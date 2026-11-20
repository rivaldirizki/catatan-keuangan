import { db } from '../config/database.js';

export const WalletService = {
  async createWallet(userId, name, initialBalance = 0, scope = 'personal', familyId = null) {
    const insertRes = await db.query(
      'INSERT INTO wallets (user_id, family_id, name, balance, scope, is_active) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, familyId, name.trim(), Number(initialBalance), scope, 1]
    );

    return {
      id: insertRes.insertId,
      user_id: userId,
      family_id: familyId,
      name: name.trim(),
      balance: Number(initialBalance),
      scope,
      is_active: 1
    };
  },

  async getWallets(userId, familyId = null, familyView = false) {
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
