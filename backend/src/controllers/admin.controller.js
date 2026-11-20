import { db } from '../config/database.js';

export const AdminController = {
  async getStats(req, res) {
    try {
      const users = await db.query('SELECT id, name, email, role, family_id, created_at FROM users');
      const families = await db.query('SELECT id, name, invite_code, created_at FROM families');
      const transactions = await db.query('SELECT id, user_id, wallet_id, type, amount, transaction_date, notes, scope, created_at FROM transactions ORDER BY id DESC');
      const wallets = await db.query('SELECT id, balance FROM wallets');
      const savings = await db.query('SELECT id, target_amount, current_amount, scope FROM savings');
      const debts = await db.query('SELECT id, type, remaining_amount, status FROM debts');

      let totalSystemBalance = 0;
      wallets.forEach(w => totalSystemBalance += Number(w.balance || 0));

      let totalSavingsBalance = 0;
      let sharedSavingsCount = 0;
      savings.forEach(s => {
        totalSavingsBalance += Number(s.current_amount || 0);
        if (s.scope === 'family') sharedSavingsCount++;
      });

      let totalActiveDebts = 0;
      debts.forEach(d => {
        if (d.type === 'payable' && d.status !== 'paid') totalActiveDebts += Number(d.remaining_amount || 0);
      });

      let totalIncomeVolume = 0;
      let totalExpenseVolume = 0;
      transactions.forEach(t => {
        if (t.type === 'income') totalIncomeVolume += Number(t.amount || 0);
        else totalExpenseVolume += Number(t.amount || 0);
      });

      const recentTx = transactions.slice(0, 8).map(t => {
        const u = users.find(user => user.id === t.user_id);
        return {
          ...t,
          user_name: u ? u.name : 'User #' + t.user_id,
          user_email: u ? u.email : ''
        };
      });

      res.json({
        total_users: users.length,
        admin_count: users.filter(u => u.role === 'admin').length,
        total_families: families.length,
        total_transactions: transactions.length,
        total_system_balance: totalSystemBalance,
        total_savings_balance: totalSavingsBalance,
        total_savings_goals: savings.length,
        shared_savings_count: sharedSavingsCount,
        total_active_debts: totalActiveDebts,
        total_wallets: wallets.length,
        total_income_volume: totalIncomeVolume,
        total_expense_volume: totalExpenseVolume,
        recent_transactions: recentTx
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async getUsers(req, res) {
    try {
      const users = await db.query('SELECT id, name, email, role, family_id, created_at FROM users ORDER BY id DESC');
      const families = await db.query('SELECT id, name, invite_code FROM families');
      const wallets = await db.query('SELECT id, user_id, balance FROM wallets');
      const transactions = await db.query('SELECT id, user_id FROM transactions');

      const enriched = users.map(u => {
        const fam = families.find(f => f.id === u.family_id);
        const userWallets = wallets.filter(w => w.user_id === u.id);
        const totalBal = userWallets.reduce((sum, w) => sum + Number(w.balance || 0), 0);
        const txCount = transactions.filter(t => t.user_id === u.id).length;

        return {
          ...u,
          family_name: fam ? fam.name : null,
          family_code: fam ? fam.invite_code : null,
          wallet_count: userWallets.length,
          total_balance: totalBal,
          transaction_count: txCount
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async getFamilies(req, res) {
    try {
      const families = await db.query('SELECT id, name, invite_code, created_at FROM families ORDER BY id DESC');
      const users = await db.query('SELECT id, name, email, role, family_id FROM users');
      const savings = await db.query('SELECT id, family_id, current_amount, target_amount, scope FROM savings');

      const enriched = families.map(f => {
        const members = users.filter(u => u.family_id === f.id);
        const familySavings = savings.filter(s => s.family_id === f.id || s.scope === 'family');
        const totalSavings = familySavings.reduce((sum, s) => sum + Number(s.current_amount || 0), 0);

        return {
          ...f,
          member_count: members.length,
          members: members.map(m => ({ id: m.id, name: m.name, email: m.email, role: m.role })),
          savings_count: familySavings.length,
          total_savings: totalSavings
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async getTransactions(req, res) {
    try {
      const transactions = await db.query('SELECT id, user_id, family_id, wallet_id, type, amount, transaction_date, notes, scope, created_at FROM transactions ORDER BY id DESC');
      const users = await db.query('SELECT id, name, email FROM users');
      const wallets = await db.query('SELECT id, name FROM wallets');
      const families = await db.query('SELECT id, name FROM families');

      const enriched = transactions.map(t => {
        const u = users.find(user => user.id === t.user_id);
        const w = wallets.find(wallet => wallet.id === t.wallet_id);
        const f = t.family_id ? families.find(fam => fam.id === t.family_id) : null;

        return {
          ...t,
          user_name: u ? u.name : 'User #' + t.user_id,
          user_email: u ? u.email : '',
          wallet_name: w ? w.name : 'Dompet #' + t.wallet_id,
          family_name: f ? f.name : null
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async getSavings(req, res) {
    try {
      const savings = await db.query('SELECT id, user_id, family_id, goal_name, target_amount, current_amount, target_date, scope, status, created_at FROM savings ORDER BY id DESC');
      const users = await db.query('SELECT id, name FROM users');
      const families = await db.query('SELECT id, name FROM families');

      const enriched = savings.map(s => {
        const u = users.find(user => user.id === s.user_id);
        const f = s.family_id ? families.find(fam => fam.id === s.family_id) : null;
        const target = Number(s.target_amount || 0);
        const current = Number(s.current_amount || 0);
        const progress = target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0;

        return {
          ...s,
          user_name: u ? u.name : 'Unknown',
          family_name: f ? f.name : null,
          progress
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async getDebts(req, res) {
    try {
      const debts = await db.query('SELECT id, user_id, type, person_name, amount, remaining_amount, due_date, status, notes, scope, created_at FROM debts ORDER BY id DESC');
      const users = await db.query('SELECT id, name FROM users');

      const enriched = debts.map(d => {
        const u = users.find(user => user.id === d.user_id);
        return {
          ...d,
          user_name: u ? u.name : 'Unknown'
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateUserRole(req, res) {
    try {
      const targetUserId = Number(req.params.id);
      const { role } = req.body;

      if (!['admin', 'user'].includes(role)) {
        return res.status(400).json({ error: 'Role harus berupa "admin" atau "user"' });
      }

      const targetUsers = await db.query('SELECT id, role FROM users WHERE id = ?', [targetUserId]);
      if (!targetUsers || targetUsers.length === 0) {
        return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
      }

      await db.query('UPDATE users SET role = ? WHERE id = ?', [role, targetUserId]);
      res.json({
        success: true,
        message: `Role pengguna berhasil diubah menjadi ${role}`,
        user_id: targetUserId,
        new_role: role
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
};
