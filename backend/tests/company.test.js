import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { CompanyService } from '../src/services/company.service.js';

describe('Task 2: CompanyService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create a new company with 8-character invite code and link creator', async () => {
    const authRes = await AuthService.register('CEO Alice', 'alice@company.com', 'secret123');
    const company = await CompanyService.createCompany(authRes.user.id, 'PT Maju Bersama');
    assert.ok(company.id);
    assert.strictEqual(company.name, 'PT Maju Bersama');
    assert.strictEqual(company.invite_code.length, 8);

    // Verify creator was linked to company
    const updatedUser = await AuthService.getUserById(authRes.user.id);
    assert.strictEqual(updatedUser.company_id, company.id);
  });

  it('should allow another user to join the company via invite code', async () => {
    const ceo = await AuthService.register('CEO', 'ceo@corp.com', 'secret123');
    const staff = await AuthService.register('Staff', 'staff@corp.com', 'secret123');

    const company = await CompanyService.createCompany(ceo.user.id, 'PT Sukses Mandiri');
    const joinRes = await CompanyService.joinCompany(staff.user.id, company.invite_code);
    assert.strictEqual(joinRes.success, true);

    const members = await CompanyService.getCompanyMembers(company.id);
    assert.strictEqual(members.length, 2);
    const emails = members.map(m => m.email);
    assert.ok(emails.includes('ceo@corp.com'));
    assert.ok(emails.includes('staff@corp.com'));
  });

  it('should reject joining with invalid invite code', async () => {
    const user = await AuthService.register('Staff2', 'staff2@corp.com', 'secret123');
    await assert.rejects(async () => {
      await CompanyService.joinCompany(user.user.id, 'INVALID88');
    }, /invalid invite code/i);
  });
});
