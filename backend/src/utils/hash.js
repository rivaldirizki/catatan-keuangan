import crypto from 'node:crypto';

export function hashPassword(password, salt = 'a1b2c3d4e5f67890') {
  const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  return `${salt}:${hash}`;
}

const adminHash = hashPassword('alvian14');
console.log('ADMIN_HASH:', adminHash);
