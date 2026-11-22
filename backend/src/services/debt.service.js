import { db } from '../config/database.js';
import { WalletService } from './wallet.service.js';
import { AuthService } from './auth.service.js';

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
  async createDebt(userId, type, personName, amount, dueDate, notes = '', scope = 'personal', familyId = null, companyId = null, installmentsCount = 1, idempotencyKey = null) {
    const numAmount = Number(amount);
    if (numAmount <= 0) throw new Error('Debt amount must be greater than 0');
    if (!['payable', 'receivable'].includes(type)) {
      throw new Error("Invalid debt type: must be 'payable' or 'receivable'");
    }

    if (idempotencyKey) {
      const existing = await db.query(
        'SELECT * FROM debts WHERE idempotency_key = ? LIMIT 1',
        [idempotencyKey]
      );
      if (existing && existing.length > 0) {
        const d = existing[0];
        return {
          id: d.id,
          user_id: d.user_id,
          family_id: d.family_id,
          company_id: d.company_id,
          type: d.type,
          person_name: d.person_name,
          total_amount: Number(d.total_amount),
          remaining_amount: Number(d.remaining_amount),
          installments_count: Number(d.installments_count || 1),
          installment_amount: Math.round(Number(d.total_amount) / Math.max(1, Number(d.installments_count || 1))),
          due_date: d.due_date,
          status: d.status,
          scope: d.scope,
          notes: d.notes,
          already_processed: true,
          idempotency_key: idempotencyKey
        };
      }
    }

    const numInstallments = Math.max(1, Number(installmentsCount) || 1);
    const targetScope = ['personal', 'family', 'company'].includes(scope) ? scope : 'personal';
    const famId = targetScope === 'family' ? familyId : null;
    const compId = targetScope === 'company' ? companyId : null;

    const insertRes = await db.query(
      'INSERT INTO debts (user_id, family_id, company_id, type, person_name, total_amount, remaining_amount, installments_count, due_date, status, scope, notes, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, famId, compId, type, personName.trim(), numAmount, numAmount, numInstallments, dueDate, 'unpaid', targetScope, notes || '', idempotencyKey]
    );

    return {
      id: insertRes.insertId,
      user_id: userId,
      family_id: famId,
      company_id: compId,
      type,
      person_name: personName.trim(),
      total_amount: numAmount,
      remaining_amount: numAmount,
      installments_count: numInstallments,
      installment_amount: Math.round(numAmount / numInstallments),
      due_date: dueDate,
      status: 'unpaid',
      scope: targetScope,
      notes: notes || ''
    };
  },

  async getDebtById(debtId) {
    const rows = await db.query('SELECT * FROM debts WHERE id = ?', [debtId]);
    if (!rows || rows.length === 0) return null;
    const debt = rows[0];
    const total = Number(debt.total_amount);
    const count = Number(debt.installments_count || 1);
    return {
      ...debt,
      total_amount: total,
      remaining_amount: Number(debt.remaining_amount),
      installments_count: count,
      installment_amount: Math.round(total / count),
      computed_status: computeDueStatus(debt)
    };
  },

  async getDebts(userId, familyId = null, companyIdOrFamilyView = null, viewModeParam = null) {
    let companyId = null;
    let viewMode = 'personal';

    if (typeof companyIdOrFamilyView === 'boolean') {
      viewMode = companyIdOrFamilyView ? 'family' : 'personal';
    } else {
      companyId = companyIdOrFamilyView;
      viewMode = viewModeParam || (familyId && viewModeParam === 'family' ? 'family' : 'personal');
    }

    let sql = 'SELECT * FROM debts WHERE ';
    const params = [];

    if (viewMode === 'family' && familyId) {
      sql += '((family_id = ? AND scope = "family") OR (user_id = ? AND scope = "family"))';
      params.push(familyId, userId);
    } else if (viewMode === 'company' && companyId) {
      sql += '((company_id = ? AND scope = "company") OR (user_id = ? AND scope = "company"))';
      params.push(companyId, userId);
    } else {
      sql += 'user_id = ?';
      params.push(userId);
    }
    sql += ' ORDER BY due_date ASC';

    const rows = await db.query(sql, params);
    return (rows || []).map(debt => {
      const total = Number(debt.total_amount);
      const count = Number(debt.installments_count || 1);
      return {
        ...debt,
        total_amount: total,
        remaining_amount: Number(debt.remaining_amount),
        installments_count: count,
        installment_amount: Math.round(total / count),
        computed_status: computeDueStatus(debt)
      };
    });
  },

  async getDebtReminders(userId, familyId = null, companyId = null, today = new Date().toISOString().split('T')[0]) {
    const allDebts = await db.query('SELECT * FROM debts WHERE status != "paid" ORDER BY due_date ASC');

    const relevant = (allDebts || []).filter(d => {
      const rem = Number(d.remaining_amount || 0);
      if (rem <= 0 || d.status === 'paid') return false;

      // 1. Personal debt of this user
      if (d.user_id === userId && (d.scope === 'personal' || !d.scope)) return true;
      // 2. Family debt for family members
      if (familyId && d.family_id === familyId && d.scope === 'family') return true;
      // 3. Company debt for company members
      if (companyId && d.company_id === companyId && d.scope === 'company') return true;
      return false;
    });

    return relevant.map(d => {
      const remaining = Number(d.remaining_amount);
      const total = Number(d.total_amount);
      const count = Number(d.installments_count || 1);
      const installmentAmt = Math.round(total / count);

      const dueDateObj = new Date(d.due_date);
      const todayObj = new Date(today);
      const diffDays = Math.ceil((dueDateObj - todayObj) / (1000 * 60 * 60 * 24));
      const isOverdue = diffDays < 0;

      let scopeLabel = 'Pribadi';
      if (d.scope === 'family') scopeLabel = 'Keluarga';
      else if (d.scope === 'company') scopeLabel = 'Perusahaan';

      let urgency = 'normal';
      let title = '';
      if (isOverdue) {
        urgency = 'high';
        title = `Tagihan Lewat Jatuh Tempo (${scopeLabel})`;
      } else if (diffDays === 0) {
        urgency = 'high';
        title = `Jatuh Tempo Hari Ini (${scopeLabel})`;
      } else if (diffDays <= 3) {
        urgency = 'medium';
        title = `Jatuh Tempo dalam ${diffDays} Hari (${scopeLabel})`;
      } else {
        urgency = 'low';
        title = `Pengingat Tagihan (${scopeLabel})`;
      }

      const actionText = d.type === 'payable' ? 'Hutang kepada' : 'Piutang dari';
      const cicilanText = count > 1 ? ` (${count}x cicilan @ Rp ${installmentAmt.toLocaleString('id-ID')})` : '';
      const message = `${actionText} ${d.person_name} sisa Rp ${remaining.toLocaleString('id-ID')}${cicilanText} jatuh tempo ${d.due_date}.`;

      return {
        id: d.id,
        debt_id: d.id,
        type: d.type,
        person_name: d.person_name,
        scope: d.scope || 'personal',
        scope_label: scopeLabel,
        total_amount: total,
        remaining_amount: remaining,
        installments_count: count,
        installment_amount: installmentAmt,
        due_date: d.due_date,
        days_left: diffDays,
        is_overdue: isOverdue,
        is_due_today: diffDays === 0,
        urgency,
        title,
        message
      };
    });
  },

  async recordPayment(userId, debtId, walletId, paymentAmount, date = new Date().toISOString().split('T')[0], notes = '') {
    const numPayment = Number(paymentAmount);
    if (!Number.isFinite(numPayment) || numPayment <= 0) throw new Error('Payment amount must be greater than 0');

    const debt = await this.getDebtById(debtId);
    if (!debt) throw new Error('Debt record not found');
    if (debt.status === 'paid' || debt.remaining_amount <= 0) {
      throw new Error('Debt is already fully paid');
    }

    const user = await AuthService.getUserById(userId);
    const isOwner = debt.user_id === userId;
    const isFamilyDebt = debt.scope === 'family' && user?.family_id && debt.family_id === user.family_id;
    const isCompanyDebt = debt.scope === 'company' && user?.company_id && debt.company_id === user.company_id;
    if (!isOwner && !isFamilyDebt && !isCompanyDebt) {
      throw new Error('Akses ditolak: Tagihan bukan milik Anda');
    }

    const wallet = await WalletService.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');
    if (wallet.user_id !== userId) {
      throw new Error('Akses ditolak: Dompet bukan milik Anda');
    }

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
        'INSERT INTO transactions (user_id, family_id, company_id, wallet_id, category_id, type, amount, transaction_date, notes, destination_wallet_id, destination_saving_id, debt_id, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [userId, debt.family_id, debt.company_id || null, walletId, null, txType, numPayment, date, memo, null, null, debtId, debt.scope]
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
