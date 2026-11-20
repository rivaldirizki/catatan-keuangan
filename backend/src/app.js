import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { AuthService } from './services/auth.service.js';
import { FamilyService } from './services/family.service.js';
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
    const user = await AuthService.getUserById(req.user.id);
    const result = await TransactionService.recordIncome(user.id, wallet_id, category_id, amount, date || new Date().toISOString().split('T')[0], notes, isFamily, user.family_id);
    res.status(201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/transactions/expense', authenticateJWT, async (req, res) => {
  try {
    const { wallet_id, category_id, amount, date, notes, isFamily } = req.body;
    const user = await AuthService.getUserById(req.user.id);
    const result = await TransactionService.recordExpense(user.id, wallet_id, category_id, amount, date || new Date().toISOString().split('T')[0], notes, isFamily, user.family_id);
    res.status(201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/v1/transactions/transfer', authenticateJWT, async (req, res) => {
  try {
    const { from_wallet_id, to_wallet_id, amount, date, notes } = req.body;
    const result = await TransactionService.transfer(req.user.id, from_wallet_id, to_wallet_id, amount, date || new Date().toISOString().split('T')[0], notes);
    res.json(result);
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
    const result = await SavingService.deposit(req.user.id, wallet_id, saving_id, amount, date, notes);
    res.json(result);
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
    const familyView = req.query.familyView === 'true';
    const debts = await DebtService.getDebts(user.id, user.family_id, familyView);
    res.json(debts);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/debts', authenticateJWT, async (req, res) => {
  try {
    const { type, person_name, amount, due_date, notes, scope } = req.body;
    const user = await AuthService.getUserById(req.user.id);
    const debt = await DebtService.createDebt(user.id, type, person_name, amount, due_date, notes, scope || 'personal', user.family_id);
    res.status(201).json(debt);
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

// ======================= ADMIN API ROUTES =======================
app.get('/admin/api/stats', authenticateJWT, requireAdmin, AdminController.getStats);
app.get('/admin/api/users', authenticateJWT, requireAdmin, AdminController.getUsers);
app.get('/admin/api/families', authenticateJWT, requireAdmin, AdminController.getFamilies);
app.get('/admin/api/transactions', authenticateJWT, requireAdmin, AdminController.getTransactions);
app.get('/admin/api/savings', authenticateJWT, requireAdmin, AdminController.getSavings);
app.get('/admin/api/debts', authenticateJWT, requireAdmin, AdminController.getDebts);
app.put('/admin/api/users/:id/role', authenticateJWT, requireAdmin, AdminController.updateUserRole);

// ======================= ADMIN WEB PORTAL WITH LOGIN GATE =======================
const adminHtmlPath = path.join(__dirname, 'views', 'admin.html');
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
