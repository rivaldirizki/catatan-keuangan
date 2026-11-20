import crypto from 'node:crypto';
import { db } from '../config/database.js';

function generateInviteCode() {
  return crypto.randomBytes(4).toString('hex').toUpperCase(); // 8 characters
}

export const FamilyService = {
  async createFamily(userId, familyName) {
    const inviteCode = generateInviteCode();
    const insertRes = await db.query(
      'INSERT INTO families (name, invite_code, created_by) VALUES (?, ?, ?)',
      [familyName.trim(), inviteCode, userId]
    );

    const familyId = insertRes.insertId;

    // Update creator's family_id
    await db.query('UPDATE users SET family_id = ? WHERE id = ?', [familyId, userId]);

    return {
      id: familyId,
      name: familyName.trim(),
      invite_code: inviteCode,
      created_by: userId
    };
  },

  async joinFamily(userId, inviteCode) {
    const families = await db.query('SELECT * FROM families WHERE invite_code = ?', [inviteCode.trim().toUpperCase()]);
    if (!families || families.length === 0) {
      throw new Error('Invalid invite code');
    }

    const family = families[0];
    await db.query('UPDATE users SET family_id = ? WHERE id = ?', [family.id, userId]);

    return {
      success: true,
      family: {
        id: family.id,
        name: family.name,
        invite_code: family.invite_code
      }
    };
  },

  async getFamilyMembers(familyId) {
    const members = await db.query(
      'SELECT id, name, email, role, family_id, created_at FROM users WHERE family_id = ?',
      [familyId]
    );
    if (!members || members.length === 0) return [];

    for (const m of members) {
      const wallets = await db.query('SELECT balance FROM wallets WHERE user_id = ?', [m.id]);
      m.total_balance = (wallets || []).reduce((sum, w) => sum + Number(w.balance || 0), 0);
    }
    return members;
  },

  async getFamilyById(familyId) {
    const families = await db.query('SELECT * FROM families WHERE id = ?', [familyId]);
    return families && families.length > 0 ? families[0] : null;
  }
};
