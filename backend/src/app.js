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

// ======================= ADMIN API ROUTES =======================
app.get('/admin/api/stats', authenticateJWT, requireAdmin, AdminController.getStats);
app.get('/admin/api/users', authenticateJWT, requireAdmin, AdminController.getUsers);

// ======================= ADMIN WEB PORTAL WITH LOGIN GATE =======================
app.get('/admin', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Admin Portal - Catatan Keuangan</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-900 text-slate-100 min-h-screen font-sans">
  
  <!-- 1. LOGIN GATE VIEW (Ditampilkan jika belum login) -->
  <div id="login-view" class="flex items-center justify-center min-h-screen px-4">
    <div class="w-full max-w-md bg-slate-800/80 p-8 rounded-2xl border border-slate-700 shadow-2xl backdrop-blur-sm">
      <div class="text-center mb-6">
        <div class="w-14 h-14 bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 rounded-2xl flex items-center justify-center mx-auto mb-3">
          <svg class="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
          </svg>
        </div>
        <h1 class="text-2xl font-bold text-white">Login Admin Portal</h1>
        <p class="text-slate-400 text-sm mt-1">Khusus akun dengan role administrator</p>
      </div>

      <div id="login-alert" class="hidden mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-xs"></div>

      <form id="admin-login-form" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2">Email Admin</label>
          <input type="email" id="email" value="admin@gmail.com" required class="w-full px-4 py-3 rounded-xl bg-slate-900/80 border border-slate-700 text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 transition-colors text-sm">
        </div>
        <div>
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2">Password</label>
          <input type="password" id="password" value="alvian14" required class="w-full px-4 py-3 rounded-xl bg-slate-900/80 border border-slate-700 text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 transition-colors text-sm">
        </div>
        <button type="submit" id="btn-login" class="w-full py-3.5 px-4 bg-emerald-500 hover:bg-emerald-600 text-slate-950 font-bold rounded-xl transition-all shadow-lg shadow-emerald-500/20 active:scale-[0.99] text-sm">
          Masuk ke Dashboard
        </button>
      </form>
    </div>
  </div>

  <!-- 2. PROTECTED ADMIN DASHBOARD VIEW (Hanya muncul jika sudah login) -->
  <div id="dashboard-view" class="hidden">
    <div class="max-w-6xl mx-auto px-4 py-8">
      <header class="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-slate-800 gap-4">
        <div>
          <div class="flex items-center gap-3">
            <h1 class="text-2xl font-bold text-white">Admin Management Portal</h1>
            <span class="px-2.5 py-0.5 bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 rounded-full text-xs font-semibold">Active</span>
          </div>
          <p class="text-slate-400 text-sm mt-1">Monitoring sistem keuangan, keluarga, dan seluruh pengguna</p>
        </div>
        <div class="flex items-center gap-3">
          <span id="admin-user-label" class="text-sm font-medium text-slate-300 bg-slate-800 px-3 py-1.5 rounded-lg border border-slate-700">admin@gmail.com</span>
          <button id="btn-logout" class="px-4 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 rounded-lg text-sm font-semibold transition-colors">
            Keluar
          </button>
        </div>
      </header>

      <!-- Stat Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 my-8">
        <div class="bg-slate-800/60 p-6 rounded-2xl border border-slate-700/50">
          <p class="text-sm font-medium text-slate-400">Total Pengguna Terdaftar</p>
          <p class="text-3xl font-extrabold text-white mt-2" id="stat-users">-</p>
        </div>
        <div class="bg-slate-800/60 p-6 rounded-2xl border border-slate-700/50">
          <p class="text-sm font-medium text-slate-400">Total Grup Keluarga</p>
          <p class="text-3xl font-extrabold text-emerald-400 mt-2" id="stat-families">-</p>
        </div>
        <div class="bg-slate-800/60 p-6 rounded-2xl border border-slate-700/50">
          <p class="text-sm font-medium text-slate-400">Total Mutasi Transaksi</p>
          <p class="text-3xl font-extrabold text-blue-400 mt-2" id="stat-transactions">-</p>
        </div>
      </div>

      <!-- Users Table -->
      <div class="bg-slate-800/40 rounded-2xl border border-slate-800 p-6">
        <h2 class="text-lg font-semibold text-white mb-4">Daftar Pengguna Sistem</h2>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-slate-300">
            <thead class="text-xs uppercase bg-slate-800/80 text-slate-400">
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
  </div>

  <script>
    const tokenKey = 'finance_admin_token';

    function checkAuth() {
      const token = localStorage.getItem(tokenKey);
      if (!token) {
        document.getElementById('login-view').classList.remove('hidden');
        document.getElementById('dashboard-view').classList.add('hidden');
      } else {
        document.getElementById('login-view').classList.add('hidden');
        document.getElementById('dashboard-view').classList.remove('hidden');
        loadDashboardData(token);
      }
    }

    document.getElementById('admin-login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('email').value.trim();
      const password = document.getElementById('password').value;
      const alertBox = document.getElementById('login-alert');
      const btn = document.getElementById('btn-login');

      alertBox.classList.add('hidden');
      btn.disabled = true;
      btn.innerText = 'Memverifikasi...';

      try {
        const res = await fetch('/api/v1/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password })
        });
        const data = await res.json();

        if (!res.ok) {
          throw new Error(data.error || 'Login gagal');
        }

        if (data.user.role !== 'admin') {
          throw new Error('Akses ditolak: Akun ini bukan administrator');
        }

        localStorage.setItem(tokenKey, data.token);
        localStorage.setItem('admin_email', data.user.email);
        document.getElementById('admin-user-label').innerText = data.user.email;
        checkAuth();
      } catch (err) {
        alertBox.innerText = err.message;
        alertBox.classList.remove('hidden');
      } finally {
        btn.disabled = false;
        btn.innerText = 'Masuk ke Dashboard';
      }
    });

    document.getElementById('btn-logout').addEventListener('click', () => {
      localStorage.removeItem(tokenKey);
      localStorage.removeItem('admin_email');
      checkAuth();
    });

    async function loadDashboardData(token) {
      const headers = { 'Authorization': 'Bearer ' + token };
      try {
        // Fetch stats
        const statsRes = await fetch('/admin/api/stats', { headers });
        if (statsRes.status === 401 || statsRes.status === 403) {
          localStorage.removeItem(tokenKey);
          return checkAuth();
        }
        const stats = await statsRes.json();
        document.getElementById('stat-users').innerText = stats.total_users;
        document.getElementById('stat-families').innerText = stats.total_families;
        document.getElementById('stat-transactions').innerText = stats.total_transactions;

        // Fetch users
        const usersRes = await fetch('/admin/api/users', { headers });
        const users = await usersRes.json();
        const tbody = document.getElementById('user-rows');
        if (Array.isArray(users) && users.length > 0) {
          tbody.innerHTML = users.map(u => \`
            <tr class="hover:bg-slate-800/40">
              <td class="px-4 py-3 font-mono text-xs">\${u.id}</td>
              <td class="px-4 py-3 font-medium text-white">\${u.name}</td>
              <td class="px-4 py-3 text-slate-300">\${u.email}</td>
              <td class="px-4 py-3">
                <span class="px-2 py-0.5 rounded text-xs font-semibold \${u.role === 'admin' ? 'bg-purple-500/10 text-purple-400 border border-purple-500/30' : 'bg-slate-700 text-slate-300'}">
                  \${u.role}
                </span>
              </td>
              <td class="px-4 py-3 text-slate-400">\${u.family_id || '-'}</td>
            </tr>
          \`).join('');
        }
      } catch (err) {
        console.error(err);
      }
    }

    checkAuth();
  </script>
</body>
</html>
  `);
});
