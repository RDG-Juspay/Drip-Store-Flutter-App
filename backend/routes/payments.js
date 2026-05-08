'use strict';
const express = require('express');
const axios   = require('axios');
const crypto  = require('crypto');

const router = express.Router();

const MERCHANT_ID = 'iimkashipur';
const CLIENT_ID   = 'aivo';

// Normalise base URL — strip any path suffix the user may have included
// (e.g. https://sandbox.juspay.in/session → https://sandbox.juspay.in)
const JUSPAY_BASE_URL = (process.env.JUSPAY_BASE_URL || 'https://sandbox.juspay.in')
  .replace(/\/(session|orders)\/?.*$/, '');

function apiKey() {
  const key = process.env.JUSPAY_API_KEY;
  if (!key) throw new Error('JUSPAY_API_KEY environment variable is not set');
  return key;
}

// Juspay uses HTTP Basic Auth: Base64(api_key + ":") — the colon is mandatory
function authHeader() {
  return 'Basic ' + Buffer.from(apiKey() + ':').toString('base64');
}

/**
 * Generates an order ID that is:
 *   - strictly alphanumeric (A–Z, 0–9)
 *   - under 21 characters   (Juspay hard limit)
 * Format: "DS" + uppercase base-36 timestamp ≈ 13 chars total
 */
function generateOrderId() {
  return ('DS' + Date.now().toString(36)).toUpperCase();
}

// ─── POST /api/payments/create-session ────────────────────────────────────────
router.post('/create-session', async (req, res) => {
  const { amount, customer_id, customer_email, customer_phone } = req.body;

  if (!amount || !customer_id || !customer_email || !customer_phone) {
    return res.status(400).json({
      error: 'amount, customer_id, customer_email and customer_phone are required',
    });
  }

  if (!/^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/.test(customer_email)) {
    return res.status(400).json({ error: 'Invalid customer_email' });
  }

  const parsedAmount = parseFloat(amount);
  if (isNaN(parsedAmount) || parsedAmount <= 0) {
    return res.status(400).json({ error: 'amount must be a positive number' });
  }

  const order_id = generateOrderId();

  try {
    const backendUrl = process.env.BACKEND_URL || 'http://localhost:3000';

    const { data } = await axios.post(
      `${JUSPAY_BASE_URL}/session`,
      {
        order_id,
        amount: parsedAmount.toFixed(2),
        currency: 'INR',
        customer_id,
        customer_email,
        customer_phone,
        payment_page_client_id: CLIENT_ID,
        return_url: `${backendUrl}/api/payments/callback`,
        description: 'Payment for DRIP order',
      },
      {
        headers: {
          Authorization: authHeader(),
          'x-merchantid': MERCHANT_ID,
          'Content-Type': 'application/json',
          version: '2021-11-02',
        },
        timeout: 15000,
      }
    );

    res.json({
      order_id:    data.order_id || order_id,
      status:      data.status,
      sdk_payload: data.sdk_payload,
    });
  } catch (err) {
    const statusCode = err.response?.status || 500;
    const message    = err.response?.data?.user_message || err.message;
    console.error('[create-session]', statusCode, message);
    res.status(statusCode).json({ error: message });
  }
});

// ─── GET /api/payments/verify/:orderId ────────────────────────────────────────
router.get('/verify/:orderId', async (req, res) => {
  const { orderId } = req.params;

  // Reject anything that is not alphanumeric and ≤21 chars — prevents path traversal
  if (!/^[A-Z0-9]{1,21}$/.test(orderId)) {
    return res.status(400).json({ error: 'Invalid order ID format' });
  }

  try {
    const { data } = await axios.get(
      `${JUSPAY_BASE_URL}/orders/${orderId}`,
      {
        headers: {
          Authorization: authHeader(),
          'x-merchantid': MERCHANT_ID,
        },
        timeout: 15000,
      }
    );

    res.json({
      order_id: data.order_id,
      status:   data.status,
      amount:   data.amount,
      txn_id:   data.txn_id,
    });
  } catch (err) {
    const statusCode = err.response?.status || 500;
    console.error('[verify]', err.response?.data || err.message);
    res.status(statusCode).json({ error: 'Order verification failed' });
  }
});

// ─── POST /api/payments/webhook ───────────────────────────────────────────────
// express.raw() is applied to this route in server.js before express.json(),
// so req.body here is a raw Buffer — do NOT add express.json() on this route.
router.post('/webhook', (req, res) => {
  let rawBody;
  let event;

  try {
    rawBody = Buffer.isBuffer(req.body)
      ? req.body.toString('utf8')
      : JSON.stringify(req.body);
    event = JSON.parse(rawBody);
  } catch {
    return res.status(400).json({ error: 'Malformed payload' });
  }

  // HMAC-SHA256 signature verification — Juspay sends this in x-signature header
  const signature = req.headers['x-signature'];
  if (signature) {
    try {
      const expected = crypto
        .createHmac('sha256', apiKey())
        .update(rawBody)
        .digest('hex');

      // timing-safe comparison prevents length-based timing attacks
      if (
        signature.length !== expected.length ||
        !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
      ) {
        return res.status(401).json({ error: 'Invalid signature' });
      }
    } catch {
      return res.status(401).json({ error: 'Signature verification failed' });
    }
  }

  const eventName = event.event_name;
  const orderId   = event.content?.order?.order_id;
  const paidAmt   = event.content?.order?.amount;

  console.log(`[webhook] ${eventName} | order=${orderId} | amount=${paidAmt}`);

  // ── Idempotency ─────────────────────────────────────────────────────────────
  // Juspay may deliver the same webhook event more than once.
  // In production, use an idempotent DB upsert keyed on (order_id, event_name)
  // so that duplicate deliveries never double-process an order.
  //
  //   await db.orders.upsert(
  //     { order_id: orderId, status: newStatus, paid_amount: paidAmt },
  //     { onConflict: 'order_id', skipUpdateIfStatus: ['CHARGED'] }
  //   );
  // ───────────────────────────────────────────────────────────────────────────

  switch (eventName) {
    case 'ORDER_SUCCEEDED':
      // ⚠️  Security gate: always verify paidAmt matches the expected amount
      //     stored in YOUR database before marking the order paid.
      //     This prevents under-payment attacks where a malicious actor
      //     pays ₹1 for a ₹1000 item and crafts a fake success webhook.
      //
      //   const expected = await db.getOrderAmount(orderId);
      //   if (parseFloat(paidAmt) < expected) { flagFraud(orderId); break; }
      //   await db.markOrderPaid(orderId, paidAmt);
      break;

    case 'ORDER_FAILED':
    case 'ORDER_VOIDED':
      // await db.markOrderFailed(orderId);
      break;

    default:
      break;
  }

  // Always respond 200 promptly — Juspay retries on any non-2xx response
  res.status(200).json({ received: true });
});

// ─── GET /api/payments/callback ───────────────────────────────────────────────
// return_url for Juspay's web-based fallback flow (rarely triggered in-app)
router.get('/callback', (_req, res) => {
  res.send(
    '<html><body style="font-family:sans-serif;text-align:center;padding:40px">' +
    '<h2>Payment received</h2>' +
    '<p>You may close this window and return to the app.</p>' +
    '</body></html>'
  );
});

module.exports = router;
