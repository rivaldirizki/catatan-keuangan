import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/saving_model.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  void _showDepositModal(BuildContext context, SavingModel goal) {
    final finance = context.read<FinanceProvider>();
    final amountController = TextEditingController();
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
                      Text('Setor ke: ${goal.goalName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Saldo dompet akan dipotong dan saldo tabungan ini akan bertambah secara otomatis.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Wallet selector
                  DropdownButtonFormField<int>(
                    value: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Dompet Sumber Dana',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: finance.wallets.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text('${w.name} (Saldo: ${_formatRupiah(w.balance)})'));
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nominal Setoran (Rp)',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (amount <= 0 || selectedWalletId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harap pilih dompet dan isi nominal setoran')),
                        );
                        return;
                      }

                      Navigator.pop(modalCtx);
                      final success = await finance.depositToSaving(walletId: selectedWalletId!, savingId: goal.id, amount: amount);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Berhasil menyetor ke tabungan!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.savingBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Setor Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final finance = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tabungan & Target Keuangan')),
      body: finance.savings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada target tabungan yang dibuat', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: finance.savings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final goal = finance.savings[index];
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.slateBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(goal.goalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: goal.status == 'completed'
                                  ? AppTheme.incomeGreen.withOpacity(0.12)
                                  : AppTheme.savingBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              goal.status == 'completed' ? 'Tercapai' : '${goal.progressPercentage}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: goal.status == 'completed' ? AppTheme.incomeGreen : AppTheme.savingBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Linear Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (goal.progressPercentage / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          color: goal.status == 'completed' ? AppTheme.incomeGreen : AppTheme.savingBlue,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Terkumpul: ${_formatRupiah(goal.currentAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slateDark),
                          ),
                          Text(
                            'Target: ${_formatRupiah(goal.targetAmount)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDepositModal(context, goal),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text('Setor Tabungan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.savingBlue,
                            side: const BorderSide(color: AppTheme.savingBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
