import crypto from 'node:crypto';
import { db } from '../config/database.js';
import { hashPassword } from '../services/auth.service.js';

const generateCode = () => crypto.randomBytes(4).toString('hex').toUpperCase();

export const AdminController = {
  // ======================== STATS & OVERVIEW ========================
  async getStats(req, res) {
    try {
      const users = await db.query('SELECT id, name, email, role, family_id, company_id, created_at FROM users');
      const families = await db.query('SELECT id, name, invite_code, created_at FROM families');
      const companies = await db.query('SELECT id, name, invite_code, created_at FROM companies');
      const projects = await db.query('SELECT id, name, target_budget, current_income, current_expense, status FROM projects');
      const transactions = await db.query('SELECT id, user_id, wallet_id, type, amount, transaction_date, notes, scope, created_at FROM transactions ORDER BY id DESC');
      const wallets = await db.query('SELECT id, balance FROM wallets');
      const savings = await db.query('SELECT id, target_amount, current_amount, scope FROM savings');
      const debts = await db.query('SELECT id, type, remaining_amount, status FROM debts');
      const categories = await db.query('SELECT id FROM categories');

      let totalSystemBalance = 0;
      wallets.forEach(w => totalSystemBalance += Number(w.balance || 0));

      let totalSavingsBalance = 0;
      let sharedSavingsCount = 0;
      savings.forEach(s => {
        totalSavingsBalance += Number(s.current_amount || 0);
        if (s.scope === 'family') sharedSavingsCount++;
      });

      let totalActiveDebts = 0;
      debts.forEach(d => {
        if (d.type === 'payable' && d.status !== 'paid') totalActiveDebts += Number(d.remaining_amount || 0);
      });

      let totalIncomeVolume = 0;
      let totalExpenseVolume = 0;
      transactions.forEach(t => {
        if (t.type === 'income') totalIncomeVolume += Number(t.amount || 0);
        else totalExpenseVolume += Number(t.amount || 0);
      });

      const recentTx = transactions.slice(0, 8).map(t => {
        const u = users.find(user => user.id === t.user_id);
        return {
          ...t,
          user_name: u ? u.name : 'User #' + t.user_id,
          user_email: u ? u.email : ''
        };
      });

      res.json({
        total_users: users.length,
        admin_count: users.filter(u => u.role === 'admin').length,
        total_families: families.length,
        total_companies: (companies || []).length,
        total_projects: (projects || []).length,
        total_transactions: transactions.length,
        total_system_balance: totalSystemBalance,
        total_savings_balance: totalSavingsBalance,
        total_savings_goals: savings.length,
        shared_savings_count: sharedSavingsCount,
        total_active_debts: totalActiveDebts,
        total_wallets: wallets.length,
        total_categories: (categories || []).length,
        total_income_volume: totalIncomeVolume,
        total_expense_volume: totalExpenseVolume,
        recent_transactions: recentTx
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== USERS CRUD ========================
  async getUsers(req, res) {
    try {
      const users = await db.query('SELECT id, name, email, role, family_id, company_id, created_at FROM users ORDER BY id DESC');
      const families = await db.query('SELECT id, name, invite_code FROM families');
      const companies = await db.query('SELECT id, name, invite_code FROM companies');
      const wallets = await db.query('SELECT id, user_id, balance FROM wallets');
      const transactions = await db.query('SELECT id, user_id FROM transactions');

      const enriched = users.map(u => {
        const fam = families.find(f => f.id === u.family_id);
        const comp = companies.find(c => c.id === u.company_id);
        const userWallets = wallets.filter(w => w.user_id === u.id);
        const totalBal = userWallets.reduce((sum, w) => sum + Number(w.balance || 0), 0);
        const txCount = transactions.filter(t => t.user_id === u.id).length;

        return {
          ...u,
          family_name: fam ? fam.name : null,
          family_code: fam ? fam.invite_code : null,
          company_name: comp ? comp.name : null,
          company_code: comp ? comp.invite_code : null,
          wallet_count: userWallets.length,
          total_balance: totalBal,
          transaction_count: txCount
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createUser(req, res) {
    try {
      const { name, email, password, role, family_id, company_id } = req.body;
      if (!name || !email || !password) {
        return res.status(400).json({ error: 'Nama, email, dan kata sandi wajib diisi' });
      }

      const existing = await db.query('SELECT id FROM users WHERE email = ?', [email.toLowerCase().trim()]);
      if (existing && existing.length > 0) {
        return res.status(400).json({ error: 'Email sudah terdaftar di sistem' });
      }

      const targetRole = role === 'admin' ? 'admin' : 'user';
      const passwordHash = hashPassword(password);
      const famId = family_id ? Number(family_id) : null;
      const compId = company_id ? Number(company_id) : null;

      const result = await db.query(
        'INSERT INTO users (name, email, password_hash, role, family_id, company_id) VALUES (?, ?, ?, ?, ?, ?)',
        [name.trim(), email.toLowerCase().trim(), passwordHash, targetRole, famId, compId]
      );

      const newUserId = result.insertId;

      // Buat default wallet untuk pengguna baru
      await db.query(
        'INSERT INTO wallets (user_id, family_id, company_id, name, balance, scope, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [newUserId, famId, compId, 'Dompet Utama', 0, 'personal', 1]
      );

      res.status(201).json({
        success: true,
        message: 'Pengguna berhasil dibuat',
        user: {
          id: newUserId,
          name: name.trim(),
          email: email.toLowerCase().trim(),
          role: targetRole,
          family_id: famId,
          company_id: compId
        }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateUser(req, res) {
    try {
      const userId = Number(req.params.id);
      const { name, email, role, family_id, company_id, password } = req.body;

      const existingUsers = await db.query('SELECT id, password_hash FROM users WHERE id = ?', [userId]);
      if (!existingUsers || existingUsers.length === 0) {
        return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
      }

      if (email) {
        const duplicate = await db.query('SELECT id FROM users WHERE email = ? AND id != ?', [email.toLowerCase().trim(), userId]);
        if (duplicate && duplicate.length > 0) {
          return res.status(400).json({ error: 'Email sudah digunakan pengguna lain' });
        }
      }

      let passwordHash = existingUsers[0].password_hash;
      if (password && password.trim().length > 0) {
        passwordHash = hashPassword(password.trim());
      }

      const targetRole = role === 'admin' ? 'admin' : 'user';
      const famId = family_id ? Number(family_id) : null;
      const compId = company_id ? Number(company_id) : null;

      await db.query(
        'UPDATE users SET name = ?, email = ?, password_hash = ?, role = ?, family_id = ?, company_id = ? WHERE id = ?',
        [name ? name.trim() : existingUsers[0].name, email ? email.toLowerCase().trim() : existingUsers[0].email, passwordHash, targetRole, famId, compId, userId]
      );

      res.json({
        success: true,
        message: 'Data pengguna berhasil diperbarui',
        user_id: userId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteUser(req, res) {
    try {
      const targetUserId = Number(req.params.id);

      if (req.user && req.user.id === targetUserId) {
        return res.status(400).json({ error: 'Anda tidak dapat menghapus akun administrator yang sedang digunakan' });
      }

      const existing = await db.query('SELECT id FROM users WHERE id = ?', [targetUserId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
      }

      // Cascading cleanup
      await db.query('DELETE FROM users WHERE id = ?', [targetUserId]);

      res.json({
        success: true,
        message: 'Pengguna beserta data terkait berhasil dihapus',
        user_id: targetUserId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateUserRole(req, res) {
    try {
      const targetUserId = Number(req.params.id);
      const { role } = req.body;

      if (!['admin', 'user'].includes(role)) {
        return res.status(400).json({ error: 'Role harus berupa "admin" atau "user"' });
      }

      const targetUsers = await db.query('SELECT id, role FROM users WHERE id = ?', [targetUserId]);
      if (!targetUsers || targetUsers.length === 0) {
        return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
      }

      await db.query('UPDATE users SET role = ? WHERE id = ?', [role, targetUserId]);
      res.json({
        success: true,
        message: `Role pengguna berhasil diubah menjadi ${role}`,
        user_id: targetUserId,
        new_role: role
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== FAMILIES CRUD ========================
  async getFamilies(req, res) {
    try {
      const families = await db.query('SELECT id, name, invite_code, created_at FROM families ORDER BY id DESC');
      const users = await db.query('SELECT id, name, email, role, family_id FROM users');
      const savings = await db.query('SELECT id, family_id, current_amount, target_amount, scope FROM savings');

      const enriched = families.map(f => {
        const members = users.filter(u => u.family_id === f.id);
        const familySavings = savings.filter(s => s.family_id === f.id || s.scope === 'family');
        const totalSavings = familySavings.reduce((sum, s) => sum + Number(s.current_amount || 0), 0);

        return {
          ...f,
          member_count: members.length,
          members: members.map(m => ({ id: m.id, name: m.name, email: m.email, role: m.role })),
          savings_count: familySavings.length,
          total_savings: totalSavings
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createFamily(req, res) {
    try {
      const { name, invite_code } = req.body;
      if (!name || name.trim().length === 0) {
        return res.status(400).json({ error: 'Nama grup keluarga wajib diisi' });
      }

      const code = (invite_code && invite_code.trim()) ? invite_code.trim().toUpperCase() : generateCode();
      const existing = await db.query('SELECT id FROM families WHERE invite_code = ?', [code]);
      if (existing && existing.length > 0) {
        return res.status(400).json({ error: 'Kode undangan sudah digunakan oleh keluarga lain' });
      }

      const result = await db.query(
        'INSERT INTO families (name, invite_code, created_by) VALUES (?, ?, ?)',
        [name.trim(), code, req.user?.id || null]
      );

      res.status(201).json({
        success: true,
        message: 'Grup keluarga berhasil dibuat',
        family: { id: result.insertId, name: name.trim(), invite_code: code }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateFamily(req, res) {
    try {
      const familyId = Number(req.params.id);
      const { name, invite_code } = req.body;
      if (!name) return res.status(400).json({ error: 'Nama grup keluarga wajib diisi' });

      const existing = await db.query('SELECT id FROM families WHERE id = ?', [familyId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Grup keluarga tidak ditemukan' });
      }

      const code = (invite_code && invite_code.trim()) ? invite_code.trim().toUpperCase() : generateCode();
      await db.query('UPDATE families SET name = ?, invite_code = ? WHERE id = ?', [name.trim(), code, familyId]);

      res.json({
        success: true,
        message: 'Grup keluarga berhasil diperbarui',
        family_id: familyId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteFamily(req, res) {
    try {
      const familyId = Number(req.params.id);
      const existing = await db.query('SELECT id FROM families WHERE id = ?', [familyId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Grup keluarga tidak ditemukan' });
      }

      // Detach users from family
      await db.query('UPDATE users SET family_id = ? WHERE family_id = ?', [null, familyId]);
      await db.query('DELETE FROM families WHERE id = ?', [familyId]);

      res.json({
        success: true,
        message: 'Grup keluarga berhasil dihapus',
        family_id: familyId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== COMPANIES CRUD ========================
  async getCompanies(req, res) {
    try {
      const companies = await db.query('SELECT id, name, invite_code, created_by, created_at FROM companies ORDER BY id DESC');
      const users = await db.query('SELECT id, name, email, role, company_id FROM users');
      const projects = await db.query('SELECT id, company_id, name, target_budget, current_income, current_expense, status FROM projects');

      const enriched = (companies || []).map(c => {
        const members = users.filter(u => u.company_id === c.id);
        const compProjects = (projects || []).filter(p => p.company_id === c.id);
        const totalBudget = compProjects.reduce((sum, p) => sum + Number(p.target_budget || 0), 0);
        const totalIncome = compProjects.reduce((sum, p) => sum + Number(p.current_income || 0), 0);
        const totalExpense = compProjects.reduce((sum, p) => sum + Number(p.current_expense || 0), 0);

        return {
          ...c,
          member_count: members.length,
          members: members.map(m => ({ id: m.id, name: m.name, email: m.email, role: m.role })),
          project_count: compProjects.length,
          total_budget: totalBudget,
          total_income: totalIncome,
          total_expense: totalExpense
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createCompany(req, res) {
    try {
      const { name, invite_code } = req.body;
      if (!name || name.trim().length === 0) {
        return res.status(400).json({ error: 'Nama perusahaan wajib diisi' });
      }

      const code = (invite_code && invite_code.trim()) ? invite_code.trim().toUpperCase() : generateCode();
      const existing = await db.query('SELECT id FROM companies WHERE invite_code = ?', [code]);
      if (existing && existing.length > 0) {
        return res.status(400).json({ error: 'Kode undangan sudah digunakan oleh perusahaan lain' });
      }

      const result = await db.query(
        'INSERT INTO companies (name, invite_code, created_by) VALUES (?, ?, ?)',
        [name.trim(), code, req.user?.id || null]
      );

      res.status(201).json({
        success: true,
        message: 'Perusahaan berhasil dibuat',
        company: { id: result.insertId, name: name.trim(), invite_code: code }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateCompany(req, res) {
    try {
      const companyId = Number(req.params.id);
      const { name, invite_code } = req.body;
      if (!name) return res.status(400).json({ error: 'Nama perusahaan wajib diisi' });

      const existing = await db.query('SELECT id FROM companies WHERE id = ?', [companyId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Perusahaan tidak ditemukan' });
      }

      const code = (invite_code && invite_code.trim()) ? invite_code.trim().toUpperCase() : generateCode();
      await db.query('UPDATE companies SET name = ?, invite_code = ? WHERE id = ?', [name.trim(), code, companyId]);

      res.json({
        success: true,
        message: 'Perusahaan berhasil diperbarui',
        company_id: companyId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteCompany(req, res) {
    try {
      const companyId = Number(req.params.id);
      const existing = await db.query('SELECT id FROM companies WHERE id = ?', [companyId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Perusahaan tidak ditemukan' });
      }

      // Detach users and wallets
      await db.query('UPDATE users SET company_id = ? WHERE company_id = ?', [null, companyId]);
      await db.query('UPDATE wallets SET company_id = ? WHERE company_id = ?', [null, companyId]);
      await db.query('DELETE FROM companies WHERE id = ?', [companyId]);

      res.json({
        success: true,
        message: 'Perusahaan berhasil dihapus',
        company_id: companyId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== PROJECTS CRUD ========================
  async getProjects(req, res) {
    try {
      const projects = await db.query('SELECT id, company_id, created_by, name, description, target_budget, current_income, current_expense, status, start_date, end_date, created_at FROM projects ORDER BY id DESC');
      const companies = await db.query('SELECT id, name FROM companies');
      const users = await db.query('SELECT id, name FROM users');

      const enriched = (projects || []).map(p => {
        const c = companies.find(comp => comp.id === p.company_id);
        const u = users.find(usr => usr.id === p.created_by);
        const netCashflow = Number(p.current_income || 0) - Number(p.current_expense || 0);

        return {
          ...p,
          company_name: c ? c.name : 'Unknown Company',
          creator_name: u ? u.name : 'Unknown Creator',
          net_cashflow: netCashflow
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createProject(req, res) {
    try {
      const { company_id, name, description, target_budget, status, start_date, end_date } = req.body;
      if (!company_id || !name) {
        return res.status(400).json({ error: 'Perusahaan dan nama proyek wajib diisi' });
      }

      const comp = await db.query('SELECT id FROM companies WHERE id = ?', [Number(company_id)]);
      if (!comp || comp.length === 0) {
        return res.status(404).json({ error: 'Perusahaan yang dipilih tidak valid' });
      }

      const budget = Number(target_budget || 0);
      const stat = status || 'active';
      const createdBy = req.user?.id || 1;

      const result = await db.query(
        'INSERT INTO projects (company_id, created_by, name, description, target_budget, current_income, current_expense, status, start_date, end_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [Number(company_id), createdBy, name.trim(), description || '', budget, 0, 0, stat, start_date || null, end_date || null]
      );

      res.status(201).json({
        success: true,
        message: 'Proyek perusahaan berhasil dibuat',
        project: {
          id: result.insertId,
          company_id: Number(company_id),
          name: name.trim(),
          target_budget: budget,
          status: stat
        }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateProject(req, res) {
    try {
      const projectId = Number(req.params.id);
      const { name, description, target_budget, current_income, current_expense, status, start_date, end_date, company_id } = req.body;

      const existing = await db.query('SELECT id, current_income, current_expense FROM projects WHERE id = ?', [projectId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Proyek tidak ditemukan' });
      }

      const budget = target_budget !== undefined ? Number(target_budget) : 0;
      const income = current_income !== undefined ? Number(current_income) : Number(existing[0].current_income || 0);
      const expense = current_expense !== undefined ? Number(current_expense) : Number(existing[0].current_expense || 0);

      await db.query(
        'UPDATE projects SET name = ?, description = ?, target_budget = ?, current_income = ?, current_expense = ?, status = ?, start_date = ?, end_date = ? WHERE id = ?',
        [name.trim(), description || '', budget, income, expense, status || 'active', start_date || null, end_date || null, projectId]
      );

      res.json({
        success: true,
        message: 'Proyek berhasil diperbarui',
        project_id: projectId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteProject(req, res) {
    try {
      const projectId = Number(req.params.id);
      const existing = await db.query('SELECT id FROM projects WHERE id = ?', [projectId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Proyek tidak ditemukan' });
      }

      // Nullify project_id in transactions
      await db.query('UPDATE transactions SET project_id = ? WHERE project_id = ?', [null, projectId]);
      await db.query('DELETE FROM projects WHERE id = ?', [projectId]);

      res.json({
        success: true,
        message: 'Proyek berhasil dihapus',
        project_id: projectId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== WALLETS CRUD ========================
  async getWallets(req, res) {
    try {
      const wallets = await db.query('SELECT id, user_id, family_id, company_id, name, balance, scope, is_active, created_at FROM wallets ORDER BY id DESC');
      const users = await db.query('SELECT id, name, email FROM users');
      const families = await db.query('SELECT id, name FROM families');
      const companies = await db.query('SELECT id, name FROM companies');

      const enriched = (wallets || []).map(w => {
        const u = users.find(usr => usr.id === w.user_id);
        const f = w.family_id ? families.find(fam => fam.id === w.family_id) : null;
        const c = w.company_id ? companies.find(comp => comp.id === w.company_id) : null;

        return {
          ...w,
          user_name: u ? u.name : 'Unknown',
          user_email: u ? u.email : '',
          family_name: f ? f.name : null,
          company_name: c ? c.name : null
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createWallet(req, res) {
    try {
      const { user_id, name, balance, scope, family_id, company_id, is_active } = req.body;
      if (!user_id || !name) {
        return res.status(400).json({ error: 'Pemilik dompet dan nama dompet wajib diisi' });
      }

      const bal = Number(balance || 0);
      const targetScope = ['personal', 'family', 'company'].includes(scope) ? scope : 'personal';
      const famId = family_id ? Number(family_id) : null;
      const compId = company_id ? Number(company_id) : null;
      const active = is_active !== undefined ? (is_active ? 1 : 0) : 1;

      const result = await db.query(
        'INSERT INTO wallets (user_id, family_id, company_id, name, balance, scope, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [Number(user_id), famId, compId, name.trim(), bal, targetScope, active]
      );

      res.status(201).json({
        success: true,
        message: 'Dompet berhasil dibuat',
        wallet: { id: result.insertId, name: name.trim(), balance: bal, scope: targetScope }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateWallet(req, res) {
    try {
      const walletId = Number(req.params.id);
      const { name, balance, scope, is_active, family_id, company_id } = req.body;

      const existing = await db.query('SELECT id, balance, scope FROM wallets WHERE id = ?', [walletId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Dompet tidak ditemukan' });
      }

      const bal = balance !== undefined ? Number(balance) : Number(existing[0].balance || 0);
      const targetScope = scope || existing[0].scope || 'personal';
      const active = is_active !== undefined ? (is_active ? 1 : 0) : 1;
      const famId = family_id !== undefined ? (family_id ? Number(family_id) : null) : null;
      const compId = company_id !== undefined ? (company_id ? Number(company_id) : null) : null;

      await db.query(
        'UPDATE wallets SET name = ?, balance = ?, scope = ?, is_active = ?, family_id = ?, company_id = ? WHERE id = ?',
        [name.trim(), bal, targetScope, active, famId, compId, walletId]
      );

      res.json({
        success: true,
        message: 'Dompet berhasil diperbarui',
        wallet_id: walletId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteWallet(req, res) {
    try {
      const walletId = Number(req.params.id);
      const existing = await db.query('SELECT id FROM wallets WHERE id = ?', [walletId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Dompet tidak ditemukan' });
      }

      // Check transactions
      await db.query('DELETE FROM transactions WHERE wallet_id = ?', [walletId]);
      await db.query('DELETE FROM wallets WHERE id = ?', [walletId]);

      res.json({
        success: true,
        message: 'Dompet beserta histori transaksinya berhasil dihapus',
        wallet_id: walletId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== TRANSACTIONS CRUD ========================
  async getTransactions(req, res) {
    try {
      const transactions = await db.query('SELECT id, user_id, family_id, company_id, project_id, wallet_id, category_id, type, amount, transaction_date, notes, scope, created_at FROM transactions ORDER BY id DESC');
      const users = await db.query('SELECT id, name, email FROM users');
      const wallets = await db.query('SELECT id, name FROM wallets');
      const families = await db.query('SELECT id, name FROM families');
      const companies = await db.query('SELECT id, name FROM companies');
      const projects = await db.query('SELECT id, name FROM projects');
      const categories = await db.query('SELECT id, name, type, color, icon FROM categories');

      const enriched = (transactions || []).map(t => {
        const u = users.find(user => user.id === t.user_id);
        const w = wallets.find(wallet => wallet.id === t.wallet_id);
        const f = t.family_id ? families.find(fam => fam.id === t.family_id) : null;
        const c = t.company_id ? companies.find(comp => comp.id === t.company_id) : null;
        const p = t.project_id ? projects.find(proj => proj.id === t.project_id) : null;
        const cat = t.category_id ? categories.find(ct => ct.id === t.category_id) : null;

        return {
          ...t,
          user_name: u ? u.name : 'User #' + t.user_id,
          user_email: u ? u.email : '',
          wallet_name: w ? w.name : 'Dompet #' + t.wallet_id,
          family_name: f ? f.name : null,
          company_name: c ? c.name : null,
          project_name: p ? p.name : null,
          category_name: cat ? cat.name : '-'
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createTransaction(req, res) {
    try {
      const { user_id, wallet_id, category_id, type, amount, transaction_date, notes, scope, family_id, company_id, project_id } = req.body;
      if (!user_id || !wallet_id || !type || amount === undefined || !transaction_date) {
        return res.status(400).json({ error: 'Pengguna, dompet, jenis, nominal, dan tanggal transaksi wajib diisi' });
      }

      const numAmount = Number(amount);
      if (isNaN(numAmount) || numAmount <= 0) {
        return res.status(400).json({ error: 'Nominal transaksi harus berupa angka positif' });
      }

      const wal = await db.query('SELECT id, balance FROM wallets WHERE id = ?', [Number(wallet_id)]);
      if (!wal || wal.length === 0) {
        return res.status(404).json({ error: 'Dompet tidak ditemukan' });
      }

      // Adjust wallet balance
      let currentBal = Number(wal[0].balance || 0);
      if (type === 'income') {
        currentBal += numAmount;
      } else if (type === 'expense') {
        currentBal -= numAmount;
      }
      await db.query('UPDATE wallets SET balance = ? WHERE id = ?', [currentBal, Number(wallet_id)]);

      // If project_id is provided, adjust project income/expense
      const projId = project_id ? Number(project_id) : null;
      if (projId) {
        const proj = await db.query('SELECT id, current_income, current_expense FROM projects WHERE id = ?', [projId]);
        if (proj && proj.length > 0) {
          if (type === 'income') {
            await db.query('UPDATE projects SET current_income = ? WHERE id = ?', [Number(proj[0].current_income || 0) + numAmount, projId]);
          } else if (type === 'expense') {
            await db.query('UPDATE projects SET current_expense = ? WHERE id = ?', [Number(proj[0].current_expense || 0) + numAmount, projId]);
          }
        }
      }

      let catId = null;
      if (category_id) {
        const catRows = await db.query('SELECT id FROM categories WHERE id = ?', [Number(category_id)]);
        if (catRows && catRows.length > 0) {
          catId = Number(category_id);
        }
      }
      const famId = family_id ? Number(family_id) : null;
      let compId = company_id ? Number(company_id) : null;
      if (projId && !compId) {
        const projRows = await db.query('SELECT company_id FROM projects WHERE id = ?', [projId]);
        if (projRows && projRows.length > 0 && projRows[0].company_id) {
          compId = projRows[0].company_id;
        }
      }
      const targetScope = ['personal', 'family', 'company'].includes(scope) ? scope : (compId ? 'company' : (famId ? 'family' : 'personal'));

      const result = await db.query(
        'INSERT INTO transactions (user_id, family_id, company_id, project_id, wallet_id, category_id, type, amount, transaction_date, notes, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [Number(user_id), famId, compId, projId, Number(wallet_id), catId, type, numAmount, transaction_date, notes || '', targetScope]
      );

      res.status(201).json({
        success: true,
        message: 'Transaksi berhasil dicatat',
        transaction: {
          id: result.insertId,
          amount: numAmount,
          type,
          wallet_id: Number(wallet_id)
        }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateTransaction(req, res) {
    try {
      const txId = Number(req.params.id);
      const { type, amount, transaction_date, notes, category_id, scope, project_id } = req.body;

      const existing = await db.query('SELECT * FROM transactions WHERE id = ?', [txId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Transaksi tidak ditemukan' });
      }

      const oldTx = existing[0];
      const newType = type || oldTx.type;
      const newAmount = amount !== undefined ? Number(amount) : Number(oldTx.amount);
      const newDate = transaction_date || oldTx.transaction_date;
      const newNotes = notes !== undefined ? notes : oldTx.notes;
      let newCatId = null;
      const targetCatId = category_id !== undefined ? (category_id ? Number(category_id) : null) : oldTx.category_id;
      if (targetCatId) {
        const catRows = await db.query('SELECT id FROM categories WHERE id = ?', [Number(targetCatId)]);
        if (catRows && catRows.length > 0) {
          newCatId = Number(targetCatId);
        }
      }
      const newScope = scope || oldTx.scope;
      const newProjId = project_id !== undefined ? (project_id ? Number(project_id) : null) : oldTx.project_id;

      // Adjust wallet balance delta
      const wal = await db.query('SELECT id, balance FROM wallets WHERE id = ?', [oldTx.wallet_id]);
      if (wal && wal.length > 0) {
        let bal = Number(wal[0].balance || 0);
        // Revert old effect
        if (oldTx.type === 'income') bal -= Number(oldTx.amount);
        else if (oldTx.type === 'expense') bal += Number(oldTx.amount);

        // Apply new effect
        if (newType === 'income') bal += newAmount;
        else if (newType === 'expense') bal -= newAmount;

        await db.query('UPDATE wallets SET balance = ? WHERE id = ?', [bal, oldTx.wallet_id]);
      }

      await db.query(
        'UPDATE transactions SET type = ?, amount = ?, transaction_date = ?, notes = ?, category_id = ?, scope = ?, project_id = ? WHERE id = ?',
        [newType, newAmount, newDate, newNotes, newCatId, newScope, newProjId, txId]
      );

      res.json({
        success: true,
        message: 'Transaksi berhasil diperbarui',
        transaction_id: txId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteTransaction(req, res) {
    try {
      const txId = Number(req.params.id);
      const existing = await db.query('SELECT * FROM transactions WHERE id = ?', [txId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Transaksi tidak ditemukan' });
      }

      const tx = existing[0];

      // Revert wallet balance
      const wal = await db.query('SELECT id, balance FROM wallets WHERE id = ?', [tx.wallet_id]);
      if (wal && wal.length > 0) {
        let bal = Number(wal[0].balance || 0);
        if (tx.type === 'income') bal -= Number(tx.amount);
        else if (tx.type === 'expense') bal += Number(tx.amount);
        await db.query('UPDATE wallets SET balance = ? WHERE id = ?', [bal, tx.wallet_id]);
      }

      // Revert project stats if applicable
      if (tx.project_id) {
        const proj = await db.query('SELECT id, current_income, current_expense FROM projects WHERE id = ?', [tx.project_id]);
        if (proj && proj.length > 0) {
          if (tx.type === 'income') {
            await db.query('UPDATE projects SET current_income = ? WHERE id = ?', [Math.max(0, Number(proj[0].current_income || 0) - Number(tx.amount)), tx.project_id]);
          } else if (tx.type === 'expense') {
            await db.query('UPDATE projects SET current_expense = ? WHERE id = ?', [Math.max(0, Number(proj[0].current_expense || 0) - Number(tx.amount)), tx.project_id]);
          }
        }
      }

      await db.query('DELETE FROM transactions WHERE id = ?', [txId]);

      res.json({
        success: true,
        message: 'Transaksi berhasil dihapus dan saldo dompet disesuaikan',
        transaction_id: txId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== SAVINGS CRUD ========================
  async getSavings(req, res) {
    try {
      const savings = await db.query('SELECT id, user_id, family_id, goal_name, target_amount, current_amount, target_date, scope, status, created_at FROM savings ORDER BY id DESC');
      const users = await db.query('SELECT id, name FROM users');
      const families = await db.query('SELECT id, name FROM families');

      const enriched = (savings || []).map(s => {
        const u = users.find(user => user.id === s.user_id);
        const f = s.family_id ? families.find(fam => fam.id === s.family_id) : null;
        const target = Number(s.target_amount || 0);
        const current = Number(s.current_amount || 0);
        const progress = target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0;

        return {
          ...s,
          user_name: u ? u.name : 'Unknown',
          family_name: f ? f.name : null,
          progress
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createSaving(req, res) {
    try {
      const { user_id, family_id, goal_name, target_amount, current_amount, target_date, scope, status } = req.body;
      if (!user_id || !goal_name || target_amount === undefined) {
        return res.status(400).json({ error: 'Pengguna, nama celengan, dan target nominal wajib diisi' });
      }

      const target = Number(target_amount);
      const current = Number(current_amount || 0);
      const targetScope = scope === 'family' ? 'family' : 'personal';
      const famId = family_id ? Number(family_id) : null;
      const stat = status || (current >= target ? 'completed' : 'active');

      const result = await db.query(
        'INSERT INTO savings (user_id, family_id, goal_name, target_amount, current_amount, target_date, scope, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [Number(user_id), famId, goal_name.trim(), target, current, target_date || null, targetScope, stat]
      );

      res.status(201).json({
        success: true,
        message: 'Target celengan berhasil dibuat',
        saving: { id: result.insertId, goal_name: goal_name.trim(), target_amount: target }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateSaving(req, res) {
    try {
      const savingId = Number(req.params.id);
      const { goal_name, target_amount, current_amount, target_date, scope, status, family_id } = req.body;

      const existing = await db.query('SELECT * FROM savings WHERE id = ?', [savingId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Target celengan tidak ditemukan' });
      }

      const s = existing[0];
      const gName = goal_name !== undefined ? goal_name.trim() : s.goal_name;
      const target = target_amount !== undefined ? Number(target_amount) : Number(s.target_amount);
      const current = current_amount !== undefined ? Number(current_amount) : Number(s.current_amount);
      const tDate = target_date !== undefined ? target_date : s.target_date;
      const scp = scope || s.scope;
      const stat = status || s.status;
      const famId = family_id !== undefined ? (family_id ? Number(family_id) : null) : s.family_id;

      await db.query(
        'UPDATE savings SET goal_name = ?, target_amount = ?, current_amount = ?, target_date = ?, scope = ?, status = ?, family_id = ? WHERE id = ?',
        [gName, target, current, tDate, scp, stat, famId, savingId]
      );

      res.json({
        success: true,
        message: 'Target celengan berhasil diperbarui',
        saving_id: savingId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteSaving(req, res) {
    try {
      const savingId = Number(req.params.id);
      const existing = await db.query('SELECT id FROM savings WHERE id = ?', [savingId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Target celengan tidak ditemukan' });
      }

      await db.query('DELETE FROM savings WHERE id = ?', [savingId]);

      res.json({
        success: true,
        message: 'Target celengan berhasil dihapus',
        saving_id: savingId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== DEBTS CRUD ========================
  async getDebts(req, res) {
    try {
      const debts = await db.query('SELECT id, user_id, family_id, type, person_name, total_amount, remaining_amount, due_date, status, notes, scope, created_at FROM debts ORDER BY id DESC');
      const users = await db.query('SELECT id, name FROM users');

      const enriched = (debts || []).map(d => {
        const u = users.find(user => user.id === d.user_id);
        return {
          ...d,
          user_name: u ? u.name : 'Unknown'
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createDebt(req, res) {
    try {
      const { user_id, family_id, type, person_name, total_amount, remaining_amount, due_date, status, notes, scope } = req.body;
      if (!user_id || !type || !person_name || total_amount === undefined || !due_date) {
        return res.status(400).json({ error: 'Pengguna, jenis, pihak terkait, nominal total, dan jatuh tempo wajib diisi' });
      }

      const total = Number(total_amount);
      const remaining = remaining_amount !== undefined ? Number(remaining_amount) : total;
      const targetType = ['payable', 'receivable'].includes(type) ? type : 'payable';
      const targetScope = scope === 'family' ? 'family' : 'personal';
      const famId = family_id ? Number(family_id) : null;
      const stat = status || (remaining <= 0 ? 'paid' : (remaining < total ? 'partially_paid' : 'unpaid'));

      const result = await db.query(
        'INSERT INTO debts (user_id, family_id, type, person_name, total_amount, remaining_amount, due_date, status, notes, scope) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [Number(user_id), famId, targetType, person_name.trim(), total, remaining, due_date, stat, notes || '', targetScope]
      );

      res.status(201).json({
        success: true,
        message: 'Catatan hutang/piutang berhasil dibuat',
        debt: { id: result.insertId, person_name: person_name.trim(), remaining_amount: remaining }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateDebt(req, res) {
    try {
      const debtId = Number(req.params.id);
      const { type, person_name, total_amount, remaining_amount, due_date, status, notes, scope } = req.body;

      const existing = await db.query('SELECT * FROM debts WHERE id = ?', [debtId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Catatan hutang/piutang tidak ditemukan' });
      }

      const d = existing[0];
      const targetType = type || d.type;
      const name = person_name ? person_name.trim() : d.person_name;
      const total = total_amount !== undefined ? Number(total_amount) : Number(d.total_amount);
      const remaining = remaining_amount !== undefined ? Number(remaining_amount) : Number(d.remaining_amount);
      const dDate = due_date || d.due_date;
      const stat = status || (remaining <= 0 ? 'paid' : (remaining < total ? 'partially_paid' : 'unpaid'));
      const note = notes !== undefined ? notes : d.notes;
      const scp = scope || d.scope;

      await db.query(
        'UPDATE debts SET type = ?, person_name = ?, total_amount = ?, remaining_amount = ?, due_date = ?, status = ?, notes = ?, scope = ? WHERE id = ?',
        [targetType, name, total, remaining, dDate, stat, note, scp, debtId]
      );

      res.json({
        success: true,
        message: 'Catatan hutang/piutang berhasil diperbarui',
        debt_id: debtId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteDebt(req, res) {
    try {
      const debtId = Number(req.params.id);
      const existing = await db.query('SELECT id FROM debts WHERE id = ?', [debtId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Catatan hutang/piutang tidak ditemukan' });
      }

      await db.query('DELETE FROM debts WHERE id = ?', [debtId]);

      res.json({
        success: true,
        message: 'Catatan hutang/piutang berhasil dihapus',
        debt_id: debtId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ======================== CATEGORIES CRUD ========================
  async getCategories(req, res) {
    try {
      const categories = await db.query('SELECT id, user_id, name, type, color, icon, created_at FROM categories ORDER BY id ASC');
      const users = await db.query('SELECT id, name FROM users');

      const enriched = (categories || []).map(cat => {
        const u = cat.user_id ? users.find(usr => usr.id === cat.user_id) : null;
        return {
          ...cat,
          owner_name: u ? u.name : 'Sistem (Global)'
        };
      });

      res.json(enriched);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async createCategory(req, res) {
    try {
      const { name, type, color, icon, user_id } = req.body;
      if (!name || !type) {
        return res.status(400).json({ error: 'Nama kategori dan jenis transaksi (income/expense) wajib diisi' });
      }

      const targetType = type === 'income' ? 'income' : 'expense';
      const targetColor = color || (targetType === 'income' ? '#10B981' : '#EF4444');
      const targetIcon = icon || 'tag';
      const usrId = user_id ? Number(user_id) : null;

      const result = await db.query(
        'INSERT INTO categories (user_id, name, type, color, icon) VALUES (?, ?, ?, ?, ?)',
        [usrId, name.trim(), targetType, targetColor, targetIcon]
      );

      res.status(201).json({
        success: true,
        message: 'Kategori berhasil ditambahkan',
        category: { id: result.insertId, name: name.trim(), type: targetType, color: targetColor, icon: targetIcon }
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async updateCategory(req, res) {
    try {
      const categoryId = Number(req.params.id);
      const { name, type, color, icon } = req.body;

      const existing = await db.query('SELECT * FROM categories WHERE id = ?', [categoryId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Kategori tidak ditemukan' });
      }

      const cat = existing[0];
      const catName = name ? name.trim() : cat.name;
      const targetType = type ? (type === 'income' ? 'income' : 'expense') : cat.type;
      const targetColor = color || cat.color;
      const targetIcon = icon || cat.icon;

      await db.query(
        'UPDATE categories SET name = ?, type = ?, color = ?, icon = ? WHERE id = ?',
        [catName, targetType, targetColor, targetIcon, categoryId]
      );

      res.json({
        success: true,
        message: 'Kategori berhasil diperbarui',
        category_id: categoryId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  async deleteCategory(req, res) {
    try {
      const categoryId = Number(req.params.id);
      const existing = await db.query('SELECT id FROM categories WHERE id = ?', [categoryId]);
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Kategori tidak ditemukan' });
      }

      await db.query('UPDATE transactions SET category_id = ? WHERE category_id = ?', [null, categoryId]);
      await db.query('DELETE FROM categories WHERE id = ?', [categoryId]);

      res.json({
        success: true,
        message: 'Kategori berhasil dihapus',
        category_id: categoryId
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
};
