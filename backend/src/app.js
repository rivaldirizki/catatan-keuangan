import express from 'express';
import cors from 'cors';
import { AuthService } from './services/auth.service.js';
import { FamilyService } from './services/family.service.js';
import { WalletService } from './services/wallet.service.js';
import { TransactionService } from './services/transaction.service.js';
import { SavingService } from './services/saving.service.js';
import { DebtService } from './services/debt.service.js';
import { authenticateJWT, requireAdmin } from './middleware/auth.middleware.js';
import { AdminController } from './controllers/admin.controller.js';

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

// ======================= ADMIN ROUTES =======================
app.get('/admin/api/stats', authenticateJWT, requireAdmin, AdminController.getStats);
app.get('/admin/api/users', authenticateJWT, requireAdmin, AdminController.getUsers);

// Admin Web Dashboard Static HTML (Embedded for zero hassle)
app.get('/admin', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Admin Dashboard - Catatan Keuangan</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-900 text-slate-100 min-h-screen">
  <div class="max-w-6xl mx-auto px-4 py-8">
    <header class="flex items-center justify-between pb-6 border-b border-slate-800">
      <div>
        <h1 class="text-2xl font-bold tracking-tight text-white">Admin Management Portal</h1>
        <p class="text-slate-400 text-sm">Monitoring sistem keuangan, keluarga, dan pengguna</p>
      </div>
      <span class="px-3 py-1 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-full text-xs font-semibold">Node.js + MySQL Backend</span>
    </header>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 my-8" id="stats-grid">
      <div class="bg-slate-800/60 p-6 rounded-2xl border border-slate-700/50">
        <p class="text-sm font-medium text-slate-400">Total Pengguna Terdaftar</p>
        <p class="text-3xl font-extrabold text-white mt-2" id="stat-users">-</p>
      </div>
      <div class="bg-slate-800/60 p-6 rounded-2xl border border-slate-700/50">
        <p class="text-sm font-medium text-slate-400">Total Grup Keluarga</p>
        <p class="text-3xl font-extrabold text-emerald-400 mt-2" id="stat-families">-</p>
      </div>
      <div class="bg-slate-800/60 p-6 rounded-2xl border border-slate-700/50">
        <p class="text-sm font-medium text-slate-400">Total Transaksi Tercatat</p>
        <p class="text-3xl font-extrabold text-blue-400 mt-2" id="stat-transactions">-</p>
      </div>
    </div>

    <div class="bg-slate-800/40 rounded-2xl border border-slate-800 p-6">
      <h2 class="text-lg font-semibold text-white mb-4">Pengguna Sistem</h2>
      <div class="overflow-x-auto">
        <table class="w-full text-left text-sm text-slate-300">
          <thead class="text-xs uppercase bg-slate-800 text-slate-400">
            <tr>
              <th class="px-4 py-3">ID</th>
              <th class="px-4 py-3">Nama</th>
              <th class="px-4 py-3">Email</th>
              <th class="px-4 py-3">Role</th>
              <th class="px-4 py-3">Family ID</th>
            </tr>
          </thead>
          <tbody id="user-rows" class="divide-y divide-slate-800">
            <tr><td colspan="5" class="px-4 py-4 text-center text-slate-500">Memuat data pengguna...</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</body>
</html>
  `);
});
