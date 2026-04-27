'use strict';

// Set env vars before requiring app so apiKey() and URL resolution work
process.env.JUSPAY_API_KEY = 'test_key_for_unit_tests';
process.env.JUSPAY_BASE_URL = 'https://sandbox.juspay.in';
process.env.BACKEND_URL = 'http://localhost:3000';

jest.mock('axios');
const axios   = require('axios');
const request = require('supertest');
const app     = require('../server');

const validBody = {
  amount:          29,
  customer_id:     'cust_test_01',
  customer_email:  'test@example.com',
  customer_phone:  '9000000000',
};

// ─── POST /api/payments/create-session ───────────────────────────────────────
describe('POST /api/payments/create-session', () => {
  test('400 when all required fields are missing', async () => {
    const res = await request(app).post('/api/payments/create-session').send({});
    expect(res.status).toBe(400);
  });

  test('400 when any required field is missing', async () => {
    const { customer_phone: _p, ...partial } = validBody;
    const res = await request(app).post('/api/payments/create-session').send(partial);
    expect(res.status).toBe(400);
  });

  test('400 for invalid email format', async () => {
    const res = await request(app)
      .post('/api/payments/create-session')
      .send({ ...validBody, customer_email: 'not-an-email' });
    expect(res.status).toBe(400);
  });

  test('400 for zero amount', async () => {
    const res = await request(app)
      .post('/api/payments/create-session')
      .send({ ...validBody, amount: 0 });
    expect(res.status).toBe(400);
  });

  test('400 for negative amount', async () => {
    const res = await request(app)
      .post('/api/payments/create-session')
      .send({ ...validBody, amount: -10 });
    expect(res.status).toBe(400);
  });

  test('200 returns sdk_payload and order_id on success', async () => {
    axios.post.mockResolvedValueOnce({
      data: {
        order_id:    'DS1XYZ',
        status:      'NEW',
        sdk_payload: { requestId: 'r1', service: 'in.juspay.hyperpay', payload: {} },
      },
    });
    const res = await request(app).post('/api/payments/create-session').send(validBody);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('sdk_payload');
    expect(res.body).toHaveProperty('order_id');
    expect(res.body).toHaveProperty('status', 'NEW');
  });

  test('forwards non-200 Juspay error status upstream', async () => {
    axios.post.mockRejectedValueOnce({
      response: { status: 422, data: { user_message: 'Duplicate order ID' } },
    });
    const res = await request(app).post('/api/payments/create-session').send(validBody);
    expect(res.status).toBe(422);
    expect(res.body.error).toBe('Duplicate order ID');
  });

  test('generated order_id is strictly alphanumeric', async () => {
    let capturedOrderId;
    axios.post.mockImplementationOnce((url, body) => {
      capturedOrderId = body.order_id;
      return Promise.resolve({
        data: { order_id: body.order_id, status: 'NEW', sdk_payload: {} },
      });
    });
    await request(app).post('/api/payments/create-session').send(validBody);
    expect(capturedOrderId).toMatch(/^[A-Z0-9]+$/);
  });

  test('generated order_id is under 21 characters', async () => {
    let capturedOrderId;
    axios.post.mockImplementationOnce((url, body) => {
      capturedOrderId = body.order_id;
      return Promise.resolve({
        data: { order_id: body.order_id, status: 'NEW', sdk_payload: {} },
      });
    });
    await request(app).post('/api/payments/create-session').send(validBody);
    expect(capturedOrderId.length).toBeLessThan(21);
  });

  test('uses Basic Auth header with colon suffix', async () => {
    let capturedHeaders;
    axios.post.mockImplementationOnce((url, body, config) => {
      capturedHeaders = config.headers;
      return Promise.resolve({ data: { order_id: 'X', status: 'NEW', sdk_payload: {} } });
    });
    await request(app).post('/api/payments/create-session').send(validBody);
    const decoded = Buffer.from(
      capturedHeaders.Authorization.replace('Basic ', ''),
      'base64'
    ).toString();
    expect(decoded).toMatch(/^[^:]+:$/); // key + colon, no password
  });
});

// ─── GET /api/payments/verify/:orderId ───────────────────────────────────────
describe('GET /api/payments/verify/:orderId', () => {
  test('400 for order ID with non-alphanumeric chars', async () => {
    const res = await request(app).get('/api/payments/verify/bad-id!');
    expect(res.status).toBe(400);
  });

  test('400 for order ID exceeding 21 characters', async () => {
    const res = await request(app).get('/api/payments/verify/ABCDEFGHIJKLMNOPQRSTUV');
    expect(res.status).toBe(400);
  });

  test('200 returns order details on success', async () => {
    axios.get.mockResolvedValueOnce({
      data: { order_id: 'DS1XYZ', status: 'CHARGED', amount: '29.00', txn_id: 'txn_abc' },
    });
    const res = await request(app).get('/api/payments/verify/DS1XYZ');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('CHARGED');
    expect(res.body.txn_id).toBe('txn_abc');
    expect(res.body.amount).toBe('29.00');
  });

  test('forwards Juspay 404 upstream', async () => {
    axios.get.mockRejectedValueOnce({
      response: { status: 404, data: { message: 'Order not found' } },
    });
    const res = await request(app).get('/api/payments/verify/DS1XYZ');
    expect(res.status).toBe(404);
  });
});

// ─── POST /api/payments/webhook ──────────────────────────────────────────────
describe('POST /api/payments/webhook', () => {
  const mkPayload = (eventName) =>
    JSON.stringify({
      event_name: eventName,
      content: { order: { order_id: 'DS1XYZ', amount: '29.00' } },
    });

  test('200 for ORDER_SUCCEEDED', async () => {
    const res = await request(app)
      .post('/api/payments/webhook')
      .set('Content-Type', 'application/json')
      .send(mkPayload('ORDER_SUCCEEDED'));
    expect(res.status).toBe(200);
    expect(res.body.received).toBe(true);
  });

  test('200 for ORDER_FAILED', async () => {
    const res = await request(app)
      .post('/api/payments/webhook')
      .set('Content-Type', 'application/json')
      .send(mkPayload('ORDER_FAILED'));
    expect(res.status).toBe(200);
  });

  test('400 for malformed JSON', async () => {
    const res = await request(app)
      .post('/api/payments/webhook')
      .set('Content-Type', 'application/json')
      .send('not valid json {{{');
    expect(res.status).toBe(400);
  });

  test('idempotency — two identical webhooks both return 200', async () => {
    const payload = mkPayload('ORDER_SUCCEEDED');
    const [r1, r2] = await Promise.all([
      request(app)
        .post('/api/payments/webhook')
        .set('Content-Type', 'application/json')
        .send(payload),
      request(app)
        .post('/api/payments/webhook')
        .set('Content-Type', 'application/json')
        .send(payload),
    ]);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);
  });

  test('401 for invalid HMAC signature when x-signature header is present', async () => {
    const res = await request(app)
      .post('/api/payments/webhook')
      .set('Content-Type', 'application/json')
      .set('x-signature', 'deadbeef00000000000000000000000000000000000000000000000000000000')
      .send(mkPayload('ORDER_SUCCEEDED'));
    expect(res.status).toBe(401);
  });
});
