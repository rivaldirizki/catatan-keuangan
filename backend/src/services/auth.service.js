import crypto from 'node:crypto';
import { db } from '../config/database.js';

const JWT_SECRET = process.env.JWT_SECRET || 'finance-super-secret-key-2026';

// Helper to hash password with PBKDF2 salt
export function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, storedHash) {
  if (!storedHash || !storedHash.includes(':')) return false;
  const [salt, originalHash] = storedHash.split(':');
  const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  const bufA = Buffer.from(hash);
  const bufB = Buffer.from(originalHash);
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

// Generate self-contained JWT token using HMAC-SHA256
export function generateToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const exp = Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60); // 30 days
  const body = Buffer.from(JSON.stringify({ ...payload, exp })).toString('base64url');
  const signature = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

export function verifyToken(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const [header, body, signature] = parts;
    const expectedSig = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
    const sigBuf = Buffer.from(signature);
    const expBuf = Buffer.from(expectedSig);
    if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
      return null;
    }
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch (err) {
    return null;
  }
}

export const AuthService = {
  async register(name, email, password, role = 'user') {
    const existing = await db.query('SELECT id FROM users WHERE email = ?', [email.toLowerCase().trim()]);
    if (existing && existing.length > 0) {
      throw new Error('Email already registered');
    }

    const passwordHash = hashPassword(password);
    const insertRes = await db.query(
      'INSERT INTO users (name, email, password_hash, role, family_id) VALUES (?, ?, ?, ?, ?)',
      [name.trim(), email.toLowerCase().trim(), passwordHash, role, null]
    );

    const user = {
      id: insertRes.insertId,
      name: name.trim(),
      email: email.toLowerCase().trim(),
      role,
      family_id: null,
      company_id: null
    };

    // Auto-create default wallet (Kas Tunai) for new user
    await db.query(
      'INSERT INTO wallets (user_id, family_id, name, balance, scope, is_active) VALUES (?, ?, ?, ?, ?, ?)',
      [user.id, null, 'Kas Utama', 0, 'personal', 1]
    );

    const token = generateToken({ id: user.id, email: user.email, role: user.role, family_id: null, company_id: null });
    return { user, token };
  },

  async login(email, password) {
    const users = await db.query('SELECT * FROM users WHERE email = ?', [email.toLowerCase().trim()]);
    if (!users || users.length === 0) {
      throw new Error('Invalid email or password');
    }

    const user = users[0];
    const isValid = verifyPassword(password, user.password_hash);
    if (!isValid) {
      throw new Error('Invalid email or password');
    }

    const userSafe = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      family_id: user.family_id,
      company_id: user.company_id
    };

    const token = generateToken({ id: user.id, email: user.email, role: user.role, family_id: user.family_id, company_id: user.company_id });
    return { user: userSafe, token };
  },

  async getUserById(id) {
    const users = await db.query('SELECT id, name, email, role, family_id, company_id, created_at FROM users WHERE id = ?', [id]);
    return users && users.length > 0 ? users[0] : null;
  }
};
