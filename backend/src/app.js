import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { AuthService } from './services/auth.service.js';
import { FamilyService } from './services/family.service.js';
import { CompanyService } from './services/company.service.js';
import { ProjectService } from './services/project.service.js';
import { WalletService } from './services/wallet.service.js';
import { TransactionService } from './services/transaction.service.js';
import { SavingService } from './services/saving.service.js';
import { DebtService } from './services/debt.service.js';
import { authenticateJWT, requireAdmin } from './middleware/auth.middleware.js';
import { AdminController } from './controllers/admin.controller.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const app = express();

app.use(cors());
app.use(express.json());

// Root endpoint for cPanel Node.js Selector availability check & landing
app.get('/', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(`<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>Dompet Linc Backend API • LiNC</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #F8FAFC; color: #1E293B; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
    .card { background: white; border: 1px solid #E2E8F0; border-radius: 20px; padding: 36px; max-width: 440px; text-align: center; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.05); }
    h1 { font-size: 22px; font-weight: 800; color: #0F172A; margin: 0 0 8px 0; }
    p { color: #64748B; font-size: 14px; margin: 0 0 20px 0; }
    .badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 12px; background: #ECFDF5; color: #059669; border-radius: 99px; font-size: 12px; font-weight: 600; margin-bottom: 20px; }
    .dot { width: 8px; height: 8px; background: #10B981; border-radius: 50%; }
    .btn { display: inline-block; background: #4F46E5; color: white; text-decoration: none; padding: 10px 20px; border-radius: 12px; font-weight: 600; font-size: 13px; margin: 4px; }
    .footer { font-size: 11px; color: #94A3B8; margin-top: 24px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge"><span class="dot"></span> Sistem Aktif (Online)</div>
    <h1>Dompet Linc Backend REST API</h1>
    <p>Server backend operasional untuk platform finansial pribadi, keluarga, dan perusahaan.</p>
    <div>
      <a href="/admin" class="btn">Buka Admin Console</a>
      <a href="/health" class="btn" style="background: #F1F5F9; color: #334155;">Cek Health API</a>
    </div>
    <div class="footer">Sistem by Rivaldi Rizki Alvian</div>
  </div>
</body>
</html>`);
});

// Public health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'finance-backend', time: new Date() });
});

// ======================= AUTH ROUTES =======================
app.post('/api/v1/auth/register', async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required' });
    }
    const result = await AuthService.register(name, email, password, role || 'user');
    res.status(201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    const result = await AuthService.login(email, password);
    res.json(result);
  } catch (err) {
    res.status(401).json({ error: err.message });
  }
});

app.get('/api/v1/auth/me', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ======================= FAMILY ROUTES =======================
app.post('/api/v1/family/create', authenticateJWT, async (req, res) => {
  try {
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: 'Family name is required' });
    const family = await FamilyService.createFamily(req.user.id, name);
    res.status(201).json(family);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/family/join', authenticateJWT, async (req, res) => {
  try {
    const { invite_code } = req.body;
    if (!invite_code) return res.status(400).json({ error: 'Invite code is required' });
    const result = await FamilyService.joinFamily(req.user.id, invite_code);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get('/api/v1/family/members', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.family_id) {
      return res.json([]);
    }
    const members = await FamilyService.getFamilyMembers(user.family_id);
    res.json(members);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/family/current', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.family_id) {
      return res.json({ family: null, members: [] });
    }
    const family = await FamilyService.getFamilyById(user.family_id);
    const members = await FamilyService.getFamilyMembers(user.family_id);
    res.json({ family, members });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/family/members/:id/summary', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.family_id) {
      return res.status(400).json({ error: 'Pengguna belum terhubung ke grup keluarga' });
    }
    const memberId = Number(req.params.id);
    const summary = await TransactionService.getMemberSummary(user.family_id, memberId);
    res.json(summary);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ======================= COMPANY ROUTES =======================
app.post('/api/v1/company/create', authenticateJWT, async (req, res) => {
  try {
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: 'Company name is required' });
    const company = await CompanyService.createCompany(req.user.id, name);
    res.status(201).json(company);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/company/join', authenticateJWT, async (req, res) => {
  try {
    const { invite_code } = req.body;
    if (!invite_code) return res.status(400).json({ error: 'Invite code is required' });
    const result = await CompanyService.joinCompany(req.user.id, invite_code);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get('/api/v1/company/members', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.company_id) {
      return res.json([]);
    }
    const members = await CompanyService.getCompanyMembers(user.company_id);
    res.json(members);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/company/current', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.company_id) {
      return res.json({ company: null, members: [] });
    }
    const company = await CompanyService.getCompanyById(user.company_id);
    const members = await CompanyService.getCompanyMembers(user.company_id);
    res.json({ company, members });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ======================= PROJECT ROUTES =======================
app.get('/api/v1/projects', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.company_id) {
      return res.json([]);
    }
    const projects = await ProjectService.getProjects(user.company_id, req.query.status);
    res.json(projects);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/projects', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.company_id) {
      return res.status(400).json({ error: 'Pengguna belum terhubung ke perusahaan' });
    }
    const project = await ProjectService.createProject(user.company_id, user.id, req.body);
    res.status(201).json(project);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get('/api/v1/projects/:id', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.company_id) {
      return res.status(400).json({ error: 'Pengguna belum terhubung ke perusahaan' });
    }
    const project = await ProjectService.getProjectById(user.company_id, Number(req.params.id));
    res.json(project);
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
});

app.post('/api/v1/projects/:id/transaction', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.company_id) {
      return res.status(400).json({ error: 'Pengguna belum terhubung ke perusahaan' });
    }
    const result = await ProjectService.recordTransaction(
      user.id,
      user.company_id,
      Number(req.params.id),
      req.body
    );
    res.status(201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.patch('/api/v1/projects/:id/status', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    if (!user || !user.company_id) {
      return res.status(400).json({ error: 'Pengguna belum terhubung ke perusahaan' });
    }
    const { status } = req.body;
    const result = await ProjectService.updateProjectStatus(user.company_id, Number(req.params.id), status);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ======================= WALLETS ROUTES =======================
app.get('/api/v1/wallets', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    const familyView = req.query.familyView === 'true';
    const wallets = await WalletService.getWallets(user.id, user.family_id, familyView);
    res.json(wallets);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/wallets', authenticateJWT, async (req, res) => {
  try {
    const { name, balance, scope } = req.body;
    const user = await AuthService.getUserById(req.user.id);
    const wallet = await WalletService.createWallet(user.id, name, balance || 0, scope || 'personal', user.family_id);
    res.status(201).json(wallet);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ======================= CATEGORIES ROUTES =======================
app.get('/api/v1/categories', authenticateJWT, async (req, res) => {
  try {
    const type = req.query.type;
    let sql = 'SELECT id, user_id, name, type, color, icon FROM categories WHERE (user_id IS NULL OR user_id = ?)';
    const params = [req.user.id];
    if (type) {
      sql += ' AND type = ?';
      params.push(type);
    }
    sql += ' ORDER BY id ASC';
    const categories = await db.query(sql, params);
    res.json(categories || []);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ======================= TRANSACTIONS ROUTES =======================
app.get('/api/v1/transactions', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    const familyView = req.query.familyView === 'true';
    const transactions = await TransactionService.getTransactions(user.id, user.family_id, familyView, req.query);
    res.json(transactions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/transactions/summary', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    const familyView = req.query.familyView === 'true';
    const summary = await TransactionService.getSummary(user.id, user.family_id, familyView);
    res.json(summary);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/transactions/income', authenticateJWT, async (req, res) => {
  try {
    const { wallet_id, category_id, amount, date, notes, isFamily } = req.body;
    const idempotencyKey = req.body.idempotency_key || req.headers['x-idempotency-key'] || null;
    const user = await AuthService.getUserById(req.user.id);
    const result = await TransactionService.recordIncome(user.id, wallet_id, category_id, amount, date || new Date().toISOString().split('T')[0], notes, isFamily, user.family_id, idempotencyKey);
    res.status(result.already_processed ? 200 : 201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/transactions/expense', authenticateJWT, async (req, res) => {
  try {
    const { wallet_id, category_id, amount, date, notes, isFamily } = req.body;
    const idempotencyKey = req.body.idempotency_key || req.headers['x-idempotency-key'] || null;
    const user = await AuthService.getUserById(req.user.id);
    const result = await TransactionService.recordExpense(user.id, wallet_id, category_id, amount, date || new Date().toISOString().split('T')[0], notes, isFamily, user.family_id, idempotencyKey);
    res.status(result.already_processed ? 200 : 201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/transactions/transfer', authenticateJWT, async (req, res) => {
  try {
    const { from_wallet_id, to_wallet_id, amount, date, notes } = req.body;
    const idempotencyKey = req.body.idempotency_key || req.headers['x-idempotency-key'] || null;
    const result = await TransactionService.transfer(req.user.id, from_wallet_id, to_wallet_id, amount, date || new Date().toISOString().split('T')[0], notes, idempotencyKey);
    res.status(result.already_processed ? 200 : 201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ======================= SAVINGS (VAULT) ROUTES =======================
app.get('/api/v1/savings', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    const familyView = req.query.familyView === 'true';
    const goals = await SavingService.getGoals(user.id, user.family_id, familyView);
    res.json(goals);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/savings/goals', authenticateJWT, async (req, res) => {
  try {
    const { goal_name, target_amount, target_date, scope } = req.body;
    const user = await AuthService.getUserById(req.user.id);
    const goal = await SavingService.createGoal(user.id, goal_name, target_amount, target_date, scope || 'personal', user.family_id);
    res.status(201).json(goal);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/savings/deposit', authenticateJWT, async (req, res) => {
  try {
    const { wallet_id, saving_id, amount, date, notes } = req.body;
    const idempotencyKey = req.body.idempotency_key || req.headers['x-idempotency-key'] || null;
    const result = await SavingService.deposit(req.user.id, wallet_id, saving_id, amount, date, notes, idempotencyKey);
    res.status(result.already_processed ? 200 : 201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/savings/withdraw', authenticateJWT, async (req, res) => {
  try {
    const { saving_id, wallet_id, amount, date, notes } = req.body;
    const result = await SavingService.withdraw(req.user.id, saving_id, wallet_id, amount, date, notes);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ======================= DEBTS ROUTES =======================
app.get('/api/v1/debts', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    const viewMode = req.query.viewMode || (req.query.companyView === 'true' ? 'company' : (req.query.familyView === 'true' ? 'family' : 'personal'));
    const debts = await DebtService.getDebts(user.id, user.family_id, user.company_id, viewMode);
    res.json(debts);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/debts/reminders', authenticateJWT, async (req, res) => {
  try {
    const user = await AuthService.getUserById(req.user.id);
    const reminders = await DebtService.getDebtReminders(user.id, user.family_id, user.company_id);
    res.json(reminders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/debts', authenticateJWT, async (req, res) => {
  try {
    const { type, person_name, amount, due_date, notes, scope, installments_count } = req.body;
    const idempotencyKey = req.body.idempotency_key || req.headers['x-idempotency-key'] || null;
    const user = await AuthService.getUserById(req.user.id);
    const targetScope = scope || 'personal';
    const famId = targetScope === 'family' ? user.family_id : null;
    const compId = targetScope === 'company' ? user.company_id : null;

    const debt = await DebtService.createDebt(
      user.id,
      type,
      person_name,
      amount,
      due_date,
      notes,
      targetScope,
      famId,
      compId,
      installments_count || 1,
      idempotencyKey
    );
    res.status(debt.already_processed ? 200 : 201).json(debt);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/debts/:id/pay', authenticateJWT, async (req, res) => {
  try {
    const debtId = req.params.id;
    const { wallet_id, amount, date, notes } = req.body;
    const result = await DebtService.recordPayment(req.user.id, debtId, wallet_id, amount, date, notes);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ======================= ADMIN API ROUTES (FULL CRUD) =======================
// Stats & Overview
app.get('/admin/api/stats', authenticateJWT, requireAdmin, AdminController.getStats);
app.get('/api/v1/admin/dashboard', authenticateJWT, requireAdmin, AdminController.getStats);

// Users CRUD
app.get('/admin/api/users', authenticateJWT, requireAdmin, AdminController.getUsers);
app.post('/admin/api/users', authenticateJWT, requireAdmin, AdminController.createUser);
app.put('/admin/api/users/:id', authenticateJWT, requireAdmin, AdminController.updateUser);
app.delete('/admin/api/users/:id', authenticateJWT, requireAdmin, AdminController.deleteUser);
app.put('/admin/api/users/:id/role', authenticateJWT, requireAdmin, AdminController.updateUserRole);

// Families CRUD
app.get('/admin/api/families', authenticateJWT, requireAdmin, AdminController.getFamilies);
app.post('/admin/api/families', authenticateJWT, requireAdmin, AdminController.createFamily);
app.put('/admin/api/families/:id', authenticateJWT, requireAdmin, AdminController.updateFamily);
app.delete('/admin/api/families/:id', authenticateJWT, requireAdmin, AdminController.deleteFamily);

// Companies CRUD
app.get('/admin/api/companies', authenticateJWT, requireAdmin, AdminController.getCompanies);
app.post('/admin/api/companies', authenticateJWT, requireAdmin, AdminController.createCompany);
app.put('/admin/api/companies/:id', authenticateJWT, requireAdmin, AdminController.updateCompany);
app.delete('/admin/api/companies/:id', authenticateJWT, requireAdmin, AdminController.deleteCompany);

// Projects CRUD
app.get('/admin/api/projects', authenticateJWT, requireAdmin, AdminController.getProjects);
app.post('/admin/api/projects', authenticateJWT, requireAdmin, AdminController.createProject);
app.put('/admin/api/projects/:id', authenticateJWT, requireAdmin, AdminController.updateProject);
app.delete('/admin/api/projects/:id', authenticateJWT, requireAdmin, AdminController.deleteProject);

// Wallets CRUD
app.get('/admin/api/wallets', authenticateJWT, requireAdmin, AdminController.getWallets);
app.post('/admin/api/wallets', authenticateJWT, requireAdmin, AdminController.createWallet);
app.put('/admin/api/wallets/:id', authenticateJWT, requireAdmin, AdminController.updateWallet);
app.delete('/admin/api/wallets/:id', authenticateJWT, requireAdmin, AdminController.deleteWallet);

// Transactions CRUD
app.get('/admin/api/transactions', authenticateJWT, requireAdmin, AdminController.getTransactions);
app.post('/admin/api/transactions', authenticateJWT, requireAdmin, AdminController.createTransaction);
app.put('/admin/api/transactions/:id', authenticateJWT, requireAdmin, AdminController.updateTransaction);
app.delete('/admin/api/transactions/:id', authenticateJWT, requireAdmin, AdminController.deleteTransaction);

// Savings CRUD
app.get('/admin/api/savings', authenticateJWT, requireAdmin, AdminController.getSavings);
app.post('/admin/api/savings', authenticateJWT, requireAdmin, AdminController.createSaving);
app.put('/admin/api/savings/:id', authenticateJWT, requireAdmin, AdminController.updateSaving);
app.delete('/admin/api/savings/:id', authenticateJWT, requireAdmin, AdminController.deleteSaving);

// Debts CRUD
app.get('/admin/api/debts', authenticateJWT, requireAdmin, AdminController.getDebts);
app.post('/admin/api/debts', authenticateJWT, requireAdmin, AdminController.createDebt);
app.put('/admin/api/debts/:id', authenticateJWT, requireAdmin, AdminController.updateDebt);
app.delete('/admin/api/debts/:id', authenticateJWT, requireAdmin, AdminController.deleteDebt);

// Categories CRUD
app.get('/admin/api/categories', authenticateJWT, requireAdmin, AdminController.getCategories);
app.post('/admin/api/categories', authenticateJWT, requireAdmin, AdminController.createCategory);
app.put('/admin/api/categories/:id', authenticateJWT, requireAdmin, AdminController.updateCategory);
app.delete('/admin/api/categories/:id', authenticateJWT, requireAdmin, AdminController.deleteCategory);

// ======================= ADMIN WEB PORTAL WITH LOGIN GATE =======================
const adminHtmlPath = path.join(__dirname, 'views', 'admin.html');
const logoAssetPath = path.join(__dirname, 'views', 'linc_logo.png');
const fallbackLogoPath = path.join(__dirname, '..', '..', 'frontend', 'assets', 'images', 'linc_logo.png');

app.get('/assets/logo.png', (req, res) => {
  const targetPath = fs.existsSync(logoAssetPath) ? logoAssetPath : (fs.existsSync(fallbackLogoPath) ? fallbackLogoPath : null);
  if (targetPath) {
    if (typeof res.sendFile === 'function') {
      res.sendFile(targetPath);
    } else {
      res.setHeader('content-type', 'image/png');
      res.send(fs.readFileSync(targetPath));
    }
  } else {
    res.status(404).send('Logo not found');
  }
});

app.get('/admin', (req, res) => {
  if (fs.existsSync(adminHtmlPath)) {
    if (typeof res.sendFile === 'function') {
      res.sendFile(adminHtmlPath);
    } else {
      res.setHeader('content-type', 'text/html');
      res.send(fs.readFileSync(adminHtmlPath, 'utf-8'));
    }
  } else {
    res.status(404).send('Admin view file not found');
  }
});
