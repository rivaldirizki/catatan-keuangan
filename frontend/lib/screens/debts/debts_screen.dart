import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
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
                              'Pihak: ${debt.personName}${debt.installmentsCount > 1 ? " • Cicilan ${debt.installmentsCount}x" : ""}',
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
    final auth = context.read<AuthProvider>();
    final hasFamily = auth.currentUser?.familyId != null;
    final hasCompany = auth.currentUser?.companyId != null;

    final personController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final customInstallmentController = TextEditingController(text: '1');
    String type = 'payable'; // 'payable' or 'receivable'
    int installmentsCount = 1;
    bool isCustomInstallment = false;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    // Determine initial scope from active view
    String selectedScope = finance.isCompanyView && hasCompany
        ? 'company'
        : (finance.isFamilyView && hasFamily ? 'family' : 'personal');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final parsedAmount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
            final currentInstallmentCount = isCustomInstallment
                ? (int.tryParse(customInstallmentController.text.trim()) ?? 1)
                : installmentsCount;
            final estPerCicilan = currentInstallmentCount > 1 && parsedAmount > 0
                ? (parsedAmount / currentInstallmentCount).round()
                : 0;

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
              child: SingleChildScrollView(
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 14),

                    // Scope Chip Selector (Personal / Family / Company)
                    if (hasFamily || hasCompany) ...[
                      Row(
                        children: [
                          _buildScopeChip(
                            label: 'Pribadi',
                            icon: Icons.person_rounded,
                            isSelected: selectedScope == 'personal',
                            color: AppTheme.iosBlue,
                            onTap: () => setModalState(() => selectedScope = 'personal'),
                          ),
                          if (hasFamily) ...[
                            const SizedBox(width: 8),
                            _buildScopeChip(
                              label: 'Keluarga',
                              icon: Icons.family_restroom_rounded,
                              isSelected: selectedScope == 'family',
                              color: AppTheme.familyPurple,
                              onTap: () => setModalState(() => selectedScope = 'family'),
                            ),
                          ],
                          if (hasCompany) ...[
                            const SizedBox(width: 8),
                            _buildScopeChip(
                              label: 'Perusahaan',
                              icon: Icons.business_rounded,
                              isSelected: selectedScope == 'company',
                              color: const Color(0xFF1E3A8A),
                              onTap: () => setModalState(() => selectedScope = 'company'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Segmented Switch: Hutang vs Piutang
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
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: type == 'payable' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: type == 'payable'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text(
                                  'Hutang',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
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
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: type == 'receivable' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: type == 'receivable'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text(
                                  'Piutang (Dipinjamkan)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: type == 'receivable' ? AppTheme.incomeGreen : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: personController,
                      decoration: InputDecoration(
                        labelText: 'Nama Pihak / Orang / Mitra',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF2F2F7),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: 'Total Nominal Tagihan',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: const Color(0xFFF2F2F7),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cicilan / Tenor Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jumlah Cicilan / Tenor',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildInstallmentChip(
                              label: '1x (Lunas)',
                              isSelected: !isCustomInstallment && installmentsCount == 1,
                              onTap: () => setModalState(() {
                                isCustomInstallment = false;
                                installmentsCount = 1;
                              }),
                            ),
                            _buildInstallmentChip(
                              label: '3x Cicilan',
                              isSelected: !isCustomInstallment && installmentsCount == 3,
                              onTap: () => setModalState(() {
                                isCustomInstallment = false;
                                installmentsCount = 3;
                              }),
                            ),
                            _buildInstallmentChip(
                              label: '6x Cicilan',
                              isSelected: !isCustomInstallment && installmentsCount == 6,
                              onTap: () => setModalState(() {
                                isCustomInstallment = false;
                                installmentsCount = 6;
                              }),
                            ),
                            _buildInstallmentChip(
                              label: '12x Cicilan',
                              isSelected: !isCustomInstallment && installmentsCount == 12,
                              onTap: () => setModalState(() {
                                isCustomInstallment = false;
                                installmentsCount = 12;
                              }),
                            ),
                            _buildInstallmentChip(
                              label: 'Kustom',
                              isSelected: isCustomInstallment,
                              onTap: () => setModalState(() {
                                isCustomInstallment = true;
                              }),
                            ),
                          ],
                        ),
                        if (isCustomInstallment) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: customInstallmentController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Masukkan Jumlah Berapa Kali Cicilan',
                              suffixText: 'kali',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: const Color(0xFFF2F2F7),
                            ),
                          ),
                        ],
                        if (estPerCicilan > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.iosBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calculate_outlined, size: 16, color: AppTheme.iosBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Estimasi: ${_formatRupiah(estPerCicilan)} / cicilan ($currentInstallmentCount kali)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.iosBlue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

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
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        final person = personController.text.trim();
                        final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                        final finalInstallments = isCustomInstallment
                            ? (int.tryParse(customInstallmentController.text.trim()) ?? 1)
                            : installmentsCount;

                        if (person.isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama pihak dan nominal harus diisi dengan benar')),
                          );
                          return;
                        }

                        HapticFeedback.mediumImpact();
                        Navigator.pop(modalCtx);
                        final success = await finance.createDebt(
                          personName: person,
                          type: type,
                          amount: amount,
                          dueDate: selectedDate.toIso8601String().split('T')[0],
                          notes: notesController.text,
                          scope: selectedScope,
                          installmentsCount: finalInstallments > 0 ? finalInstallments : 1,
                        );

                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Catatan hutang piutang berhasil disimpan!')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.textPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Simpan Catatan', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScopeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textPrimary : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final mode = finance.currentMode;

    // Filter debts according to active scope
    final scopedDebts = finance.debts.where((d) {
      if (mode == AppViewMode.company) {
        return d.scope == 'company' || d.companyId != null;
      } else if (mode == AppViewMode.family) {
        return d.scope == 'family' || d.familyId != null;
      } else {
        return d.scope == 'personal' || (d.familyId == null && d.companyId == null);
      }
    }).toList();

    int totalPayable = scopedDebts.where((d) => d.type == 'payable').fold(0, (sum, d) => sum + d.remainingAmount);
    int totalReceivable = scopedDebts.where((d) => d.type == 'receivable').fold(0, (sum, d) => sum + d.remainingAmount);

    final filteredDebts = scopedDebts.where((d) {
      if (_filter == 'payable') return d.type == 'payable';
      if (_filter == 'receivable') return d.type == 'receivable';
      return true;
    }).toList();

    // Active reminders matching current scope
    final scopedReminders = finance.debtReminders.where((r) {
      if (mode == AppViewMode.company) {
        return r.scope == 'company' || r.companyId != null;
      } else if (mode == AppViewMode.family) {
        return r.scope == 'family' || r.familyId != null;
      } else {
        return r.scope == 'personal' || (r.familyId == null && r.companyId == null);
      }
    }).toList();

    final screenTitle = mode == AppViewMode.company
        ? 'Hutang & Piutang Usaha'
        : (mode == AppViewMode.family ? 'Hutang & Piutang Keluarga' : 'Hutang & Piutang Pribadi');

    final payableLabel = mode == AppViewMode.company
        ? 'Hutang Usaha'
        : (mode == AppViewMode.family ? 'Hutang Keluarga' : 'Hutang Saya');

    final receivableLabel = mode == AppViewMode.company
        ? 'Piutang Usaha'
        : (mode == AppViewMode.family ? 'Piutang Keluarga' : 'Piutang (Dipinjam)');

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
        title: Text(screenTitle, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
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
            // Bill Reminders Section (if any due/overdue)
            if (scopedReminders.isNotEmpty) ...[
              _buildRemindersBanner(context, scopedReminders, scopedDebts),
              const SizedBox(height: 14),
            ],

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
                        Text(payableLabel, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
                        Text(receivableLabel, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
                  _buildFilterTab('payable', payableLabel),
                  _buildFilterTab('receivable', receivableLabel),
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
                    padding: const EdgeInsets.all(16),
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isPayable ? AppTheme.warningOrange : AppTheme.incomeGreen).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPayable ? Icons.call_made_rounded : Icons.call_received_rounded,
                                      size: 15,
                                      color: isPayable ? AppTheme.warningOrange : AppTheme.incomeGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                debt.personName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _buildScopeTag(debt.scope),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isPayable ? 'Hutang ke pihak terkait' : 'Piutang dipinjamkan',
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

                        // Cicilan & Tenor Badge
                        if (debt.installmentsCount > 1) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.iosBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.repeat_rounded, size: 12, color: AppTheme.iosBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'Cicilan ${debt.installmentsCount}x (@ ${_formatRupiah(debt.installmentAmount)})',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.iosBlue),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.iosDivider, height: 1),
                        const SizedBox(height: 12),
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
                                        fontSize: 15.5,
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
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
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

  Widget _buildScopeTag(String scope) {
    Color color;
    String label;
    if (scope == 'company') {
      color = const Color(0xFF1E3A8A);
      label = 'Perusahaan';
    } else if (scope == 'family') {
      color = AppTheme.familyPurple;
      label = 'Keluarga';
    } else {
      color = AppTheme.textSecondary;
      label = 'Pribadi';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildRemindersBanner(BuildContext context, List<DebtReminderModel> reminders, List<DebtModel> allDebts) {
    final highestUrgency = reminders.any((r) => r.isOverdue || r.urgency == 'high');
    final bannerBg = highestUrgency ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB);
    final borderColor = highestUrgency ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A);
    final accentColor = highestUrgency ? const Color(0xFFE11D48) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tagihan & Pengingat Hutang (${reminders.length})',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: reminders.map((rem) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rem.reminderMessage,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: highestUrgency ? const Color(0xFF881337) : const Color(0xFF78350F),
                        ),
                      ),
                    ),
                    if (rem.type == 'payable' && rem.remainingAmount > 0) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final matching = allDebts.where((d) => d.id == rem.id).firstOrNull;
                          if (matching != null) {
                            _showPaymentModal(context, matching);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Bayar',
                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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
