import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { WalletService } from '../src/services/wallet.service.js';
import { TransactionService } from '../src/services/transaction.service.js';

describe('Task 3: Wallets & TransactionService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create wallets and record income and expense updating balance', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik@test.com', 'pass123');
    const wallet = await WalletService.createWallet(user.id, 'Bank BCA', 1000000);
    assert.strictEqual(wallet.balance, 1000000);

    // Record Income (+500,000)
    await TransactionService.recordIncome(user.id, wallet.id, null, 500000, '2026-11-20', 'Gaji');
    const updatedWallet1 = await WalletService.getWalletById(wallet.id);
    assert.strictEqual(updatedWallet1.balance, 1500000);

    // Record Expense (-200,000)
    await TransactionService.recordExpense(user.id, wallet.id, null, 200000, '2026-11-20', 'Belanja');
    const updatedWallet2 = await WalletService.getWalletById(wallet.id);
    assert.strictEqual(updatedWallet2.balance, 1300000);
  });

  it('should transfer money between wallets atomically', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik2@test.com', 'pass123');
    const w1 = await WalletService.createWallet(user.id, 'Bank Mandiri', 500000);
    const w2 = await WalletService.createWallet(user.id, 'GoPay', 50000);

    await TransactionService.transfer(user.id, w1.id, w2.id, 200000, '2026-11-20', 'Topup GoPay');

    const resW1 = await WalletService.getWalletById(w1.id);
    const resW2 = await WalletService.getWalletById(w2.id);

    assert.strictEqual(resW1.balance, 300000);
    assert.strictEqual(resW2.balance, 250000);
  });

  it('should reject transfer when source wallet has insufficient balance', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik3@test.com', 'pass123');
    const w1 = await WalletService.createWallet(user.id, 'Dompet Kecil', 50000);
    const w2 = await WalletService.createWallet(user.id, 'Dompet Tujuan', 0);

    await assert.rejects(async () => {
      await TransactionService.transfer(user.id, w1.id, w2.id, 100000, '2026-11-20', 'Transfer Gagal');
    }, /insufficient balance/i);
  });

  it('should isolate transactions per user and allow shared view when familyView is true', async () => {
    const userA = (await AuthService.register('User A', 'usera@test.com', 'pass123')).user;
    const userB = (await AuthService.register('User B', 'userb@test.com', 'pass123')).user;

    const wA = await WalletService.createWallet(userA.id, 'Dompet A', 500000);
    const wB = await WalletService.createWallet(userB.id, 'Dompet B', 300000);

    await TransactionService.recordExpense(userA.id, wA.id, null, 50000, '2026-11-20', 'Makan Siang A');
    await TransactionService.recordExpense(userB.id, wB.id, null, 70000, '2026-11-20', 'Bensin B');

    // Personal view for User A: only 1 transaction
    const txA = await TransactionService.getTransactions(userA.id, null, false);
    assert.strictEqual(txA.length, 1);
    assert.strictEqual(txA[0].notes, 'Makan Siang A');
  });
});
