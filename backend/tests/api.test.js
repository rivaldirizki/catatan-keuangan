import { describe, it, before } from 'node:test';
import assert from 'node:assert';
import { EventEmitter } from 'node:events';
import fs from 'node:fs';
import { app } from '../src/app.js';
import { db } from '../src/config/database.js';

function request(app) {
  return {
    async send(method, url, { headers = {}, body = null } = {}) {
      return new Promise((resolve) => {
        const req = new EventEmitter();
        req.method = method.toUpperCase();
        req.url = url;
        req.headers = { ...headers };
        if (body) {
          req.headers['content-type'] = 'application/json';
          req.body = body; // Pre-assign for simulated calls
        }

        const res = new EventEmitter();
        res.statusCode = 200;
        res._headers = {};
        res.setHeader = (name, val) => { res._headers[name.toLowerCase()] = val; };
        res.getHeader = (name) => res._headers[name.toLowerCase()];
        res.status = (code) => { res.statusCode = code; return res; };

        let responseBody = '';
        res.write = (chunk) => { responseBody += chunk; };
        res.end = (chunk) => {
          if (chunk) responseBody += chunk;
          let parsed = responseBody;
          try {
            parsed = JSON.parse(responseBody);
          } catch (e) {}
          resolve({
            status: res.statusCode,
            headers: res._headers,
            body: parsed
          });
        };
        res.json = (obj) => {
          res.setHeader('content-type', 'application/json');
          res.end(JSON.stringify(obj));
        };
        res.send = (val) => {
          res.end(typeof val === 'object' ? JSON.stringify(val) : String(val));
        };
        res.sendFile = (filePath) => {
          res.setHeader('content-type', 'text/html');
          res.end(fs.readFileSync(filePath, 'utf-8'));
        };

        // Forward to express app
        app(req, res);
      });
    }
  };
}

describe('Task 6: Express App & REST API Integration (TDD)', () => {
  before(() => {
    if (db.mock) db.mock.reset();
  });

  it('should return health check and API status', async () => {
    const client = request(app);
    const res = await client.send('GET', '/health');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'ok');
  });

  it('should register and login via API endpoints', async () => {
    const client = request(app);
    // 1. Register
    const regRes = await client.send('POST', '/api/v1/auth/register', {
      body: { name: 'API User', email: 'api@finance.com', password: 'password123' }
    });
    assert.strictEqual(regRes.status, 201);
    assert.ok(regRes.body.token);
    assert.strictEqual(regRes.body.user.email, 'api@finance.com');

    // 2. Access protected endpoint without token -> 401
    const unauthRes = await client.send('GET', '/api/v1/wallets');
    assert.strictEqual(unauthRes.status, 401);

    // 3. Access protected endpoint with token -> 200
    const authRes = await client.send('GET', '/api/v1/wallets', {
      headers: { 'authorization': `Bearer ${regRes.body.token}` }
    });
    assert.strictEqual(authRes.status, 200);
    assert.ok(Array.isArray(authRes.body));
  });

  it('should provide Admin Dashboard stats for role: admin', async () => {
    const client = request(app);
    // Register admin user
    const adminReg = await client.send('POST', '/api/v1/auth/register', {
      body: { name: 'Admin Boss', email: 'admin@finance.com', password: 'adminpass123', role: 'admin' }
    });

    const adminStatsRes = await client.send('GET', '/admin/api/stats', {
      headers: { 'authorization': `Bearer ${adminReg.body.token}` }
    });
    assert.strictEqual(adminStatsRes.status, 200);
    assert.ok(adminStatsRes.body.total_users >= 1);

    // Verify /admin HTML portal endpoint
    const htmlRes = await client.send('GET', '/admin');
    assert.strictEqual(htmlRes.status, 200);
    assert.ok(htmlRes.body.includes('Finance OS'));

    // Verify extended Admin API endpoints
    const familiesRes = await client.send('GET', '/admin/api/families', {
      headers: { 'authorization': `Bearer ${adminReg.body.token}` }
    });
    assert.strictEqual(familiesRes.status, 200);
    assert.ok(Array.isArray(familiesRes.body));

    const txRes = await client.send('GET', '/admin/api/transactions', {
      headers: { 'authorization': `Bearer ${adminReg.body.token}` }
    });
    assert.strictEqual(txRes.status, 200);
    assert.ok(Array.isArray(txRes.body));

    const savingsRes = await client.send('GET', '/admin/api/savings', {
      headers: { 'authorization': `Bearer ${adminReg.body.token}` }
    });
    assert.strictEqual(savingsRes.status, 200);
    assert.ok(Array.isArray(savingsRes.body));

    const debtsRes = await client.send('GET', '/admin/api/debts', {
      headers: { 'authorization': `Bearer ${adminReg.body.token}` }
    });
    assert.strictEqual(debtsRes.status, 200);
    assert.ok(Array.isArray(debtsRes.body));
  });
});
