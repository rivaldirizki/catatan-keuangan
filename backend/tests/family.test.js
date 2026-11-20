import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { FamilyService } from '../src/services/family.service.js';

describe('Task 2: FamilyService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create a new family with 8-character invite code and link creator', async () => {
    const authRes = await AuthService.register('Budi', 'budi@example.com', 'secret123');
    const family = await FamilyService.createFamily(authRes.user.id, 'Keluarga Budi');
    assert.ok(family.id);
    assert.strictEqual(family.name, 'Keluarga Budi');
    assert.strictEqual(family.invite_code.length, 8);

    // Verify user was updated with family_id
    const user = await AuthService.getUserById(authRes.user.id);
    assert.strictEqual(user.family_id, family.id);
  });

  it('should allow another user to join the family via invite code', async () => {
    const parent = await AuthService.register('Ayah', 'ayah@example.com', 'secret123');
    const child = await AuthService.register('Anak', 'anak@example.com', 'secret123');

    const family = await FamilyService.createFamily(parent.user.id, 'Keluarga Bahagia');
    const joinResult = await FamilyService.joinFamily(child.user.id, family.invite_code);
    assert.strictEqual(joinResult.success, true);

    const members = await FamilyService.getFamilyMembers(family.id);
    assert.strictEqual(members.length, 2);
    const emails = members.map(m => m.email);
    assert.ok(emails.includes('ayah@example.com'));
    assert.ok(emails.includes('anak@example.com'));
  });

  it('should reject joining with invalid invite code', async () => {
    const user = await AuthService.register('Seseorang', 'user@example.com', 'secret123');
    await assert.rejects(async () => {
      await FamilyService.joinFamily(user.user.id, 'INVALID99');
    }, /invalid invite code/i);
  });
});
