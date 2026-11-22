import { db } from '../config/database.js';
import { WalletService } from './wallet.service.js';
import { AuthService } from './auth.service.js';

export const SavingService = {
  async createGoal(userId, goalName, targetAmount, targetDate = null, scope = 'personal', familyId = null) {
    const numTarget = Number(targetAmount);
    if (numTarget <= 0) throw new Error('Target amount must be greater than 0');

    const insertRes = await db.query(
      'INSERT INTO savings (user_id, family_id, goal_name, target_amount, current_amount, target_date, scope, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, familyId, goalName.trim(), numTarget, 0, targetDate, scope, 'active']
    );

    return {
      id: insertRes.insertId,
      user_id: userId,
      family_id: familyId,
      goal_name: goalName.trim(),
      target_amount: numTarget,
      current_amount: 0,
      target_date: targetDate,
      scope,
      status: 'active',
      progress_percentage: 0
    };
  },

  async getGoalContributions(savingId) {
    const rows = await db.query(
      `SELECT t.user_id, u.name as user_name, SUM(t.amount) as total_contributed
       FROM transactions t
       JOIN users u ON t.user_id = u.id
       WHERE t.destination_saving_id = ? AND t.type = 'saving_deposit'
       GROUP BY t.user_id, u.name
       ORDER BY total_contributed DESC`,
      [savingId]
    );
    return (rows || []).map(r => ({
      user_id: r.user_id,
      user_name: r.user_name,
      total_contributed: Number(r.total_contributed)
    }));
  },

  async getGoalById(savingId) {
    const rows = await db.query('SELECT * FROM savings WHERE id = ?', [savingId]);
    if (!rows || rows.length === 0) return null;
    const goal = rows[0];
    const target = Number(goal.target_amount);
    const current = Number(goal.current_amount);
    const progress = target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0;
    const contributions = await this.getGoalContributions(goal.id);
    return {
      ...goal,
      target_amount: target,
      current_amount: current,
      progress_percentage: progress,
      contributions
    };
  },

  async getGoals(userId, familyId = null, familyView = false) {
    let sql = 'SELECT * FROM savings WHERE ';
    const params = [];

    if (familyView && familyId) {
      sql += '((family_id = ? AND scope = "family") OR user_id = ?)';
      params.push(familyId, userId);
    } else {
      sql += 'user_id = ?';
      params.push(userId);
    }
    sql += ' ORDER BY id DESC';

    const rows = await db.query(sql, params);
    const result = [];
    for (const goal of (rows || [])) {
      const target = Number(goal.target_amount);
      const current = Number(goal.current_amount);
      const progress = target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0;
      const contributions = await this.getGoalContributions(goal.id);
      result.push({
        ...goal,
        target_amount: target,
        current_amount: current,
        progress_percentage: progress,
        contributions
      });
    }
    return result;
  },

  async deposit(userId, walletId, savingId, amount, date = new Date().toISOString().split('T')[0], notes = '', idempotencyKey = null) {
    const numAmount = Number(amount);
    if (!Number.isFinite(numAmount) || numAmount <= 0) throw new Error('Deposit amount must be greater than 0');

    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');
    if (wallet.user_id !== userId) {
      throw new Error('Akses ditolak: Dompet bukan milik Anda');
    }

    if (Number(wallet.balance) < numAmount) {
      throw new Error('Insufficient balance in wallet to deposit into savings');
    }

    const goal = await this.getGoalById(savingId);
    if (!goal) throw new Error('Savings goal not found');

    const user = await AuthService.getUserById(userId);
    const isOwner = goal.user_id === userId;
    const isFamilyShared = goal.scope === 'family' && user?.family_id && goal.family_id === user.family_id;
    if (!isOwner && !isFamilyShared) {
      throw new Error('Akses ditolak: Anda tidak memiliki akses ke tabungan ini');
    }

    if (idempotencyKey) {
      const existing = await db.query(
        'SELECT * FROM transactions WHERE idempotency_key = ? LIMIT 1',
        [idempotencyKey]
      );
      if (existing && existing.length > 0) {
        const curGoal = await this.getGoalById(savingId);
        const curWallet = await WalletService.getWalletById(walletId);
        return {
          success: true,
          wallet_id: walletId,
          new_wallet_balance: curWallet ? Number(curWallet.balance) : 0,
          saving_id: savingId,
          new_saving_amount: curGoal ? Number(curGoal.current_amount) : 0,
          status: curGoal ? curGoal.status : 'active',
          already_processed: true,
          idempotency_key: idempotencyKey
        };
      }
    }

    return await db.transaction(async (trx) => {
      const newWalletBal = Number(wallet.balance) - numAmount;
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newWalletBal, walletId]);

      const newSavingAmount = Number(goal.current_amount) + numAmount;
      const newStatus = newSavingAmount >= Number(goal.target_amount) ? 'completed' : 'active';
      await trx.query('UPDATE savings SET current_amount = ?, status = ? WHERE id = ?', [newSavingAmount, newStatus, savingId]);

      await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, goal.family_id, walletId, null, 'saving_deposit', numAmount, date, notes || `Setor tabungan: ${goal.goal_name}`, null, savingId, null, goal.scope, idempotencyKey]
      );

      return {
        success: true,
        wallet_id: walletId,
        new_wallet_balance: newWalletBal,
        saving_id: savingId,
        new_saving_amount: newSavingAmount,
        status: newStatus,
        idempotency_key: idempotencyKey
      };
    });
  },

  async withdraw(userId, savingId, walletId, amount, date = new Date().toISOString().split('T')[0], notes = '') {
    const numAmount = Number(amount);
    if (!Number.isFinite(numAmount) || numAmount <= 0) throw new Error('Withdrawal amount must be greater than 0');

    const goal = await this.getGoalById(savingId);
    if (!goal) throw new Error('Savings goal not found');

    const user = await AuthService.getUserById(userId);
    const isOwner = goal.user_id === userId;
    const isFamilyShared = goal.scope === 'family' && user?.family_id && goal.family_id === user.family_id;
    if (!isOwner && !isFamilyShared) {
      throw new Error('Akses ditolak: Anda tidak memiliki akses ke tabungan ini');
    }

    if (Number(goal.current_amount) < numAmount) {
      throw new Error('Insufficient savings balance for withdrawal');
    }

    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');
    if (wallet.user_id !== userId) {
      throw new Error('Akses ditolak: Dompet bukan milik Anda');
    }

    return await db.transaction(async (trx) => {
      const newSavingAmount = Number(goal.current_amount) - numAmount;
      await trx.query('UPDATE savings SET current_amount = ?, status = "active" WHERE id = ?', [newSavingAmount, savingId]);

      const newWalletBal = Number(wallet.balance) + numAmount;
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newWalletBal, walletId]);

      await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, goal.family_id, walletId, null, 'saving_withdrawal', numAmount, date, notes || `Tarik tabungan: ${goal.goal_name}`, null, savingId, null, goal.scope]
      );

      return {
        success: true,
        saving_id: savingId,
        new_saving_amount: newSavingAmount,
        wallet_id: walletId,
        new_wallet_balance: newWalletBal
      };
    });
  }
};
