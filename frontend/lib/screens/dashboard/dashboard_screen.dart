import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/family_switcher.dart';
import '../savings/savings_screen.dart';
import '../debts/debts_screen.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchDashboard();
    });
  }

  void _showAddTransactionModal() {
    final finance = context.read<FinanceProvider>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String type = 'expense'; // 'income' or 'expense'
    int? selectedWalletId = finance.wallets.isNotEmpty ? finance.wallets.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Catat Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Segmented type selector
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setModalState(() => type = 'expense'),
                          icon: const Icon(Icons.trending_down, size: 18),
                          label: const Text('Pengeluaran'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: type == 'expense' ? AppTheme.expenseRed : Colors.grey.shade200,
                            foregroundColor: type == 'expense' ? Colors.white : Colors.black87,
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setModalState(() => type = 'income'),
                          icon: const Icon(Icons.trending_up, size: 18),
                          label: const Text('Pemasukan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: type == 'income' ? AppTheme.incomeGreen : Colors.grey.shade200,
                            foregroundColor: type == 'income' ? Colors.white : Colors.black87,
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Wallet selector
                  DropdownButtonFormField<int>(
                    value: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Dompet / Rekening',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: finance.wallets.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text(w.name));
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 14),

                  // Nominal input
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nominal (Rp)',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes input
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Catatan / Keterangan (Opsional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (amount <= 0 || selectedWalletId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nominal dan dompet harus diisi dengan benar')),
                        );
                        return;
                      }

                      Navigator.pop(modalCtx);
                      final date = DateTime.now().toIso8601String().split('T')[0];

                      if (type == 'expense') {
                        await finance.addExpense(walletId: selectedWalletId!, amount: amount, date: date, notes: notesController.text);
                      } else {
                        await finance.addIncome(walletId: selectedWalletId!, amount: amount, date: date, notes: notesController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'expense' ? AppTheme.expenseRed : AppTheme.incomeGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finance = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${auth.currentUser?.name ?? "Pengguna"}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  finance.isFamilyView ? 'Mode Keuangan Keluarga' : 'Mode Keuangan Pribadi',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const FamilySwitcher(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => finance.fetchDashboard(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 Balance Summary Cards (Grid)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.4 : 1.3,
                    children: [
                      BalanceCard(
                        title: 'Total Saldo',
                        amount: finance.totalBalance,
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppTheme.slateDark,
                        subtitle: '${finance.wallets.length} Dompet aktif',
                      ),
                      BalanceCard(
                        title: 'Pemasukan',
                        amount: finance.totalIncome,
                        icon: Icons.trending_up_rounded,
                        color: AppTheme.incomeGreen,
                      ),
                      BalanceCard(
                        title: 'Pengeluaran',
                        amount: finance.totalExpense,
                        icon: Icons.trending_down_rounded,
                        color: AppTheme.expenseRed,
                      ),
                      BalanceCard(
                        title: 'Arus Kas Bersih',
                        amount: finance.netCashflow,
                        icon: Icons.swap_vert_rounded,
                        color: finance.netCashflow >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Quick Action Navigation Cards (Tabungan & Hutang)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsScreen())),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.savingBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.savingBlue.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppTheme.savingBlue, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tabungan & Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('${finance.savings.length} Target aktif', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningAmber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.warningAmber.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppTheme.warningAmber, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hutang & Piutang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('${finance.debts.length} Catatan', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transaksi Terbaru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slateDark)),
                  Text('${finance.transactions.length} mutasi', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),

              // Transactions List
              if (finance.transactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.slateBorder),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Belum ada transaksi tercatat', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: finance.transactions.length > 10 ? 10 : finance.transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = finance.transactions[index];
                    final isExpense = tx.type == 'expense' || tx.type == 'saving_deposit';
                    final color = tx.type == 'income'
                        ? AppTheme.incomeGreen
                        : (tx.type == 'saving_deposit' ? AppTheme.savingBlue : AppTheme.expenseRed);
                    final icon = tx.type == 'income'
                        ? Icons.arrow_downward_rounded
                        : (tx.type == 'saving_deposit' ? Icons.savings_rounded : Icons.arrow_upward_rounded);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.slateBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                            child: Icon(icon, size: 20, color: color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.notes?.isNotEmpty == true ? tx.notes! : (isExpense ? 'Pengeluaran' : 'Pemasukan'),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(tx.transactionDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text(
                            '${isExpense ? "-" : "+"} Rp ${tx.amount}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: color,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionModal,
        backgroundColor: AppTheme.slateDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catat Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
