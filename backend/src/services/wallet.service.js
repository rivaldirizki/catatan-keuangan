import { db } from '../config/database.js';

export const WalletService = {
  async createWallet(userId, name, initialBalance = 0, scope = 'personal', familyId = null, companyId = null) {
    const insertRes = await db.query(
      'INSERT INTO wallets (user_id, family_id, company_id, name, balance, scope, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [userId, familyId, companyId, name.trim(), Number(initialBalance), scope, 1]
    );

    return {
      id: insertRes.insertId,
      user_id: userId,
      family_id: familyId,
      company_id: companyId,
      name: name.trim(),
      balance: Number(initialBalance),
      scope,
      is_active: 1
    };
  },

  async getWallets(userId, familyId = null, familyView = false, companyId = null, companyView = false) {
    if (companyView && companyId) {
      // Ensure company has default operational wallet
      const companyWallets = await db.query(
        'SELECT * FROM wallets WHERE company_id = ? AND scope = "company"',
        [companyId]
      );
      if (!companyWallets || companyWallets.length === 0) {
        await this.createWallet(userId, 'Kas Operasional Perusahaan', 0, 'company', null, companyId);
      }
      return await db.query(
        'SELECT * FROM wallets WHERE (company_id = ? AND scope = "company") OR user_id = ?',
        [companyId, userId]
      );
    }
    if (familyView && familyId) {
      return await db.query(
        'SELECT * FROM wallets WHERE (family_id = ? AND scope = "family") OR user_id = ?',
        [familyId, userId]
      );
    }
    return await db.query('SELECT * FROM wallets WHERE user_id = ?', [userId]);
  },

  async getWalletById(walletId) {
    const rows = await db.query('SELECT * FROM wallets WHERE id = ?', [walletId]);
    return rows && rows.length > 0 ? rows[0] : null;
  },

  async updateBalance(walletId, delta) {
    const wallet = await this.getWalletById(walletId);
    if (!wallet) throw new Error('Wallet not found');
    const newBalance = Number(wallet.balance) + Number(delta);
    await db.query('UPDATE wallets SET balance = ? WHERE id = ?', [newBalance, walletId]);
    return newBalance;
  }
};
