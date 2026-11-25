import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { CompanyService } from '../src/services/company.service.js';
import { ProjectService } from '../src/services/project.service.js';
import { WalletService } from '../src/services/wallet.service.js';

describe('Task 3: ProjectService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create a project under company with budget', async () => {
    const ceo = await AuthService.register('CEO', 'ceo@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Agensi Digital');

    const project = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Pembuatan Website Klien A',
      description: 'Proyek pengembangan web portal e-commerce',
      target_budget: 25000000
    });

    assert.ok(project.id);
    assert.strictEqual(project.company_id, comp.id);
    assert.strictEqual(Number(project.target_budget), 25000000);
    assert.strictEqual(Number(project.current_income), 0);
    assert.strictEqual(Number(project.current_expense), 0);
  });

  it('should record project income and expense, updating project balances atomically', async () => {
    const ceo = await AuthService.register('CEO', 'ceo2@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Tech Studio');
    const wallet = await WalletService.createWallet(ceo.user.id, 'Rekening Operasional', 10000000);

    const proj = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Mobile App Project',
      target_budget: 50000000
    });

    // 1. Catat Pemasukan Klien (Termin 1: Rp 30.000.000)
    await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
      wallet_id: wallet.id,
      type: 'income',
      amount: 30000000,
      notes: 'Pembayaran DP Termin 1'
    });

    // 2. Catat Pengeluaran Proyek (Sewa Server & Desain: Rp 5.000.000)
    await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
      wallet_id: wallet.id,
      type: 'expense',
      amount: 5000000,
      notes: 'Pembelian domain dan server cloud'
    });

    const updatedProj = await ProjectService.getProjectById(comp.id, proj.id);
    assert.strictEqual(Number(updatedProj.current_income), 30000000);
    assert.strictEqual(Number(updatedProj.current_expense), 5000000);
    assert.strictEqual(Number(updatedProj.net_profit), 25000000);

    // Dompet rekening juga bertambah bersih +25.000.000 (10jt + 30jt - 5jt = 35jt)
    const updatedWallet = await WalletService.getWalletById(wallet.id);
    assert.strictEqual(Number(updatedWallet.balance), 35000000);
  });

  it('should reject recording expense when wallet balance is insufficient', async () => {
    const ceo = await AuthService.register('CEO', 'ceo3@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Software House');
    const wallet = await WalletService.createWallet(ceo.user.id, 'Kas Kecil', 500000);

    const proj = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Sistem ERP',
      target_budget: 100000000
    });

    await assert.rejects(async () => {
      await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
        wallet_id: wallet.id,
        type: 'expense',
        amount: 2000000,
        notes: 'Biaya lisensi melebihi saldo kas'
      });
    }, /saldo dompet tidak mencukupi|insufficient/i);
  });

  it('should support personal wallet funding for project expense and auto-tag as Talangan Pribadi', async () => {
    const ceo = await AuthService.register('CEO', 'ceo4@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Talangan Co');
    const personalWallet = await WalletService.createWallet(ceo.user.id, 'BCA Pribadi CEO', 5000000, 'personal');

    const proj = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Expo Booth Project',
      target_budget: 20000000
    });

    // Expense using personal wallet (talangan)
    const result = await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
      wallet_id: personalWallet.id,
      type: 'expense',
      amount: 1500000,
      notes: 'Beli banner & merchandise'
    });

    assert.strictEqual(result.funding_source, 'personal');
    assert.ok(result.notes.includes('Talangan Pribadi'));

    const projDetails = await ProjectService.getProjectById(comp.id, proj.id);
    assert.strictEqual(Number(projDetails.current_expense), 1500000);
    assert.ok(projDetails.transactions[0].notes.includes('Talangan Pribadi'));

    // Personal wallet was deducted
    const updatedPersonalWallet = await WalletService.getWalletById(personalWallet.id);
    assert.strictEqual(Number(updatedPersonalWallet.balance), 3500000);
  });

  it('should reject wallet from unauthorized user or different company', async () => {
    const ceo = await AuthService.register('CEO', 'ceo5@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Comp A');
    const stranger = await AuthService.register('Stranger', 'stranger@biz.com', 'secret123');
    const strangerWallet = await WalletService.createWallet(stranger.user.id, 'Dompet Orang Lain', 5000000, 'personal');

    const proj = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Secret Project',
      target_budget: 10000000
    });

    await assert.rejects(async () => {
      await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
        wallet_id: strangerWallet.id,
        type: 'expense',
        amount: 500000,
        notes: 'Trying to spend stranger money'
      });
    }, /akses ditolak|bukan milik/i);
  });

  it('should gracefully handle valid and non-existent category_id without foreign key errors', async () => {
    const ceo = await AuthService.register('CEO', 'ceo6@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Studio Kreatif');
    const wallet = await WalletService.createWallet(ceo.user.id, 'Kas Usaha', 10000000);
    const proj = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Project Branding',
      target_budget: 15000000
    });

    // Valid category (id: 12 - Pendapatan Usaha)
    const tx1 = await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
      wallet_id: wallet.id,
      category_id: 12,
      type: 'income',
      amount: 5000000,
      notes: 'Pembayaran Termin 1'
    });
    assert.ok(tx1.id);

    // Non-existent category (e.g. 9999) - should gracefully fallback to null without throwing
    const tx2 = await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
      wallet_id: wallet.id,
      category_id: 9999,
      type: 'income',
      amount: 2500000,
      notes: 'Pembayaran Termin 2 dengan kategori tak dikenal'
    });
    assert.ok(tx2.id);

    const projDetails = await ProjectService.getProjectById(comp.id, proj.id);
    assert.strictEqual(Number(projDetails.current_income), 7500000);
  });
});
