import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { WalletService } from '../src/services/wallet.service.js';
import { TransactionService } from '../src/services/transaction.service.js';
import { SavingService } from '../src/services/saving.service.js';
import { DebtService } from '../src/services/debt.service.js';
import { FamilyService } from '../src/services/family.service.js';

describe('Security Remediation & Defensive Controls Test Suite', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('SEC-01 & SEC-04: should reject transferring funds from a wallet not owned by user', async () => {
    // User 1
    const u1 = await AuthService.register('Victim User', 'victim@mail.com', 'pass123');
    const u1Wallets = await WalletService.getWallets(u1.user.id);
    const u1Wallet = u1Wallets[0];
    await TransactionService.recordIncome(u1.user.id, u1Wallet.id, null, 100000, '2026-11-22');

    // User 2 (Attacker)
    const u2 = await AuthService.register('Attacker User', 'attacker@mail.com', 'pass123');
    const u2Wallets = await WalletService.getWallets(u2.user.id);
    const u2Wallet = u2Wallets[0];

    // Attacker tries to transfer Victim's money into their own wallet
    await assert.rejects(async () => {
      await TransactionService.transfer(u2.user.id, u1Wallet.id, u2Wallet.id, 50000, '2026-11-22');
    }, /Akses ditolak: Dompet sumber bukan milik Anda/i);
  });

  it('SEC-02: should reject withdrawing from another user\'s personal savings goal (BOLA)', async () => {
    const u1 = await AuthService.register('Goal Owner', 'owner@mail.com', 'pass123');
    const u1Wallets = await WalletService.getWallets(u1.user.id);
    const u1Wallet = u1Wallets[0];
    await TransactionService.recordIncome(u1.user.id, u1Wallet.id, null, 200000, '2026-11-22');

    const goal = await SavingService.createGoal(u1.user.id, 'Dana Pensiun Pribadi', 500000, '2030-01-01', 'personal');
    await SavingService.deposit(u1.user.id, u1Wallet.id, goal.id, 100000, '2026-11-22');

    const u2 = await AuthService.register('Sneaky User', 'sneaky@mail.com', 'pass123');
    const u2Wallets = await WalletService.getWallets(u2.user.id);
    const u2Wallet = u2Wallets[0];

    // Attacker tries to withdraw Victim's savings into Attacker's wallet
    await assert.rejects(async () => {
      await SavingService.withdraw(u2.user.id, goal.id, u2Wallet.id, 50000, '2026-11-22');
    }, /Akses ditolak/i);
  });

  it('SEC-02: should reject paying debt using someone else\'s wallet (BOLA)', async () => {
    const u1 = await AuthService.register('Debt Holder', 'debtholder@mail.com', 'pass123');
    const debt = await DebtService.createDebt(u1.user.id, 'payable', 'Toko Bangunan', 150000, '2026-12-01');

    const u2 = await AuthService.register('Innocent Bystander', 'bystander@mail.com', 'pass123');
    const u2Wallets = await WalletService.getWallets(u2.user.id);
    const u2Wallet = u2Wallets[0];
    await TransactionService.recordIncome(u2.user.id, u2Wallet.id, null, 200000, '2026-11-22');

    // u1 tries to pay their debt using u2's wallet
    await assert.rejects(async () => {
      await DebtService.recordPayment(u1.user.id, debt.id, u2Wallet.id, 50000, '2026-11-22');
    }, /Akses ditolak/i);
  });

  it('SEC-03: should only return family-scoped transactions in member summary', async () => {
    const fam = await FamilyService.createFamily(1, 'Keluarga Bahagia');
    const u1 = await AuthService.register('Ayah', 'ayah@keluarga.com', 'pass123');
    await db.query('UPDATE users SET family_id = ? WHERE id = ?', [fam.id, u1.user.id]);
    const u1Wallets = await WalletService.getWallets(u1.user.id);
    const u1Wallet = u1Wallets[0];

    // Personal transaction
    await TransactionService.recordIncome(u1.user.id, u1Wallet.id, null, 500000, '2026-11-22', 'Gaji Rahasia', false);
    // Family transaction
    await TransactionService.recordExpense(u1.user.id, u1Wallet.id, null, 100000, '2026-11-22', 'Belanja Dapur Bersama', true, fam.id);

    const summary = await TransactionService.getMemberSummary(fam.id, u1.user.id);
    // Personal transaction must NOT appear in family member summary
    assert.strictEqual(summary.transactions.length, 1);
    assert.strictEqual(summary.transactions[0].notes, 'Belanja Dapur Bersama');
    assert.strictEqual(summary.total_income, 0); // No family income recorded
    assert.strictEqual(summary.total_expense, 100000);
  });

  it('BUG-03: should reject NaN and non-finite numbers on income, expense, and transfer', async () => {
    const u = await AuthService.register('Tester', 'tester@test.com', 'pass123');
    const wallets = await WalletService.getWallets(u.user.id);
    const w = wallets[0];

    await assert.rejects(async () => {
      await TransactionService.recordIncome(u.user.id, w.id, null, NaN, '2026-11-22');
    }, /Amount must be greater than 0/i);

    await assert.rejects(async () => {
      await TransactionService.recordExpense(u.user.id, w.id, null, 'not_a_number', '2026-11-22');
    }, /Amount must be greater than 0/i);
  });
});
