import { db } from '../config/database.js';
import { WalletService } from './wallet.service.js';

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

  async getGoalById(savingId) {
    const rows = await db.query('SELECT * FROM savings WHERE id = ?', [savingId]);
    if (!rows || rows.length === 0) return null;
    const goal = rows[0];
    const target = Number(goal.target_amount);
    const current = Number(goal.current_amount);
    const progress = target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0;
    return {
      ...goal,
      target_amount: target,
      current_amount: current,
      progress_percentage: progress
    };
  },

  async getGoals(userId, familyId = null, familyView = false) {
    let rows = await db.query('SELECT * FROM savings');
    if (familyView && familyId) {
      rows = rows.filter(r => (r.family_id === familyId && r.scope === 'family') || r.user_id === userId);
    } else {
      rows = rows.filter(r => r.user_id === userId);
    }

    return rows.map(goal => {
      const target = Number(goal.target_amount);
      const current = Number(goal.current_amount);
      const progress = target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0;
      return {
        ...goal,
        target_amount: target,
        current_amount: current,
        progress_percentage: progress
      };
    });
  },

  async deposit(userId, walletId, savingId, amount, date = new Date().toISOString().split('T')[0], notes = '') {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Deposit amount must be greater than 0');

    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    if (Number(wallet.balance) < numAmount) {
      throw new Error('Insufficient balance in wallet to deposit into savings');
    }

    const goal = await this.getGoalById(savingId);
    if (!goal) throw new Error('Savings goal not found');

    return await db.transaction(async (trx) => {
      // 1. Decrement wallet balance
      const newWalletBal = Number(wallet.balance) - numAmount;
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newWalletBal, walletId]);

      // 2. Increment saving current_amount
      const newSavingAmount = Number(goal.current_amount) + numAmount;
      const newStatus = newSavingAmount >= Number(goal.target_amount) ? 'completed' : 'active';
      await trx.query('UPDATE savings SET current_amount = ?, status = ? WHERE id = ?', [newSavingAmount, newStatus, savingId]);

      // 3. Log transaction as saving_deposit
      await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, goal.family_id, walletId, null, 'saving_deposit', numAmount, date, notes || `Setor tabungan: ${goal.goal_name}`, null, savingId, null, goal.scope]
      );

      return {
        success: true,
        wallet_id: walletId,
        new_wallet_balance: newWalletBal,
        saving_id: savingId,
        new_saving_amount: newSavingAmount,
        status: newStatus
      };
    });
  },

  async withdraw(userId, savingId, walletId, amount, date = new Date().toISOString().split('T')[0], notes = '') {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Withdrawal amount must be greater than 0');

    const goal = await this.getGoalById(savingId);
    if (!goal) throw new Error('Savings goal not found');

    if (Number(goal.current_amount) < numAmount) {
      throw new Error('Insufficient savings balance for withdrawal');
    }

    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    return await db.transaction(async (trx) => {
      // 1. Decrement saving amount
      const newSavingAmount = Number(goal.current_amount) - numAmount;
      await trx.query('UPDATE savings SET current_amount = ?, status = "active" WHERE id = ?', [newSavingAmount, savingId]);

      // 2. Increment wallet balance
      const newWalletBal = Number(wallet.balance) + numAmount;
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newWalletBal, walletId]);

      // 3. Log transaction as saving_withdrawal
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
