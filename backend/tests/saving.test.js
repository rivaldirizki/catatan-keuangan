import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { WalletService } from '../src/services/wallet.service.js';
import { SavingService } from '../src/services/saving.service.js';

describe('Task 4: SavingService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create savings goal and calculate progress', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik@saving.com', 'pass123');
    const goal = await SavingService.createGoal(user.id, 'Dana Darurat', 10000000, '2026-12-31');

    assert.strictEqual(goal.goal_name, 'Dana Darurat');
    assert.strictEqual(goal.target_amount, 10000000);
    assert.strictEqual(goal.current_amount, 0);
    assert.strictEqual(goal.progress_percentage, 0);
  });

  it('should deposit to savings: wallet decreases and saving increases atomically', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik2@saving.com', 'pass123');
    const wallet = await WalletService.createWallet(user.id, 'BCA Gaji', 2000000);
    const goal = await SavingService.createGoal(user.id, 'Liburan Akhir Tahun', 5000000);

    // Deposit 500,000 from wallet to savings
    const depositResult = await SavingService.deposit(user.id, wallet.id, goal.id, 500000, '2026-11-20', 'Nabung bulanan');

    // Wallet balance must decrease from 2,000,000 to 1,500,000
    const updatedWallet = await WalletService.getWalletById(wallet.id);
    assert.strictEqual(updatedWallet.balance, 1500000);

    // Saving current_amount must increase from 0 to 500,000
    const updatedGoal = await SavingService.getGoalById(goal.id);
    assert.strictEqual(updatedGoal.current_amount, 500000);
    assert.strictEqual(updatedGoal.progress_percentage, 10);
    assert.strictEqual(depositResult.success, true);
  });

  it('should reject deposit if wallet has insufficient balance', async () => {
    const { user } = await AuthService.register('Tasik', 'tasik3@saving.com', 'pass123');
    const wallet = await WalletService.createWallet(user.id, 'Dompet Pas-pasan', 100000);
    const goal = await SavingService.createGoal(user.id, 'Beli Motor', 20000000);

    await assert.rejects(async () => {
      await SavingService.deposit(user.id, wallet.id, goal.id, 500000, '2026-11-20');
    }, /insufficient balance/i);
  });
});
