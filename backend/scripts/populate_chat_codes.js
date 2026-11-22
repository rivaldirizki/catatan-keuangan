import crypto from 'node:crypto';
import { db } from '../src/config/database.js';

async function run() {
  const users = await db.query('SELECT id, name, email, chat_invite_code FROM users WHERE chat_invite_code IS NULL OR chat_invite_code = ""');
  console.log(`Found ${users.length} users needing chat_invite_code.`);

  for (const u of users) {
    const code = 'CHAT-' + crypto.randomBytes(4).toString('hex').toUpperCase();
    await db.query('UPDATE users SET chat_invite_code = ? WHERE id = ?', [code, u.id]);
    console.log(`Assigned [${code}] to user #${u.id} (${u.name})`);
  }

  const all = await db.query('SELECT id, name, email, chat_invite_code FROM users');
  console.log('\n--- ALL USERS IN DB ---');
  for (const u of all) {
    console.log(`#${u.id} | ${u.name} | ${u.email} | Code: ${u.chat_invite_code}`);
  }
  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
