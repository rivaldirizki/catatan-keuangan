import { db } from '../config/database.js';
import { WalletService } from './wallet.service.js';

function computeDueStatus(debt, today = new Date().toISOString().split('T')[0]) {
  if (debt.status === 'paid' || Number(debt.remaining_amount) <= 0) {
    return 'paid';
  }
  if (debt.due_date < today) {
    return 'overdue';
  }
  const diffDays = Math.ceil((new Date(debt.due_date) - new Date(today)) / (1000 * 60 * 60 * 24));
  if (diffDays <= 3) {
    return 'due_soon';
  }
  return Number(debt.remaining_amount) < Number(debt.total_amount) ? 'partially_paid' : 'unpaid';
}

export const DebtService = {
  async createDebt(userId, type, personName, amount, dueDate, notes = '', scope = 'personal', familyId = null) {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Debt amount must be greater than 0');
    if (!['payable', 'receivable'].includes(type)) {
      throw new Error("Invalid debt type: must be 'payable' or 'receivable'");
    }

    const insertRes = await db.query(
      'INSERT INTO debts (user_id, family_id, type, person_name, total_amount, remaining_amount, due_date, status, scope, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, familyId, type, personName.trim(), numAmount, numAmount, dueDate, 'unpaid', scope, notes]
    );

    return {
      id: insertRes.insertId,
      user_id: userId,
      family_id: familyId,
      type,
      person_name: personName.trim(),
      total_amount: numAmount,
      remaining_amount: numAmount,
      due_date: dueDate,
      status: 'unpaid',
      scope,
      notes
    };
  },

  async getDebtById(debtId) {
    const rows = await db.query('SELECT * FROM debts WHERE id = ?', [debtId]);
    if (!rows || rows.length === 0) return null;
    const debt = rows[0];
    return {
      ...debt,
      total_amount: Number(debt.total_amount),
      remaining_amount: Number(debt.remaining_amount),
      computed_status: computeDueStatus(debt)
    };
  },

  async getDebts(userId, familyId = null, familyView = false) {
    let sql = 'SELECT * FROM debts WHERE ';
    const params = [];

    if (familyView && familyId) {
      sql += '((family_id = ? AND scope = "family") OR user_id = ?)';
      params.push(familyId, userId);
    } else {
      sql += 'user_id = ?';
      params.push(userId);
    }
    sql += ' ORDER BY due_date ASC';

    const rows = await db.query(sql, params);
    return (rows || []).map(debt => ({
      ...debt,
      total_amount: Number(debt.total_amount),
      remaining_amount: Number(debt.remaining_amount),
      computed_status: computeDueStatus(debt)
    }));
  },

  async recordPayment(userId, debtId, walletId, paymentAmount, date = new Date().toISOString().split('T')[0], notes = '') {
    const numPayment = Number(paymentAmount);
    if (numPayment <= 0) throw new Error('Payment amount must be greater than 0');

    const debt = await this.getDebtById(debtId);
    if (!debt) throw new Error('Debt record not found');
    if (debt.status === 'paid' || debt.remaining_amount <= 0) {
      throw new Error('Debt is already fully paid');
    }

    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');

    if (debt.type === 'payable' && Number(wallet.balance) < numPayment) {
      throw new Error('Insufficient wallet balance to pay debt');
    }

    return await db.transaction(async (trx) => {
      const newRemaining = Math.max(0, Number(debt.remaining_amount) - numPayment);
      const newStatus = newRemaining === 0 ? 'paid' : 'partially_paid';

      await trx.query('UPDATE debts SET remaining_amount = ?, status = ? WHERE id = ?', [newRemaining, newStatus, debtId]);

      const walletDelta = debt.type === 'payable' ? -numPayment : numPayment;
      const newWalletBal = Number(wallet.balance) + walletDelta;
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newWalletBal, walletId]);

      const txType = 'debt_payment';
      const memo = notes || (debt.type === 'payable' ? `Bayar hutang ke: ${debt.person_name}` : `Terima piutang dari: ${debt.person_name}`);
      await trx.query(
        'INSERT INTO transactions (user_id, family_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, debt.family_id, walletId, null, txType, numPayment, date, memo, null, null, debtId, debt.scope]
      );

      return {
        success: true,
        debt_id: debtId,
        remaining_amount: newRemaining,
        status: newStatus,
        wallet_id: walletId,
        new_wallet_balance: newWalletBal
      };
    });
  }
};
