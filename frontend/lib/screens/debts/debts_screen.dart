import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/debt_model.dart';
import '../../widgets/due_date_badge.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  void _showPaymentModal(BuildContext context, DebtModel debt) {
    final finance = context.read<FinanceProvider>();
    final amountController = TextEditingController(text: debt.remainingAmount.toString());
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
                      Text(
                        debt.type == 'payable' ? 'Bayar Hutang: ${debt.personName}' : 'Terima Piutang: ${debt.personName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Sisa tagihan: ${_formatRupiah(debt.remainingAmount)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    value: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: debt.type == 'payable' ? 'Dompet Pembayaran' : 'Dompet Penerima Dana',
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
                      labelText: 'Nominal Bayar / Cicil (Rp)',
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
                          const SnackBar(content: Text('Harap pilih dompet dan isi nominal dengan benar')),
                        );
                        return;
                      }

                      Navigator.pop(modalCtx);
                      final success = await finance.payDebt(debtId: debt.id, walletId: selectedWalletId!, amount: amount);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran berhasil dicatat!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: debt.type == 'payable' ? AppTheme.warningAmber : AppTheme.incomeGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      debt.type == 'payable' ? 'Bayar Cicilan / Lunas' : 'Konfirmasi Terima Dana',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
      appBar: AppBar(title: const Text('Catatan Hutang & Piutang')),
      body: finance.debts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.event_available_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tidak ada catatan hutang atau piutang aktif', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: finance.debts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final debt = finance.debts[index];
                final isPayable = debt.type == 'payable';

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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isPayable ? AppTheme.expenseRed : AppTheme.incomeGreen).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isPayable ? Icons.call_made_rounded : Icons.call_received_rounded,
                                  size: 16,
                                  color: isPayable ? AppTheme.expenseRed : AppTheme.incomeGreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(debt.personName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          DueDateBadge(status: debt.computedStatus, dueDate: debt.dueDate),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sisa: ${_formatRupiah(debt.remainingAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                          ),
                          Text('Total: ${_formatRupiah(debt.totalAmount)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (debt.status != 'paid')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showPaymentModal(context, debt),
                            icon: const Icon(Icons.payment_rounded, size: 18),
                            label: Text(isPayable ? 'Bayar / Cicil' : 'Terima Pembayaran'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPayable ? AppTheme.warningAmber : AppTheme.incomeGreen,
                              foregroundColor: Colors.white,
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
