import { db } from '../config/database.js';
import { WalletService } from './wallet.service.js';

export const TransactionService = {
  async recordIncome(userId, walletId, categoryId, amount, date, notes = '', isFamily = false, familyId = null) {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Amount must be greater than 0');
    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    return await db.transaction(async (trx) => {
      const scope = isFamily ? 'family' : 'personal';
      const insertRes = await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, familyId, walletId, categoryId, 'income', numAmount, date, notes, null, null, null, scope]
      );

      const newBalance = Number(wallet.balance) + numAmount;
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newBalance, walletId]);

      return {
        id: insertRes.insertId,
        user_id: userId,
        wallet_id: walletId,
        type: 'income',
        amount: numAmount,
        date,
        new_wallet_balance: newBalance
      };
    });
  },

  async recordExpense(userId, walletId, categoryId, amount, date, notes = '', isFamily = false, familyId = null) {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Amount must be greater than 0');
    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    return await db.transaction(async (trx) => {
      const scope = isFamily ? 'family' : 'personal';
      const insertRes = await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, familyId, walletId, categoryId, 'expense', numAmount, date, notes, null, null, null, scope]
      );

      const newBalance = Number(wallet.balance) - numAmount;
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newBalance, walletId]);

      return {
        id: insertRes.insertId,
        user_id: userId,
        wallet_id: walletId,
        type: 'expense',
        amount: numAmount,
        date,
        new_wallet_balance: newBalance
      };
    });
  },

  async transfer(userId, fromWalletId, toWalletId, amount, date, notes = '') {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Amount must be greater than 0');
    if (Number(fromWalletId) === Number(toWalletId)) throw new Error('Source and destination wallets must be different');

    const fromWallet = await WalletService.getWalletById(fromWalletId);
    const toWallet = await WalletService.getWalletById(toWalletId);
    if (!fromWallet || !toWallet) throw new Error('Wallet not found');

    if (Number(fromWallet.balance) < numAmount) {
      throw new Error('Insufficient balance in source wallet');
    }

    return await db.transaction(async (trx) => {
      await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, null, fromWalletId, null, 'transfer', numAmount, date, notes, toWalletId, null, null, 'personal']
      );

      const newFromBal = Number(fromWallet.balance) - numAmount;
      const newToBal = Number(toWallet.balance) + numAmount;

      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newFromBal, fromWalletId]);
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newToBal, toWalletId]);

      return {
        success: true,
        from_wallet_balance: newFromBal,
        to_wallet_balance: newToBal
      };
    });
  },

  async getTransactions(userId, familyId = null, familyView = false, filters = {}) {
    let sql = 'SELECT t.*, u.name as user_name FROM transactions t LEFT JOIN users u ON t.user_id = u.id WHERE ';
    const params = [];

    if (familyView && familyId) {
      sql += '((t.family_id = ? AND t.scope = "family") OR t.user_id = ?)';
      params.push(familyId, userId);
    } else {
      sql += 't.user_id = ?';
      params.push(userId);
    }

    if (filters.user_id) {
      sql += ' AND t.user_id = ?';
      params.push(Number(filters.user_id));
    }
    if (filters.type) {
      sql += ' AND t.type = ?';
      params.push(filters.type);
    }
    if (filters.wallet_id) {
      sql += ' AND t.wallet_id = ?';
      params.push(Number(filters.wallet_id));
    }
    if (filters.startDate) {
      sql += ' AND t.transaction_date >= ?';
      params.push(filters.startDate);
    }
    if (filters.endDate) {
      sql += ' AND t.transaction_date <= ?';
      params.push(filters.endDate);
    }

    sql += ' ORDER BY t.transaction_date DESC, t.id DESC';
    return await db.query(sql, params);
  },

  async getMemberSummary(familyId, targetUserId) {
    const transactions = await db.query(
      'SELECT t.*, u.name as user_name FROM transactions t LEFT JOIN users u ON t.user_id = u.id WHERE t.user_id = ? AND (t.family_id = ? OR t.scope = "family" OR t.user_id = ?) ORDER BY t.transaction_date DESC, t.id DESC',
      [targetUserId, familyId, targetUserId]
    );
    let totalIncome = 0;
    let totalExpense = 0;
    for (const tx of transactions) {
      if (tx.type === 'income') totalIncome += Number(tx.amount);
      if (tx.type === 'expense' || tx.type === 'saving_deposit') totalExpense += Number(tx.amount);
    }
    const memberRows = await db.query('SELECT id, name, email, role FROM users WHERE id = ?', [targetUserId]);
    const wallets = await db.query('SELECT balance FROM wallets WHERE user_id = ?', [targetUserId]);
    const totalBalance = (wallets || []).reduce((sum, w) => sum + Number(w.balance || 0), 0);

    return {
      member: memberRows && memberRows.length > 0 ? memberRows[0] : null,
      total_balance: totalBalance,
      total_income: totalIncome,
      total_expense: totalExpense,
      transactions: transactions || []
    };
  },

  async getSummary(userId, familyId = null, familyView = false) {
    const transactions = await this.getTransactions(userId, familyId, familyView);
    let totalIncome = 0;
    let totalExpense = 0;

    for (const tx of transactions) {
      if (tx.type === 'income') totalIncome += Number(tx.amount);
      if (tx.type === 'expense' || tx.type === 'saving_deposit') totalExpense += Number(tx.amount);
    }

    const wallets = await WalletService.getWallets(userId, familyId, familyView);
    const totalBalance = wallets.reduce((acc, w) => acc + Number(w.balance), 0);

    return {
      total_balance: totalBalance,
      total_income: totalIncome,
      total_expense: totalExpense,
      net_cashflow: totalIncome - totalExpense
    };
  }
};
