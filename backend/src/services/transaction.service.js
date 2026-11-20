import { db } from '../config/database.js';
import { WalletService } from './wallet.service.js';

export const TransactionService = {
  async recordIncome(userId, walletId, categoryId, amount, date, notes = '', isFamily = false, familyId = null) {
    if (Number(amount) <= 0) throw new Error('Amount must be greater than 0');
    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    return await db.transaction(async (trx) => {
      const scope = isFamily ? 'family' : 'personal';
      const insertRes = await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, familyId, walletId, categoryId, 'income', Number(amount), date, notes, null, null, null, scope]
      );

      const newBalance = Number(wallet.balance) + Number(amount);
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newBalance, walletId]);

      return {
        id: insertRes.insertId,
        user_id: userId,
        wallet_id: walletId,
        type: 'income',
        amount: Number(amount),
        date,
        new_wallet_balance: newBalance
      };
    });
  },

  async recordExpense(userId, walletId, categoryId, amount, date, notes = '', isFamily = false, familyId = null) {
    if (Number(amount) <= 0) throw new Error('Amount must be greater than 0');
    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    return await db.transaction(async (trx) => {
      const scope = isFamily ? 'family' : 'personal';
      const insertRes = await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, familyId, walletId, categoryId, 'expense', Number(amount), date, notes, null, null, null, scope]
      );

      const newBalance = Number(wallet.balance) - Number(amount);
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newBalance, walletId]);

      return {
        id: insertRes.insertId,
        user_id: userId,
        wallet_id: walletId,
        type: 'expense',
        amount: Number(amount),
        date,
        new_wallet_balance: newBalance
      };
    });
  },

  async transfer(userId, fromWalletId, toWalletId, amount, date, notes = '') {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Amount must be greater than 0');
    if (fromWalletId === toWalletId) throw new Error('Source and destination wallets must be different');

    const fromWallet = await WalletService.getWalletById(fromWalletId);
    const toWallet = await WalletService.getWalletById(toWalletId);
    if (!fromWallet || !toWallet) throw new Error('Wallet not found');

    if (Number(fromWallet.balance) < numAmount) {
      throw new Error('Insufficient balance in source wallet');
    }

    return await db.transaction(async (trx) => {
      // Record transfer transaction
      await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, null, fromWalletId, null, 'transfer', numAmount, date, notes, toWalletId, null, null, 'personal']
      );

      // Decrement source, increment destination
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
    let rows = await db.query('SELECT * FROM transactions');
    if (familyView && familyId) {
      rows = rows.filter(r => (r.family_id === familyId && r.scope === 'family') || r.user_id === userId);
    } else {
      rows = rows.filter(r => r.user_id === userId);
    }

    if (filters.type) {
      rows = rows.filter(r => r.type === filters.type);
    }
    if (filters.wallet_id) {
      rows = rows.filter(r => r.wallet_id === Number(filters.wallet_id));
    }
    if (filters.startDate) {
      rows = rows.filter(r => r.transaction_date >= filters.startDate);
    }
    if (filters.endDate) {
      rows = rows.filter(r => r.transaction_date <= filters.endDate);
    }

    return rows;
  },

  async getSummary(userId, familyId = null, familyView = false) {
    const transactions = await this.getTransactions(userId, familyId, familyView);
    let totalIncome = 0;
    let totalExpense = 0;

    for (const tx of transactions) {
      if (tx.type === 'income') totalIncome += Number(tx.amount);
      if (tx.type === 'expense') totalExpense += Number(tx.amount);
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
