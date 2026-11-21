import { describe, it, before } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { WalletService } from '../src/services/wallet.service.js';
import { TransactionService } from '../src/services/transaction.service.js';
import { DebtService } from '../src/services/debt.service.js';
import { SavingService } from '../src/services/saving.service.js';

describe('Task 3: Anti-Double-Input Idempotency Engine (TDD)', () => {
  let userId;
  let walletId;

  before(async () => {
    if (db.mock) db.mock.reset();
    const reg = await AuthService.register('Idemp User', 'idemp@test.com', 'password123');
    userId = reg.user.id;
    const wallets = await WalletService.getWallets(userId);
    walletId = wallets[0].id;

    // Set initial balance
    await db.query('UPDATE wallets SET balance = ? WHERE id = ?', [100000, walletId]);
  });

  it('should ignore duplicate income with identical idempotency_key and not mutate balance twice', async () => {
    const key = 'idemp_inc_unique_001';

    // 1st attempt: new transaction
    const res1 = await TransactionService.recordIncome(
      userId, walletId, null, 50000, '2026-11-21', 'Setoran Online', false, null, key
    );
    assert.strictEqual(res1.amount, 50000);
    assert.strictEqual(res1.new_wallet_balance, 150000);
    assert.strictEqual(Boolean(res1.already_processed), false);

    // 2nd attempt: duplicate idempotency key (simulating network retry)
    const res2 = await TransactionService.recordIncome(
      userId, walletId, null, 50000, '2026-11-21', 'Setoran Online', false, null, key
    );
    assert.strictEqual(res2.id, res1.id);
    assert.strictEqual(res2.amount, 50000);
    assert.strictEqual(res2.new_wallet_balance, 150000);
    assert.strictEqual(res2.already_processed, true);

    // Check actual wallet balance remains 150000 (not 200000)
    const curWallet = await WalletService.getWalletById(walletId);
    assert.strictEqual(Number(curWallet.balance), 150000);
  });

  it('should ignore duplicate expense with identical idempotency_key and not deduct balance twice', async () => {
    const key = 'idemp_exp_unique_002';

    // 1st attempt: expense 40000
    const res1 = await TransactionService.recordExpense(
      userId, walletId, null, 40000, '2026-11-21', 'Belanja Perlengkapan', false, null, key
    );
    assert.strictEqual(res1.amount, 40000);
    assert.strictEqual(res1.new_wallet_balance, 110000);
    assert.strictEqual(Boolean(res1.already_processed), false);

    // 2nd attempt: resend with same key
    const res2 = await TransactionService.recordExpense(
      userId, walletId, null, 40000, '2026-11-21', 'Belanja Perlengkapan', false, null, key
    );
    assert.strictEqual(res2.id, res1.id);
    assert.strictEqual(res2.already_processed, true);

    // Balance remains 110000 (not 70000)
    const curWallet = await WalletService.getWalletById(walletId);
    assert.strictEqual(Number(curWallet.balance), 110000);
  });

  it('should ignore duplicate debt creation with identical idempotency_key', async () => {
    const key = 'idemp_debt_unique_003';

    // 1st attempt
    const debt1 = await DebtService.createDebt(
      userId, 'payable', 'Toko Bangunan', 300000, '2026-12-01', 'Beli semen', 'personal', null, null, 3, key
    );
    assert.strictEqual(debt1.total_amount, 300000);
    assert.strictEqual(Boolean(debt1.already_processed), false);

    // 2nd attempt
    const debt2 = await DebtService.createDebt(
      userId, 'payable', 'Toko Bangunan', 300000, '2026-12-01', 'Beli semen', 'personal', null, null, 3, key
    );
    assert.strictEqual(debt2.id, debt1.id);
    assert.strictEqual(debt2.already_processed, true);

    const allDebts = await DebtService.getDebts(userId);
    const matching = allDebts.filter(d => d.person_name === 'Toko Bangunan');
    assert.strictEqual(matching.length, 1);
  });

  it('should ignore duplicate savings deposit with identical idempotency_key', async () => {
    const goal = await SavingService.createGoal(userId, 'Dana Darurat Idemp', 500000);
    const key = 'idemp_sav_unique_004';

    // 1st attempt: deposit 25000
    const dep1 = await SavingService.deposit(userId, walletId, goal.id, 25000, '2026-11-21', 'Nabung darurat', key);
    assert.strictEqual(dep1.success, true);
    assert.strictEqual(dep1.new_saving_amount, 25000);
    assert.strictEqual(Boolean(dep1.already_processed), false);

    // 2nd attempt: duplicate key
    const dep2 = await SavingService.deposit(userId, walletId, goal.id, 25000, '2026-11-21', 'Nabung darurat', key);
    assert.strictEqual(dep2.already_processed, true);

    const updatedGoal = await SavingService.getGoalById(goal.id);
    assert.strictEqual(updatedGoal.current_amount, 25000); // Not 50000!
  });
});
