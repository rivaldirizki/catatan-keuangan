import crypto from 'node:crypto';
import { db } from '../config/database.js';

function generateInviteCode() {
  return crypto.randomBytes(4).toString('hex').toUpperCase(); // 8 characters
}

export const CompanyService = {
  async createCompany(userId, companyName) {
    const inviteCode = generateInviteCode();
    const insertRes = await db.query(
      'INSERT INTO companies (name, invite_code, created_by) VALUES (?, ?, ?)',
      [companyName.trim(), inviteCode, userId]
    );

    const companyId = insertRes.insertId;

    // Link creator to company
    await db.query('UPDATE users SET company_id = ? WHERE id = ?', [companyId, userId]);

    return {
      id: companyId,
      name: companyName.trim(),
      invite_code: inviteCode,
      created_by: userId
    };
  },

  async joinCompany(userId, inviteCode) {
    const companies = await db.query(
      'SELECT * FROM companies WHERE invite_code = ?',
      [inviteCode.trim().toUpperCase()]
    );
    if (!companies || companies.length === 0) {
      throw new Error('Invalid invite code');
    }

    const company = companies[0];
    await db.query('UPDATE users SET company_id = ? WHERE id = ?', [company.id, userId]);

    return {
      success: true,
      company: {
        id: company.id,
        name: company.name,
        invite_code: company.invite_code
      }
    };
  },

  async getCompanyMembers(companyId) {
    const members = await db.query(
      'SELECT id, name, email, role, company_id, created_at FROM users WHERE company_id = ?',
      [companyId]
    );
    return members || [];
  },

  async getCompanyById(companyId) {
    const companies = await db.query('SELECT * FROM companies WHERE id = ?', [companyId]);
    return companies && companies.length > 0 ? companies[0] : null;
  }
};
