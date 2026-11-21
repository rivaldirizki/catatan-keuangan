import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/debt_model.dart';
import '../../widgets/due_date_badge.dart';

class DebtsScreen extends StatefulWidget {
  final bool isEmbedded;
  const DebtsScreen({super.key, this.isEmbedded = false});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  String _filter = 'all'; // 'all', 'payable', 'receivable'

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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 28,
                left: 20,
                right: 20,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              debt.type == 'payable' ? 'Bayar / Cicil Hutang' : 'Terima Pembayaran Piutang',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            Text(
                              'Pihak: ${debt.personName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(modalCtx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sisa Tagihan', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        Text(
                          _formatRupiah(debt.remainingAmount),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    initialValue: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: debt.type == 'payable' ? 'Dompet Pembayaran' : 'Dompet Penerima',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                    items: finance.wallets.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text('${w.name} (${_formatRupiah(w.balance)})'));
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Nominal Bayar / Cicil',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 22),

                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (amount <= 0 || selectedWalletId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harap pilih dompet dan isi nominal dengan benar')),
                        );
                        return;
                      }

                      HapticFeedback.mediumImpact();
                      Navigator.pop(modalCtx);
                      final success = await finance.payDebt(debtId: debt.id, walletId: selectedWalletId!, amount: amount);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran berhasil dicatat!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: debt.type == 'payable' ? AppTheme.warningOrange : AppTheme.incomeGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      debt.type == 'payable' ? 'Bayar Hutang' : 'Terima Dana Piutang',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  void _showAddDebtModal(BuildContext context) {
    final finance = context.read<FinanceProvider>();
    final personController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String type = 'payable'; // 'payable' or 'receivable'
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 28,
                left: 20,
                right: 20,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const Text(
                    'Catat Hutang / Piutang Baru',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // Segmented Switch
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => type = 'payable');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'payable' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: type == 'payable'
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Text(
                                'Hutang Saya',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: type == 'payable' ? AppTheme.warningOrange : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => type = 'receivable');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'receivable' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: type == 'receivable'
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Text(
                                'Piutang (Orang Berhutang)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: type == 'receivable' ? AppTheme.incomeGreen : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: personController,
                    decoration: InputDecoration(
                      labelText: 'Nama Pihak / Orang',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Total Nominal',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.textSecondary),
                              const SizedBox(width: 10),
                              Text(
                                'Jatuh Tempo: ${selectedDate.toIso8601String().split('T')[0]}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Keterangan (Opsional)',
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      final person = personController.text.trim();
                      final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (person.isEmpty || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama dan nominal harus diisi')),
                        );
                        return;
                      }

                      HapticFeedback.mediumImpact();
                      Navigator.pop(modalCtx);
                      await finance.createDebt(
                        personName: person,
                        type: type,
                        amount: amount,
                        dueDate: selectedDate.toIso8601String().split('T')[0],
                        notes: notesController.text,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Simpan Catatan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

    int totalPayable = finance.debts.where((d) => d.type == 'payable').fold(0, (sum, d) => sum + d.remainingAmount);
    int totalReceivable = finance.debts.where((d) => d.type == 'receivable').fold(0, (sum, d) => sum + d.remainingAmount);

    final filteredDebts = finance.debts.where((d) {
      if (_filter == 'payable') return d.type == 'payable';
      if (_filter == 'receivable') return d.type == 'receivable';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.iosBg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text('Hutang & Piutang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.iosBlue, size: 24),
            onPressed: () => _showAddDebtModal(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hutang Saya', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatRupiah(totalPayable),
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.warningOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Piutang (Dipinjam)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatRupiah(totalReceivable),
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // iOS Segmented Filter
            Container(
              decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  _buildFilterTab('all', 'Semua'),
                  _buildFilterTab('payable', 'Hutang Saya'),
                  _buildFilterTab('receivable', 'Piutang'),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (filteredDebts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.event_available_rounded, size: 48, color: AppTheme.textTertiary),
                    SizedBox(height: 12),
                    Text('Tidak ada catatan pada filter ini', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDebts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final debt = filteredDebts[index];
                  final isPayable = debt.type == 'payable';

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: (isPayable ? AppTheme.warningOrange : AppTheme.incomeGreen).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPayable ? Icons.call_made_rounded : Icons.call_received_rounded,
                                      size: 16,
                                      color: isPayable ? AppTheme.warningOrange : AppTheme.incomeGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          debt.personName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2),
                                        ),
                                        Text(
                                          isPayable ? 'Hutang saya' : 'Piutang saya',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            DueDateBadge(status: debt.dueStatus, dueDate: debt.dueDate),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: AppTheme.iosDivider, height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sisa Tagihan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _formatRupiah(debt.remainingAmount),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: debt.remainingAmount == 0 ? AppTheme.incomeGreen : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (debt.remainingAmount > 0) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showPaymentModal(context, debt);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isPayable ? AppTheme.textPrimary : AppTheme.incomeGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isPayable ? 'Bayar / Cicil' : 'Terima Dana',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _filter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _filter = key);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1.5))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
