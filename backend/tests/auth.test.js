import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';

describe('Task 2: AuthService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should register a new user with hashed password and return JWT token', async () => {
    const res = await AuthService.register('Tasik User', 'tasik@example.com', 'password123');
    assert.ok(res.user);
    assert.strictEqual(res.user.email, 'tasik@example.com');
    assert.strictEqual(res.user.name, 'Tasik User');
    assert.ok(res.token, 'Should return a JWT token string');
    assert.ok(!res.user.password_hash, 'Should not leak password_hash in response');
  });

  it('should reject registration with existing email', async () => {
    await AuthService.register('Tasik User', 'tasik@example.com', 'password123');
    await assert.rejects(async () => {
      await AuthService.register('Duplicate User', 'tasik@example.com', 'password456');
    }, /email already registered/i);
  });

  it('should login valid user and verify password', async () => {
    await AuthService.register('Tasik User', 'tasik@example.com', 'password123');
    const loginRes = await AuthService.login('tasik@example.com', 'password123');
    assert.ok(loginRes.token);
    assert.strictEqual(loginRes.user.email, 'tasik@example.com');
  });

  it('should reject login with wrong password', async () => {
    await AuthService.register('Tasik User', 'tasik@example.com', 'password123');
    await assert.rejects(async () => {
      await AuthService.login('tasik@example.com', 'wrongpassword');
    }, /invalid email or password/i);
  });
});
