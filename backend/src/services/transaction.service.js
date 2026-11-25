import { db } from '../config/database.js';
import { WalletService } from './wallet.service.js';

export const TransactionService = {
  async recordIncome(userId, walletId, categoryId, amount, date, notes = '', isFamily = false, familyId = null, idempotencyKey = null, companyId = null, isCompany = false) {
    const numAmount = Number(amount);
    if (!Number.isFinite(numAmount) || numAmount <= 0) throw new Error('Amount must be greater than 0');
    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    const isOwner = wallet.user_id === userId;
    const isFamilyWallet = isFamily && familyId && wallet.family_id === familyId && wallet.scope === 'family';
    const isCompanyWallet = isCompany && companyId && wallet.company_id === companyId && wallet.scope === 'company';
    if (!isOwner && !isFamilyWallet && !isCompanyWallet) {
      throw new Error('Akses ditolak: Dompet bukan milik Anda atau organisasi Anda');
    }

    if (idempotencyKey) {
      const existing = await db.query(
        'SELECT * FROM transactions WHERE idempotency_key = ? LIMIT 1',
        [idempotencyKey]
      );
      if (existing && existing.length > 0) {
        const tx = existing[0];
        const curWallet = await WalletService.getWalletById(tx.wallet_id);
        return {
          id: tx.id,
          user_id: tx.user_id,
          wallet_id: tx.wallet_id,
          type: tx.type,
          amount: Number(tx.amount),
          date: tx.transaction_date,
          new_wallet_balance: curWallet ? Number(curWallet.balance) : 0,
          already_processed: true,
          idempotency_key: idempotencyKey
        };
      }
    }

    return await db.transaction(async (trx) => {
      let validCategoryId = null;
      if (categoryId) {
        const catRows = await trx.query('SELECT id FROM categories WHERE id = ?', [Number(categoryId)]);
        if (catRows && catRows.length > 0) {
          validCategoryId = Number(categoryId);
        }
      }

      const scope = isCompany ? 'company' : (isFamily ? 'family' : 'personal');
      const insertRes = await trx.query(
        'INSERT INTO transactions (user_id, family_id, company_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, isFamily ? familyId : null, isCompany ? companyId : null, walletId, validCategoryId, 'income', numAmount, date, notes, null, null, null, scope, idempotencyKey]
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
        new_wallet_balance: newBalance,
        idempotency_key: idempotencyKey
      };
    });
  },

  async recordExpense(userId, walletId, categoryId, amount, date, notes = '', isFamily = false, familyId = null, idempotencyKey = null, companyId = null, isCompany = false) {
    const numAmount = Number(amount);
    if (!Number.isFinite(numAmount) || numAmount <= 0) throw new Error('Amount must be greater than 0');
    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    const isOwner = wallet.user_id === userId;
    const isFamilyWallet = isFamily && familyId && wallet.family_id === familyId && wallet.scope === 'family';
    const isCompanyWallet = isCompany && companyId && wallet.company_id === companyId && wallet.scope === 'company';
    if (!isOwner && !isFamilyWallet && !isCompanyWallet) {
      throw new Error('Akses ditolak: Dompet bukan milik Anda atau organisasi Anda');
    }

    if (Number(wallet.balance) < numAmount) {
      throw new Error('Saldo dompet tidak mencukupi');
    }

    if (idempotencyKey) {
      const existing = await db.query(
        'SELECT * FROM transactions WHERE idempotency_key = ? LIMIT 1',
        [idempotencyKey]
      );
      if (existing && existing.length > 0) {
        const tx = existing[0];
        const curWallet = await WalletService.getWalletById(tx.wallet_id);
        return {
          id: tx.id,
          user_id: tx.user_id,
          wallet_id: tx.wallet_id,
          type: tx.type,
          amount: Number(tx.amount),
          date: tx.transaction_date,
          new_wallet_balance: curWallet ? Number(curWallet.balance) : 0,
          already_processed: true,
          idempotency_key: idempotencyKey
        };
      }
    }

    return await db.transaction(async (trx) => {
      const scope = isCompany ? 'company' : (isFamily ? 'family' : 'personal');
      let finalNotes = notes ? notes.trim() : '';
      if (isCompany && !isCompanyWallet && !finalNotes.includes('Talangan Pribadi')) {
        finalNotes = finalNotes ? `${finalNotes} (Talangan Pribadi)` : 'Talangan Pribadi';
      }

      let validCategoryId = null;
      if (categoryId) {
        const catRows = await trx.query('SELECT id FROM categories WHERE id = ?', [Number(categoryId)]);
        if (catRows && catRows.length > 0) {
          validCategoryId = Number(categoryId);
        }
      }

      const insertRes = await trx.query(
        'INSERT INTO transactions (user_id, family_id, company_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, isFamily ? familyId : null, isCompany ? companyId : null, walletId, validCategoryId, 'expense', numAmount, date, finalNotes, null, null, null, scope, idempotencyKey]
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
        new_wallet_balance: newBalance,
        idempotency_key: idempotencyKey
      };
    });
  },

  async transfer(userId, fromWalletId, toWalletId, amount, date, notes = '', idempotencyKey = null) {
    const numAmount = Number(amount);
    if (!Number.isFinite(numAmount) || numAmount <= 0) throw new Error('Amount must be greater than 0');
    if (Number(fromWalletId) === Number(toWalletId)) throw new Error('Source and destination wallets must be different');

    const fromWallet = await WalletService.getWalletById(fromWalletId);
    const toWallet = await WalletService.getWalletById(toWalletId);
    if (!fromWallet || !toWallet) throw new Error('Wallet not found');

    if (fromWallet.user_id !== userId) {
      throw new Error('Akses ditolak: Dompet sumber bukan milik Anda');
    }

    if (Number(fromWallet.balance) < numAmount) {
      throw new Error('Insufficient balance in source wallet');
    }

    if (idempotencyKey) {
      const existing = await db.query(
        'SELECT * FROM transactions WHERE idempotency_key = ? LIMIT 1',
        [idempotencyKey]
      );
      if (existing && existing.length > 0) {
        const curFrom = await WalletService.getWalletById(fromWalletId);
        const curTo = await WalletService.getWalletById(toWalletId);
        return {
          id: existing[0].id,
          success: true,
          from_wallet_balance: curFrom ? Number(curFrom.balance) : 0,
          to_wallet_balance: curTo ? Number(curTo.balance) : 0,
          already_processed: true,
          idempotency_key: idempotencyKey
        };
      }
    }

    return await db.transaction(async (trx) => {
      const insertRes = await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, null, fromWalletId, null, 'transfer', numAmount, date, notes, toWalletId, null, null, 'personal', idempotencyKey]
      );

      const newFromBal = Number(fromWallet.balance) - numAmount;
      const newToBal = Number(toWallet.balance) + numAmount;

      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newFromBal, fromWalletId]);
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newToBal, toWalletId]);

      return {
        id: insertRes.insertId,
        success: true,
        from_wallet_balance: newFromBal,
        to_wallet_balance: newToBal,
        idempotency_key: idempotencyKey
      };
    });
  },

  async getTransactions(userId, familyId = null, familyView = false, filters = {}, companyId = null, companyView = false) {
    let sql = 'SELECT t.*, u.name as user_name, c.name as category_name, c.color as category_color, c.icon as category_icon FROM transactions t LEFT JOIN users u ON t.user_id = u.id LEFT JOIN categories c ON t.category_id = c.id WHERE ';
    const params = [];

    if (companyView && companyId) {
      sql += '((t.company_id = ? AND t.scope = "company") OR t.user_id = ?)';
      params.push(companyId, userId);
    } else if (familyView && familyId) {
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
      'SELECT t.*, u.name as user_name, c.name as category_name, c.color as category_color, c.icon as category_icon FROM transactions t LEFT JOIN users u ON t.user_id = u.id LEFT JOIN categories c ON t.category_id = c.id WHERE t.user_id = ? AND t.family_id = ? AND t.scope = "family" ORDER BY t.transaction_date DESC, t.id DESC',
      [targetUserId, familyId]
    );
    let totalIncome = 0;
    let totalExpense = 0;
    for (const tx of transactions) {
      if (tx.type === 'income') totalIncome += Number(tx.amount);
      if (tx.type === 'expense' || tx.type === 'saving_deposit') totalExpense += Number(tx.amount);
    }
    const memberRows = await db.query('SELECT id, name, email, role FROM users WHERE id = ?', [targetUserId]);
    const wallets = await db.query('SELECT balance FROM wallets WHERE user_id = ? AND (family_id = ? OR scope = "family")', [targetUserId, familyId]);
    const totalBalance = (wallets || []).reduce((sum, w) => sum + Number(w.balance || 0), 0);

    return {
      member: memberRows && memberRows.length > 0 ? memberRows[0] : null,
      total_balance: totalBalance,
      total_income: totalIncome,
      total_expense: totalExpense,
      transactions: transactions || []
    };
  },

  async getSummary(userId, familyId = null, familyView = false, companyId = null, companyView = false) {
    const transactions = await this.getTransactions(userId, familyId, familyView, {}, companyId, companyView);
    let totalIncome = 0;
    let totalExpense = 0;

    for (const tx of transactions) {
      if (tx.type === 'income') totalIncome += Number(tx.amount);
      if (tx.type === 'expense' || tx.type === 'saving_deposit') totalExpense += Number(tx.amount);
    }

    const wallets = await WalletService.getWallets(userId, familyId, familyView, companyId, companyView);
    const totalBalance = wallets.reduce((acc, w) => acc + Number(w.balance), 0);

    return {
      total_balance: totalBalance,
      total_income: totalIncome,
      total_expense: totalExpense,
      net_cashflow: totalIncome - totalExpense
    };
  }
};
