import { db } from '../config/database.js';

export const AdminController = {
  async getStats(req, res) {
    try {
      const users = await db.query('SELECT id, name, email, role, family_id, created_at FROM users');
      const families = await db.query('SELECT id, name, invite_code, created_at FROM families');
      const transactions = await db.query('SELECT id, type, amount, transaction_date FROM transactions');
      const wallets = await db.query('SELECT id, balance FROM wallets');
      const savings = await db.query('SELECT id, target_amount, current_amount FROM savings');
      const debts = await db.query('SELECT id, type, remaining_amount, status FROM debts');

      let totalSystemBalance = 0;
      wallets.forEach(w => totalSystemBalance += Number(w.balance || 0));

      let totalSavingsBalance = 0;
      savings.forEach(s => totalSavingsBalance += Number(s.current_amount || 0));

      let totalActiveDebts = 0;
      debts.forEach(d => {
        if (d.type === 'payable' && d.status !== 'paid') totalActiveDebts += Number(d.remaining_amount || 0);
      });

      res.json({
        total_users: users.length,
        total_families: families.length,
        total_transactions: transactions.length,
        total_system_balance: totalSystemBalance,
        total_savings_balance: totalSavingsBalance,
        total_active_debts: totalActiveDebts
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async getUsers(req, res) {
    try {
      const users = await db.query('SELECT id, name, email, role, family_id, created_at FROM users ORDER BY id DESC');
      res.json(users);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
};
