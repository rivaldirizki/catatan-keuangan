import { db } from '../config/database.js';

function calculateProjectFinancials(data = {}) {
  const billingAmount = Math.max(0, Number(data.billing_amount) || 0);
  const feePercent = Math.max(0, Number(data.fee_management_percent) || 0);
  const feeManagement = feePercent > 0
    ? Math.round((billingAmount * feePercent) / 100)
    : Math.max(0, Number(data.fee_management) || 0);

  const ppnPercent = Math.max(0, Number(data.ppn_percent) || 0);
  const ppnAmount = ppnPercent > 0
    ? Math.round((billingAmount * ppnPercent) / 100)
    : Math.max(0, Number(data.ppn_amount) || 0);

  const pphPercent = Math.max(0, Number(data.pph_percent) || 0);
  const pphAmount = pphPercent > 0
    ? Math.round((billingAmount * pphPercent) / 100)
    : Math.max(0, Number(data.pph_amount) || 0);

  const nettoAmount = Math.max(0, billingAmount - feeManagement - ppnAmount - pphAmount);

  return {
    billing_amount: billingAmount,
    fee_management_percent: feePercent,
    fee_management: feeManagement,
    ppn_percent: ppnPercent,
    ppn_amount: ppnAmount,
    pph_percent: pphPercent,
    pph_amount: pphAmount,
    netto_amount: nettoAmount
  };
}

function normalizeProjectRow(p) {
  const budget = Number(p.target_budget) || 0;
  const income = Number(p.current_income) || 0;
  const expense = Number(p.current_expense) || 0;
  const netProfit = income - expense;
  const budgetProgress = budget > 0 ? Math.min(100, Math.round((expense / budget) * 100)) : 0;

  const billingAmount = Number(p.billing_amount) || 0;
  const feePercent = Number(p.fee_management_percent) || 0;
  const feeManagement = Number(p.fee_management) || 0;
  const ppnPercent = Number(p.ppn_percent) || 0;
  const ppnAmount = Number(p.ppn_amount) || 0;
  const pphPercent = Number(p.pph_percent) || 0;
  const pphAmount = Number(p.pph_amount) || 0;
  const nettoAmount = p.netto_amount !== undefined && p.netto_amount !== null
    ? Number(p.netto_amount)
    : Math.max(0, billingAmount - feeManagement - ppnAmount - pphAmount);

  return {
    ...p,
    invoice_number: p.invoice_number || null,
    target_budget: budget,
    billing_amount: billingAmount,
    fee_management_percent: feePercent,
    fee_management: feeManagement,
    ppn_percent: ppnPercent,
    ppn_amount: ppnAmount,
    pph_percent: pphPercent,
    pph_amount: pphAmount,
    netto_amount: nettoAmount,
    payment_status: p.payment_status === 'paid' ? 'paid' : 'unpaid',
    current_income: income,
    current_expense: expense,
    net_profit: netProfit,
    budget_progress: budgetProgress
  };
}

export const ProjectService = {
  async createProject(companyId, userId, {
    name,
    description = null,
    target_budget = 0,
    start_date = null,
    end_date = null,
    invoice_number = null,
    billing_amount = 0,
    fee_management_percent = 0,
    fee_management = 0,
    ppn_percent = 0,
    ppn_amount = 0,
    pph_percent = 0,
    pph_amount = 0,
    payment_status = 'unpaid'
  }) {
    if (!name || !name.trim()) {
      throw new Error('Nama proyek wajib diisi');
    }

    const budget = Math.max(0, Number(target_budget) || 0);
    const fin = calculateProjectFinancials({
      billing_amount,
      fee_management_percent,
      fee_management,
      ppn_percent,
      ppn_amount,
      pph_percent,
      pph_amount
    });
    const payStatus = payment_status === 'paid' ? 'paid' : 'unpaid';
    const invNumber = invoice_number ? String(invoice_number).trim() : null;

    const insertRes = await db.query(
      `INSERT INTO projects (company_id, created_by, invoice_number, name, description, target_budget, billing_amount, fee_management_percent, fee_management, ppn_percent, ppn_amount, pph_percent, pph_amount, netto_amount, payment_status, current_income, current_expense, status, start_date, end_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'active', ?, ?)`,
      [
        companyId,
        userId,
        invNumber,
        name.trim(),
        description,
        budget,
        fin.billing_amount,
        fin.fee_management_percent,
        fin.fee_management,
        fin.ppn_percent,
        fin.ppn_amount,
        fin.pph_percent,
        fin.pph_amount,
        fin.netto_amount,
        payStatus,
        start_date,
        end_date
      ]
    );

    return normalizeProjectRow({
      id: insertRes.insertId,
      company_id: companyId,
      created_by: userId,
      invoice_number: invNumber,
      name: name.trim(),
      description,
      target_budget: budget,
      ...fin,
      payment_status: payStatus,
      current_income: 0,
      current_expense: 0,
      status: 'active',
      start_date,
      end_date
    });
  },

  async getProjects(companyId, status = null) {
    let sql = 'SELECT * FROM projects WHERE company_id = ?';
    const params = [companyId];

    if (status) {
      sql += ' AND status = ?';
      params.push(status);
    }
    sql += ' ORDER BY id DESC';

    const projects = await db.query(sql, params);
    if (!projects || projects.length === 0) return [];

    return projects.map(normalizeProjectRow);
  },

  async getProjectById(companyId, projectId) {
    const projects = await db.query(
      'SELECT * FROM projects WHERE id = ? AND company_id = ?',
      [projectId, companyId]
    );
    if (!projects || projects.length === 0) {
      throw new Error('Proyek tidak ditemukan');
    }

    const normalized = normalizeProjectRow(projects[0]);

    // Fetch related transactions
    const transactions = await db.query(
      `SELECT t.*, u.name as user_name, w.name as wallet_name 
       FROM transactions t 
       LEFT JOIN users u ON t.user_id = u.id 
       LEFT JOIN wallets w ON t.wallet_id = w.id 
       WHERE t.project_id = ? 
       ORDER BY t.id DESC`,
      [projectId]
    );

    return {
      ...normalized,
      transactions: transactions || []
    };
  },

  async updateProject(companyId, projectId, data = {}) {
    const existing = await db.query(
      'SELECT * FROM projects WHERE id = ? AND company_id = ?',
      [projectId, companyId]
    );
    if (!existing || existing.length === 0) {
      throw new Error('Proyek tidak ditemukan');
    }
    const p = existing[0];

    const name = data.name !== undefined ? String(data.name).trim() : p.name;
    if (!name) throw new Error('Nama proyek wajib diisi');
    const description = data.description !== undefined ? data.description : p.description;
    const invNumber = data.invoice_number !== undefined
      ? (data.invoice_number ? String(data.invoice_number).trim() : null)
      : p.invoice_number;
    const budget = data.target_budget !== undefined
      ? Math.max(0, Number(data.target_budget) || 0)
      : Number(p.target_budget || 0);

    const fin = calculateProjectFinancials({
      billing_amount: data.billing_amount !== undefined ? data.billing_amount : p.billing_amount,
      fee_management_percent: data.fee_management_percent !== undefined ? data.fee_management_percent : p.fee_management_percent,
      fee_management: data.fee_management !== undefined ? data.fee_management : p.fee_management,
      ppn_percent: data.ppn_percent !== undefined ? data.ppn_percent : p.ppn_percent,
      ppn_amount: data.ppn_amount !== undefined ? data.ppn_amount : p.ppn_amount,
      pph_percent: data.pph_percent !== undefined ? data.pph_percent : p.pph_percent,
      pph_amount: data.pph_amount !== undefined ? data.pph_amount : p.pph_amount
    });
    const payStatus = data.payment_status !== undefined
      ? (data.payment_status === 'paid' ? 'paid' : 'unpaid')
      : (p.payment_status === 'paid' ? 'paid' : 'unpaid');

    await db.query(
      `UPDATE projects SET invoice_number = ?, name = ?, description = ?, target_budget = ?, billing_amount = ?, fee_management_percent = ?, fee_management = ?, ppn_percent = ?, ppn_amount = ?, pph_percent = ?, pph_amount = ?, netto_amount = ?, payment_status = ?
       WHERE id = ? AND company_id = ?`,
      [
        invNumber,
        name,
        description,
        budget,
        fin.billing_amount,
        fin.fee_management_percent,
        fin.fee_management,
        fin.ppn_percent,
        fin.ppn_amount,
        fin.pph_percent,
        fin.pph_amount,
        fin.netto_amount,
        payStatus,
        projectId,
        companyId
      ]
    );

    return normalizeProjectRow({
      ...p,
      invoice_number: invNumber,
      name,
      description,
      target_budget: budget,
      ...fin,
      payment_status: payStatus
    });
  },

  async updatePaymentStatus(companyId, projectId, paymentStatus) {
    if (paymentStatus !== 'paid' && paymentStatus !== 'unpaid') {
      throw new Error('Status pembayaran harus "paid" atau "unpaid"');
    }
    const existing = await db.query(
      'SELECT id FROM projects WHERE id = ? AND company_id = ?',
      [projectId, companyId]
    );
    if (!existing || existing.length === 0) {
      throw new Error('Proyek tidak ditemukan');
    }

    await db.query(
      'UPDATE projects SET payment_status = ? WHERE id = ? AND company_id = ?',
      [paymentStatus, projectId, companyId]
    );
    return { id: projectId, payment_status: paymentStatus };
  },

  async getOutstandingProjects(companyId) {
    const projects = await this.getProjects(companyId);
    let totalBilling = 0;
    let totalFee = 0;
    let totalPpn = 0;
    let totalPph = 0;
    let totalNetto = 0;
    let totalPaidNetto = 0;
    let totalUnpaidNetto = 0;
    let paidCount = 0;
    let unpaidCount = 0;

    const items = projects.map((p, idx) => {
      totalBilling += p.billing_amount;
      totalFee += p.fee_management;
      totalPpn += p.ppn_amount;
      totalPph += p.pph_amount;
      totalNetto += p.netto_amount;
      if (p.payment_status === 'paid') {
        totalPaidNetto += p.netto_amount;
        paidCount++;
      } else {
        totalUnpaidNetto += p.netto_amount;
        unpaidCount++;
      }

      const invoiceAndName = p.invoice_number ? `${p.invoice_number} - ${p.name}` : p.name;
      return {
        row_number: idx + 1,
        ...p,
        invoice_and_name: invoiceAndName,
        payment_label: p.payment_status === 'paid' ? 'Lunas' : 'Belum Lunas'
      };
    });

    return {
      summary: {
        total_billing: totalBilling,
        total_fee_management: totalFee,
        total_ppn: totalPpn,
        total_pph: totalPph,
        total_netto: totalNetto,
        total_paid_netto: totalPaidNetto,
        total_unpaid_netto: totalUnpaidNetto,
        paid_count: paidCount,
        unpaid_count: unpaidCount
      },
      items
    };
  },

  async recordTransaction(userId, companyId, projectId, { wallet_id, category_id = null, type, amount, date = null, notes = null }) {
    const parsedAmount = Number(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      throw new Error('Nominal transaksi harus lebih besar dari 0');
    }

    if (type !== 'income' && type !== 'expense') {
      throw new Error('Jenis transaksi proyek harus "income" atau "expense"');
    }

    const txDate = date || new Date().toISOString().split('T')[0];

    return await db.transaction(async (trx) => {
      // 1. Verify project exists in company
      const projects = await trx.query(
        'SELECT * FROM projects WHERE id = ? AND company_id = ?',
        [projectId, companyId]
      );
      if (!projects || projects.length === 0) {
        throw new Error('Proyek tidak ditemukan di perusahaan ini');
      }
      const project = projects[0];

      // 2. Verify wallet & authorization
      const wallets = await trx.query('SELECT * FROM wallets WHERE id = ?', [wallet_id]);
      if (!wallets || wallets.length === 0) {
        throw new Error('Dompet / Rekening tidak ditemukan');
      }
      const wallet = wallets[0];
      const isCompanyWallet = String(wallet.company_id) === String(companyId) && wallet.scope === 'company';
      const isPersonalWallet = String(wallet.user_id) === String(userId);

      if (!isCompanyWallet && !isPersonalWallet) {
        throw new Error('Akses ditolak: Dompet bukan milik pribadi Anda atau kas perusahaan ini');
      }

      let finalNotes = notes ? notes.trim() : '';
      if (!isCompanyWallet && type === 'expense') {
        if (!finalNotes.includes('Talangan Pribadi')) {
          finalNotes = finalNotes ? `${finalNotes} (Talangan Pribadi)` : 'Talangan Pribadi';
        }
      }

      const walletBalance = Number(wallet.balance) || 0;
      let newWalletBalance = walletBalance;
      let newProjectIncome = Number(project.current_income) || 0;
      let newProjectExpense = Number(project.current_expense) || 0;

      if (type === 'income') {
        newWalletBalance += parsedAmount;
        newProjectIncome += parsedAmount;
      } else {
        if (walletBalance < parsedAmount) {
          throw new Error('Saldo dompet tidak mencukupi untuk pengeluaran ini');
        }
        newWalletBalance -= parsedAmount;
        newProjectExpense += parsedAmount;
      }

      // Update wallet balance
      await trx.query('UPDATE wallets SET balance = ? WHERE id = ?', [newWalletBalance, wallet_id]);

      // Update project income/expense
      await trx.query(
        'UPDATE projects SET current_income = ?, current_expense = ? WHERE id = ?',
        [newProjectIncome, newProjectExpense, projectId]
      );

      // 3. Verify category exists if provided (prevent foreign key constraint failure)
      let validCategoryId = null;
      if (category_id) {
        const catRows = await trx.query('SELECT id FROM categories WHERE id = ?', [Number(category_id)]);
        if (catRows && catRows.length > 0) {
          validCategoryId = Number(category_id);
        }
      }

      // Record transaction
      const txInvoice = project.invoice_number || null;
      const insertRes = await trx.query(
        `INSERT INTO transactions (user_id, company_id, project_id, invoice_number, wallet_id, category_id, type, amount, transaction_date, notes, scope)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [userId, companyId, projectId, txInvoice, wallet_id, validCategoryId, type, parsedAmount, txDate, finalNotes, 'company']
      );

      return {
        id: insertRes.insertId,
        project_id: projectId,
        company_id: companyId,
        wallet_id: wallet_id,
        funding_source: isCompanyWallet ? 'company' : 'personal',
        type,
        amount: parsedAmount,
        notes: finalNotes,
        wallet_balance: newWalletBalance,
        project_income: newProjectIncome,
        project_expense: newProjectExpense
      };
    });
  },

  async updateProjectStatus(companyId, projectId, status) {
    const validStatuses = ['active', 'completed', 'on_hold'];
    if (!validStatuses.includes(status)) {
      throw new Error(`Status tidak valid: ${status}`);
    }

    await db.query(
      'UPDATE projects SET status = ? WHERE id = ? AND company_id = ?',
      [status, projectId, companyId]
    );

    return { id: projectId, status };
  }
};
