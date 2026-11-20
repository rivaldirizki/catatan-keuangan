import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { WalletService } from '../src/services/wallet.service.js';
import { DebtService } from '../src/services/debt.service.js';

describe('Task 5: DebtService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create debt and auto-determine due status', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik@debt.com', 'pass123');

    // Future debt
    const debt = await DebtService.createDebt(
      user.id,
      'payable',
      'Pak Budi',
      1000000,
      '2026-12-15',
      'Pinjam modal usaha'
    );

    assert.strictEqual(debt.person_name, 'Pak Budi');
    assert.strictEqual(debt.total_amount, 1000000);
    assert.strictEqual(debt.remaining_amount, 1000000);
    assert.strictEqual(debt.status, 'unpaid');
  });

  it('should record partial and full payments, updating wallet and debt status', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik2@debt.com', 'pass123');
    const wallet = await WalletService.createWallet(user.id, 'Kas Utama', 2000000);
    const debt = await DebtService.createDebt(user.id, 'payable', 'Toko Bangunan', 1000000, '2026-12-01');

    // 1. Partial payment: Pay 400,000
    const payRes1 = await DebtService.recordPayment(user.id, debt.id, wallet.id, 400000, '2026-11-20', 'Cicilan 1');
    assert.strictEqual(payRes1.remaining_amount, 600000);
    assert.strictEqual(payRes1.status, 'partially_paid');

    const walletAfterPay1 = await WalletService.getWalletById(wallet.id);
    assert.strictEqual(walletAfterPay1.balance, 1600000);

    // 2. Full remaining payment: Pay 600,000
    const payRes2 = await DebtService.recordPayment(user.id, debt.id, wallet.id, 600000, '2026-11-25', 'Pelunasan');
    assert.strictEqual(payRes2.remaining_amount, 0);
    assert.strictEqual(payRes2.status, 'paid');

    const walletAfterPay2 = await WalletService.getWalletById(wallet.id);
    assert.strictEqual(walletAfterPay2.balance, 1000000);
  });

  it('should flag debts past due date as overdue', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik3@debt.com', 'pass123');
    // Debt with past date
    const pastDebt = await DebtService.createDebt(user.id, 'payable', 'Teman SMA', 500000, '2026-11-01');

    const debts = await DebtService.getDebts(user.id);
    const found = debts.find(d => d.id === pastDebt.id);
    assert.strictEqual(found.computed_status, 'overdue');
  });
});
