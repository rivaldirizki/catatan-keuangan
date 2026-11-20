import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  return `${salt}:${hash}`;
}

export async function runMigration() {
  const host = process.env.DB_HOST || 'localhost';
  const port = Number(process.env.DB_PORT) || 3306;
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || '';
  const database = process.env.DB_NAME || 'finance_db';

  console.log(`[Migration] Menghubungkan ke MySQL ${host}:${port}...`);
  const connection = await mysql.createConnection({ host, port, user, password, multipleStatements: true });

  console.log(`[Migration] Membuat database \`${database}\` jika belum ada...`);
  await connection.query(`CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
  await connection.query(`USE \`${database}\`;`);

  const schemaPath = path.join(__dirname, 'schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');

  console.log('[Migration] Menjalankan skema tabel...');
  await connection.query(sql);

  // Seed Admin user
  const adminEmail = 'admin@gmail.com';
  const adminPass = 'alvian14';
  const [existingAdmin] = await connection.query('SELECT id FROM users WHERE email = ?', [adminEmail]);

  let adminId;
  if (existingAdmin.length === 0) {
    console.log(`[Migration] Mendaftarkan admin user: ${adminEmail}...`);
    const passwordHash = hashPassword(adminPass);
    const [res] = await connection.query(
      'INSERT INTO users (name, email, password_hash, role, family_id) VALUES (?, ?, ?, ?, ?)',
      ['Admin Finance', adminEmail, passwordHash, 'admin', null]
    );
    adminId = res.insertId;

    // Create default wallet for admin
    await connection.query(
      'INSERT INTO wallets (user_id, family_id, name, balance, scope, is_active) VALUES (?, ?, ?, ?, ?, ?)',
      [adminId, null, 'Kas Utama Admin', 0, 'personal', 1]
    );
    console.log(`[Migration] Admin user ${adminEmail} berhasil dibuat! (ID: ${adminId})`);
  } else {
    adminId = existingAdmin[0].id;
    const passwordHash = hashPassword(adminPass);
    await connection.query('UPDATE users SET password_hash = ?, role = "admin" WHERE id = ?', [passwordHash, adminId]);
    console.log(`[Migration] Password untuk admin ${adminEmail} berhasil diperbarui!`);
  }

  // Seed default categories if empty
  const [categories] = await connection.query('SELECT id FROM categories LIMIT 1');
  if (categories.length === 0) {
    console.log('[Migration] Mengisi kategori default...');
    const defaultCategories = [
      ['Gaji', 'income', '#10B981', 'briefcase'],
      ['Investasi & Bonus', 'income', '#059669', 'trending-up'],
      ['Makanan & Minuman', 'expense', '#EF4444', 'utensils'],
      ['Transportasi', 'expense', '#F59E0B', 'car'],
      ['Tagihan & Utilitas', 'expense', '#6366F1', 'receipt'],
      ['Belanja Kebutuhan', 'expense', '#EC4899', 'shopping-bag'],
      ['Kesehatan', 'expense', '#14B8A6', 'heart-pulse']
    ];
    for (const [name, type, color, icon] of defaultCategories) {
      await connection.query(
        'INSERT INTO categories (user_id, name, type, color, icon) VALUES (?, ?, ?, ?, ?)',
        [null, name, type, color, icon]
      );
    }
  }

  console.log('[Migration] Seluruh tabel dan data admin berhasil dimigrasi ke MySQL!');
  await connection.end();
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runMigration().then(() => {
    console.log('[Migration] Selesai.');
    process.exit(0);
  }).catch(err => {
    console.error('[Migration Error]', err.message);
    process.exit(1);
  });
}
