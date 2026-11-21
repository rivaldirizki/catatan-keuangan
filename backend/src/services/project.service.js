import { db } from '../config/database.js';

export const ProjectService = {
  async createProject(companyId, userId, { name, description = null, target_budget = 0, start_date = null, end_date = null }) {
    if (!name || !name.trim()) {
      throw new Error('Nama proyek wajib diisi');
    }

    const budget = Math.max(0, Number(target_budget) || 0);

    const insertRes = await db.query(
      `INSERT INTO projects (company_id, created_by, name, description, target_budget, current_income, current_expense, status, start_date, end_date)
       VALUES (?, ?, ?, ?, ?, 0, 0, 'active', ?, ?)`,
      [companyId, userId, name.trim(), description, budget, start_date, end_date]
    );

    return {
      id: insertRes.insertId,
      company_id: companyId,
      created_by: userId,
      name: name.trim(),
      description,
      target_budget: budget,
      current_income: 0,
      current_expense: 0,
      status: 'active',
      start_date,
      end_date
    };
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

    return projects.map(p => {
      const budget = Number(p.target_budget) || 0;
      const income = Number(p.current_income) || 0;
      const expense = Number(p.current_expense) || 0;
      const netProfit = income - expense;
      const budgetProgress = budget > 0 ? Math.min(100, Math.round((expense / budget) * 100)) : 0;

      return {
        ...p,
        target_budget: budget,
        current_income: income,
        current_expense: expense,
        net_profit: netProfit,
        budget_progress: budgetProgress
      };
    });
  },

  async getProjectById(companyId, projectId) {
    const projects = await db.query(
      'SELECT * FROM projects WHERE id = ? AND company_id = ?',
      [projectId, companyId]
    );
    if (!projects || projects.length === 0) {
      throw new Error('Proyek tidak ditemukan');
    }

    const p = projects[0];
    const budget = Number(p.target_budget) || 0;
    const income = Number(p.current_income) || 0;
    const expense = Number(p.current_expense) || 0;
    const netProfit = income - expense;
    const budgetProgress = budget > 0 ? Math.min(100, Math.round((expense / budget) * 100)) : 0;

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
      ...p,
      target_budget: budget,
      current_income: income,
      current_expense: expense,
      net_profit: netProfit,
      budget_progress: budgetProgress,
      transactions: transactions || []
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

      // 2. Verify wallet
      const wallets = await trx.query('SELECT * FROM wallets WHERE id = ?', [wallet_id]);
      if (!wallets || wallets.length === 0) {
        throw new Error('Dompet / Rekening tidak ditemukan');
      }
      const wallet = wallets[0];
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

      // Record transaction
      const insertRes = await trx.query(
        `INSERT INTO transactions (user_id, company_id, project_id, wallet_id, category_id, type, amount, transaction_date, notes, scope)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'company')`,
        [userId, companyId, projectId, wallet_id, category_id, type, parsedAmount, txDate, notes]
      );

      return {
        id: insertRes.insertId,
        project_id: projectId,
        company_id: companyId,
        wallet_id: wallet_id,
        type,
        amount: parsedAmount,
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
