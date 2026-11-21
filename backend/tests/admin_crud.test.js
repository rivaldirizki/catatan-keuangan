import { describe, it, before } from 'node:test';
import assert from 'node:assert';
import { EventEmitter } from 'node:events';
import { app } from '../src/app.js';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';

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
          req.body = body;
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

        app(req, res);
      });
    }
  };
}

describe('Admin CRUD API Test Suite', () => {
  let adminToken = '';
  let userToken = '';

  before(async () => {
    if (db.mock) db.mock.reset();

    // Register admin user
    const adminUser = await AuthService.register('Super Admin', 'admin.master@finance.com', 'adminPass123', 'admin');
    adminToken = adminUser.token;

    // Register normal user
    const normalUser = await AuthService.register('Normal Staff', 'staff@finance.com', 'staffPass123', 'user');
    userToken = normalUser.token;
  });

  it('should block non-admin users from admin CRUD endpoints', async () => {
    const client = request(app);
    const res = await client.send('GET', '/admin/api/users', {
      headers: { authorization: `Bearer ${userToken}` }
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.error, 'Forbidden: Admin access required');
  });

  it('should perform full CRUD on Users', async () => {
    const client = request(app);

    // 1. CREATE USER
    const createRes = await client.send('POST', '/admin/api/users', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        name: 'Budi Santoso',
        email: 'budi.crud@example.com',
        password: 'password123',
        role: 'user'
      }
    });
    assert.strictEqual(createRes.status, 201);
    assert.strictEqual(createRes.body.success, true);
    const newUserId = createRes.body.user.id;
    assert.ok(newUserId);

    // 2. READ USERS
    const listRes = await client.send('GET', '/admin/api/users', {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(listRes.status, 200);
    const found = listRes.body.find(u => u.id === newUserId);
    assert.ok(found);
    assert.strictEqual(found.email, 'budi.crud@example.com');

    // 3. UPDATE USER
    const updateRes = await client.send('PUT', `/admin/api/users/${newUserId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        name: 'Budi Santoso Updated',
        email: 'budi.updated@example.com',
        role: 'admin'
      }
    });
    assert.strictEqual(updateRes.status, 200);
    assert.strictEqual(updateRes.body.success, true);

    // 4. DELETE USER
    const deleteRes = await client.send('DELETE', `/admin/api/users/${newUserId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(deleteRes.status, 200);
    assert.strictEqual(deleteRes.body.success, true);
  });

  it('should perform full CRUD on Families', async () => {
    const client = request(app);

    // 1. CREATE
    const createRes = await client.send('POST', '/admin/api/families', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: { name: 'Keluarga Bahagia Admin', invite_code: 'BAHAGIA1' }
    });
    assert.strictEqual(createRes.status, 201);
    const famId = createRes.body.family.id;

    // 2. READ
    const listRes = await client.send('GET', '/admin/api/families', {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(listRes.status, 200);
    assert.ok(listRes.body.some(f => f.id === famId));

    // 3. UPDATE
    const updateRes = await client.send('PUT', `/admin/api/families/${famId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: { name: 'Keluarga Harmonis Admin', invite_code: 'HARMON1' }
    });
    assert.strictEqual(updateRes.status, 200);

    // 4. DELETE
    const deleteRes = await client.send('DELETE', `/admin/api/families/${famId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(deleteRes.status, 200);
  });

  it('should perform full CRUD on Companies and Projects', async () => {
    const client = request(app);

    // 1. CREATE COMPANY
    const createCompRes = await client.send('POST', '/admin/api/companies', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: { name: 'PT Sinergi Digital Admin', invite_code: 'CORP1234' }
    });
    assert.strictEqual(createCompRes.status, 201);
    const compId = createCompRes.body.company.id;

    // 2. UPDATE COMPANY
    const updateCompRes = await client.send('PUT', `/admin/api/companies/${compId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: { name: 'PT Sinergi Digital Solusindo', invite_code: 'CORP8888' }
    });
    assert.strictEqual(updateCompRes.status, 200);

    // 3. CREATE PROJECT
    const createProjRes = await client.send('POST', '/admin/api/projects', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        company_id: compId,
        name: 'Aplikasi Keuangan Mobile',
        description: 'Pembuatan aplikasi fintech',
        target_budget: 150000000,
        status: 'active'
      }
    });
    assert.strictEqual(createProjRes.status, 201);
    const projId = createProjRes.body.project.id;

    // 4. READ PROJECTS
    const listProjRes = await client.send('GET', '/admin/api/projects', {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(listProjRes.status, 200);
    assert.ok(listProjRes.body.some(p => p.id === projId));

    // 5. UPDATE PROJECT
    const updateProjRes = await client.send('PUT', `/admin/api/projects/${projId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        name: 'Aplikasi Keuangan Mobile v2',
        target_budget: 180000000,
        status: 'completed'
      }
    });
    assert.strictEqual(updateProjRes.status, 200);

    // 6. DELETE PROJECT
    const deleteProjRes = await client.send('DELETE', `/admin/api/projects/${projId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(deleteProjRes.status, 200);

    // 7. DELETE COMPANY
    const deleteCompRes = await client.send('DELETE', `/admin/api/companies/${compId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(deleteCompRes.status, 200);
  });

  it('should perform full CRUD on Wallets and atomic Transactions', async () => {
    const client = request(app);

    // 1. CREATE WALLET
    const createWalRes = await client.send('POST', '/admin/api/wallets', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        user_id: 1,
        name: 'Rekening Bank BCA Admin',
        balance: 10000000,
        scope: 'personal'
      }
    });
    assert.strictEqual(createWalRes.status, 201);
    const walId = createWalRes.body.wallet.id;

    // 2. READ WALLETS
    const listWalRes = await client.send('GET', '/admin/api/wallets', {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(listWalRes.status, 200);
    assert.ok(listWalRes.body.some(w => w.id === walId));

    // 3. CREATE TRANSACTION (Expense) -> Wallet balance should decrease
    const createTxRes = await client.send('POST', '/admin/api/transactions', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        user_id: 1,
        wallet_id: walId,
        type: 'expense',
        amount: 2500000,
        transaction_date: '2026-11-21',
        notes: 'Beli monitor 4K kantor',
        scope: 'personal'
      }
    });
    assert.strictEqual(createTxRes.status, 201);
    const txId = createTxRes.body.transaction.id;

    // Check adjusted wallet balance
    const checkWalRes = await client.send('GET', '/admin/api/wallets', {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    const updatedWallet = checkWalRes.body.find(w => w.id === walId);
    assert.strictEqual(Number(updatedWallet.balance), 7500000);

    // 4. UPDATE TRANSACTION (Change amount to 1000000)
    const updateTxRes = await client.send('PUT', `/admin/api/transactions/${txId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        amount: 1000000,
        notes: 'Beli monitor bekas berkualitas'
      }
    });
    assert.strictEqual(updateTxRes.status, 200);

    // 5. DELETE TRANSACTION -> Wallet balance should rollback (7500000 + 1000000 = 8500000 -> 10000000)
    const deleteTxRes = await client.send('DELETE', `/admin/api/transactions/${txId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(deleteTxRes.status, 200);

    const rollbackWalRes = await client.send('GET', '/admin/api/wallets', {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    const rolledBackWallet = rollbackWalRes.body.find(w => w.id === walId);
    assert.strictEqual(Number(rolledBackWallet.balance), 10000000);

    // 6. DELETE WALLET
    const deleteWalRes = await client.send('DELETE', `/admin/api/wallets/${walId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(deleteWalRes.status, 200);
  });

  it('should perform full CRUD on Savings, Debts, and Categories', async () => {
    const client = request(app);

    // 1. SAVINGS CRUD
    const createSav = await client.send('POST', '/admin/api/savings', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        user_id: 1,
        goal_name: 'Liburan Akhir Tahun',
        target_amount: 15000000,
        current_amount: 5000000,
        scope: 'personal'
      }
    });
    assert.strictEqual(createSav.status, 201);
    const savId = createSav.body.saving.id;

    const updateSav = await client.send('PUT', `/admin/api/savings/${savId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: { current_amount: 8000000 }
    });
    assert.strictEqual(updateSav.status, 200);

    const delSav = await client.send('DELETE', `/admin/api/savings/${savId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(delSav.status, 200);

    // 2. DEBTS CRUD
    const createDebt = await client.send('POST', '/admin/api/debts', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        user_id: 1,
        type: 'payable',
        person_name: 'Vendor Laptop',
        total_amount: 12000000,
        remaining_amount: 6000000,
        due_date: '2026-12-31',
        notes: 'Cicilan kantor'
      }
    });
    assert.strictEqual(createDebt.status, 201);
    const debtId = createDebt.body.debt.id;

    const updateDebt = await client.send('PUT', `/admin/api/debts/${debtId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: { remaining_amount: 2000000 }
    });
    assert.strictEqual(updateDebt.status, 200);

    const delDebt = await client.send('DELETE', `/admin/api/debts/${debtId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(delDebt.status, 200);

    // 3. CATEGORIES CRUD
    const createCat = await client.send('POST', '/admin/api/categories', {
      headers: { authorization: `Bearer ${adminToken}` },
      body: {
        name: 'Operasional Server',
        type: 'expense',
        color: '#6366F1',
        icon: 'server'
      }
    });
    assert.strictEqual(createCat.status, 201);
    const catId = createCat.body.category.id;

    const updateCat = await client.send('PUT', `/admin/api/categories/${catId}`, {
      headers: { authorization: `Bearer ${adminToken}` },
      body: { name: 'Infrastruktur Cloud & Server', color: '#4F46E5' }
    });
    assert.strictEqual(updateCat.status, 200);

    const delCat = await client.send('DELETE', `/admin/api/categories/${catId}`, {
      headers: { authorization: `Bearer ${adminToken}` }
    });
    assert.strictEqual(delCat.status, 200);
  });
});
