'use strict';
require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();

// Raw body must be captured BEFORE the JSON parser for webhook HMAC verification.
app.use('/api/payments/webhook', express.raw({ type: '*/*' }));
app.use(express.json());
app.use(cors({ origin: process.env.ALLOWED_ORIGIN || '*' }));

app.use('/api/payments', require('./routes/payments'));

// Global error handler
app.use((err, req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`Drip Store backend listening on :${PORT}`));
}

module.exports = app;
