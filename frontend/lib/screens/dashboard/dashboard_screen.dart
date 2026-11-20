import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/saving_model.dart';
import '../../widgets/family_switcher.dart';
import '../history/history_screen.dart';
import '../savings/savings_screen.dart';
import '../debts/debts_screen.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTab = 0;
  bool _isBalanceVisible = true;
  int? _selectedMemberFilterId; // null = semua anggota

  // Onboarding controllers
  int _onboardingTab = 0; // 0: Buat Keluarga, 1: Masuk Keluarga
  final _onboardingNameController = TextEditingController();
  final _onboardingCodeController = TextEditingController();
  bool _isOnboardingLoading = false;
  String? _onboardingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().fetchDashboard();
    });
  }

  @override
  void dispose() {
    _onboardingNameController.dispose();
    _onboardingCodeController.dispose();
    super.dispose();
  }

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppTheme.incomeGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ======================= MODAL TRANSAKSI =======================
  void _showAddTransactionModal({bool isFamilyPreselected = false}) {
    final finance = context.read<FinanceProvider>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String type = 'expense';
    bool isFamily = isFamilyPreselected || finance.isFamilyView;
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
                      Row(
                        children: [
                          Icon(
                            isFamily ? Icons.family_restroom_rounded : Icons.edit_note_rounded,
                            color: isFamily ? AppTheme.familyPurple : AppTheme.iosBlue,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isFamily ? 'Catat Finansial Keluarga' : 'Catat Transaksi Pribadi',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(modalCtx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F2F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Segmented Type Selector
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => type = 'expense');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'expense' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: type == 'expense'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: type == 'expense' ? AppTheme.expenseRed : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: type == 'expense' ? AppTheme.expenseRed : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => type = 'income');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'income' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: type == 'income'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: type == 'income' ? AppTheme.incomeGreen : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: type == 'income' ? AppTheme.incomeGreen : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wallet selector
                  DropdownButtonFormField<int>(
                    initialValue: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Dompet / Rekening',
                      labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                    items: finance.wallets.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text(w.name));
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 12),

                  // Nominal input
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Nominal',
                      labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes input
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Catatan / Keterangan',
                      labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (amount <= 0 || selectedWalletId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nominal dan dompet harus diisi dengan benar')),
                        );
                        return;
                      }

                      HapticFeedback.mediumImpact();
                      Navigator.pop(modalCtx);
                      final date = DateTime.now().toIso8601String().split('T')[0];

                      if (type == 'expense') {
                        await finance.addExpense(
                          walletId: selectedWalletId!,
                          amount: amount,
                          date: date,
                          notes: notesController.text,
                          isFamily: isFamily,
                        );
                      } else {
                        await finance.addIncome(
                          walletId: selectedWalletId!,
                          amount: amount,
                          date: date,
                          notes: notesController.text,
                          isFamily: isFamily,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'expense' ? AppTheme.expenseRed : AppTheme.incomeGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Simpan ${type == "expense" ? "Pengeluaran" : "Pemasukan"}',
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

  // ======================= MODAL NABUNG BERSAMA =======================
  void _showDepositToSharedSavingModal([SavingModel? preselectedSaving]) {
    final finance = context.read<FinanceProvider>();
    final sharedSavings = finance.savings.where((s) => s.isFamilyShared).toList();

    if (sharedSavings.isEmpty && preselectedSaving == null) {
      _showCreateFamilySavingModal();
      return;
    }

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    int? selectedSavingId = preselectedSaving?.id ?? (sharedSavings.isNotEmpty ? sharedSavings.first.id : null);
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
                      const Row(
                        children: [
                          Icon(Icons.savings_rounded, color: AppTheme.familyPurple, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Nabung Bersama Keluarga',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
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
                  const SizedBox(height: 18),

                  // Target Saving Picker
                  DropdownButtonFormField<int>(
                    initialValue: selectedSavingId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Target Celengan Bersama',
                      prefixIcon: const Icon(Icons.stars_rounded, color: AppTheme.familyPurple),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: sharedSavings.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.goalName} (${s.progressPercentage}%)'),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedSavingId = val),
                  ),
                  const SizedBox(height: 12),

                  // Wallet Picker
                  DropdownButtonFormField<int>(
                    initialValue: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: 'Sumber Dana (Dompet Anda)',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: finance.wallets.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text('${w.name} (Saldo: ${_formatRupiah(w.balance)})'));
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Nominal Setoran',
                      prefixText: 'Rp ',
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Pesan / Semangat (Opsional)',
                      hintText: 'Contoh: Tambahan tabungan liburan',
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (amount <= 0 || selectedSavingId == null || selectedWalletId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lengkapi nominal, target celengan, dan dompet')),
                        );
                        return;
                      }

                      Navigator.pop(modalCtx);
                      HapticFeedback.mediumImpact();
                      final success = await finance.depositToSaving(
                        walletId: selectedWalletId!,
                        savingId: selectedSavingId!,
                        amount: amount,
                        notes: notesController.text,
                      );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Berhasil menyetor ${_formatRupiah(amount)} ke Celengan Bersama!'),
                            backgroundColor: AppTheme.incomeGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.familyPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Setor ke Celengan Bersama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======================= MODAL BUAT CELENGAN BERSAMA =======================
  void _showCreateFamilySavingModal() {
    final finance = context.read<FinanceProvider>();
    final goalNameController = TextEditingController();
    final targetAmountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
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
                  decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Target Celengan Bersama',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Celengan ini dapat diakses dan diisi bersama oleh seluruh anggota keluarga hingga target nominal tercapai.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: goalNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Target Tabungan',
                  hintText: 'Contoh: Liburan Akhir Tahun, Renovasi Rumah',
                  prefixIcon: const Icon(Icons.flag_rounded, color: AppTheme.familyPurple),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetAmountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Target Nominal',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final name = goalNameController.text.trim();
                  final amount = int.tryParse(targetAmountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                  if (name.isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nama target dan nominal target harus valid')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  final success = await finance.createSavingGoal(
                    goalName: name,
                    targetAmount: amount,
                    scope: 'family',
                  );

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Celengan Bersama "$name" berhasil dibuat!'),
                        backgroundColor: AppTheme.incomeGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.familyPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Buat Celengan Bersama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================= MODAL INSPEKSI ANGGOTA KELUARGA =======================
  void _showMemberInspectionModal(Map<String, dynamic> member) {
    final finance = context.read<FinanceProvider>();
    final memberId = int.tryParse(member['id'].toString()) ?? 0;
    final memberName = member['name']?.toString() ?? 'Anggota';
    final memberEmail = member['email']?.toString() ?? '';
    final memberRole = member['role']?.toString() ?? 'user';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: finance.getMemberFinancialSummary(memberId),
          builder: (context, snapshot) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
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
                      decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.familyPurple.withValues(alpha: 0.15),
                            child: Text(
                              memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppTheme.familyPurple, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    memberName,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: memberRole == 'admin' ? AppTheme.familyPurple.withValues(alpha: 0.12) : const Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      memberRole == 'admin' ? 'Kepala Keluarga' : 'Anggota',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: memberRole == 'admin' ? AppTheme.familyPurple : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(memberEmail, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.familyPurple)),
                    )
                  else if (!snapshot.hasData || snapshot.data == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Gagal memuat catatan finansial anggota ini')),
                    )
                  else ...[
                    // Ringkasan Keuangan Anggota
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pemasukan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatRupiah(int.tryParse(snapshot.data!['total_income'].toString()) ?? 0),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 30, color: AppTheme.iosDivider),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pengeluaran', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatRupiah(int.tryParse(snapshot.data!['total_expense'].toString()) ?? 0),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 30, color: AppTheme.iosDivider),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Arus Kas', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatRupiah(int.tryParse(snapshot.data!['net_cashflow'].toString()) ?? 0),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: (int.tryParse(snapshot.data!['net_cashflow'].toString()) ?? 0) >= 0
                                        ? AppTheme.incomeGreen
                                        : AppTheme.expenseRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Riwayat Transaksi Anggota
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Riwayat Catatan Transaksi',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        Text(
                          '${(snapshot.data!['transactions'] as List).length} catatan',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.38),
                      child: (snapshot.data!['transactions'] as List).isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.receipt_long_rounded, color: AppTheme.textTertiary, size: 36),
                                  SizedBox(height: 8),
                                  Text('Belum ada transaksi tercatat dari anggota ini', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: (snapshot.data!['transactions'] as List).length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.iosDivider),
                              itemBuilder: (context, i) {
                                final tx = (snapshot.data!['transactions'] as List)[i] as Map<String, dynamic>;
                                final isIncome = tx['type'] == 'income';
                                final amount = int.tryParse(tx['amount'].toString()) ?? 0;
                                final date = tx['transaction_date']?.toString().split('T')[0] ?? '';
                                final notes = tx['notes']?.toString();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                          size: 16,
                                          color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notes != null && notes.isNotEmpty ? notes : (isIncome ? 'Pemasukan' : 'Pengeluaran'),
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                            ),
                                            Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${isIncome ? "+" : "-"} ${_formatRupiah(amount)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======================= MODAL DETAIL & KELOLA KELUARGA =======================
  void _showFamilyInfoModal() {
    final finance = context.read<FinanceProvider>();
    final family = finance.currentFamily;
    final inviteCode = family?.inviteCode ?? '--------';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Informasi Ruang Keluarga',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Code Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E1065), Color(0xFF4C1D95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family?.name ?? 'Keluarga Kita',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${finance.familyMembers.length} Anggota Tergabung',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    const Text('KODE UNDANGAN KELUARGA:', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          inviteCode,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3.0, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _copyToClipboard(inviteCode, 'Kode $inviteCode disalin ke clipboard!'),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Salin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.familyPurple,
                            minimumSize: const Size(0, 34),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('Daftar Anggota Keluarga', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: finance.familyMembers.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: AppTheme.iosDivider),
                itemBuilder: (context, i) {
                  final member = finance.familyMembers[i];
                  final name = member['name']?.toString() ?? 'Anggota';
                  final email = member['email']?.toString() ?? '';
                  final role = member['role']?.toString() ?? 'user';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.familyPurple.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.familyPurple, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    trailing: role == 'admin'
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.familyPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Admin', style: TextStyle(color: AppTheme.familyPurple, fontSize: 10, fontWeight: FontWeight.w700)),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showMemberInspectionModal(member);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================= MAIN BUILD =======================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finance = context.watch<FinanceProvider>();
    final isFamily = finance.isFamilyView;
    final hasFamily = auth.currentUser?.familyId != null;

    return Scaffold(
      backgroundColor: isFamily ? const Color(0xFFF6F5FC) : AppTheme.iosBg,
      appBar: _currentTab == 0
          ? AppBar(
              toolbarHeight: 64,
              backgroundColor: isFamily ? const Color(0xFFF6F5FC) : Colors.white,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isFamily)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEDE9FE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.family_restroom_rounded, size: 14, color: AppTheme.familyPurple),
                        ),
                      Text(
                        isFamily
                            ? (finance.currentFamily?.name ?? (hasFamily ? 'Ruang Keluarga' : 'Finansial Keluarga'))
                            : 'Halo, ${auth.currentUser?.name ?? "Pengguna"}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isFamily
                        ? (hasFamily
                            ? 'ID: ${finance.currentFamily?.inviteCode ?? "..."} • ${finance.familyMembers.length} Anggota Aktif'
                            : 'Mulai Ruang Keuangan Bersama')
                        : 'Tampilan Finansial Pribadi',
                    style: TextStyle(
                      fontSize: 12,
                      color: isFamily ? AppTheme.familyPurple : AppTheme.textSecondary,
                      fontWeight: isFamily ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              actions: [
                const FamilySwitcher(),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20, color: AppTheme.textSecondary),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    auth.logout();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                ),
                const SizedBox(width: 12),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildSummaryView(finance, auth),
          HistoryScreen(
            isEmbedded: true,
            onAddTransactionPressed: () => _showAddTransactionModal(isFamilyPreselected: finance.isFamilyView),
          ),
          const SavingsScreen(isEmbedded: true),
          const DebtsScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.iosDivider, width: 0.8)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, isFamily ? Icons.family_restroom_rounded : Icons.account_balance_wallet_rounded, isFamily ? 'Keluarga' : 'Ringkasan', () {
                  setState(() => _currentTab = 0);
                }, isFamilyView: isFamily),
                _buildNavItem(1, Icons.receipt_long_rounded, 'Riwayat', () {
                  setState(() => _currentTab = 1);
                }, isFamilyView: isFamily),
                _buildNavItem(2, Icons.savings_rounded, isFamily ? 'Celengan' : 'Celengan', () {
                  setState(() => _currentTab = 2);
                }, isFamilyView: isFamily),
                _buildNavItem(3, Icons.event_note_rounded, 'Hutang', () {
                  setState(() => _currentTab = 3);
                }, isFamilyView: isFamily),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView(FinanceProvider finance, AuthProvider auth) {
    if (!finance.isFamilyView) {
      return _buildPersonalDashboardView(finance, auth);
    }

    final hasFamily = auth.currentUser?.familyId != null;
    if (!hasFamily) {
      return _buildFamilyOnboardingView(finance, auth);
    }

    return _buildFamilyDashboardView(finance, auth);
  }

  // ======================= VIEW 1: PERSONAL DASHBOARD =======================
  Widget _buildPersonalDashboardView(FinanceProvider finance, AuthProvider auth) {
    return RefreshIndicator(
      onRefresh: () => finance.fetchDashboard(),
      color: AppTheme.iosBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Apple Wallet Classic Hero Card (Carbon Black)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'KAS PRIBADI',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${finance.wallets.length} Akun aktif',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Total Saldo Saya',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isBalanceVisible ? _formatRupiah(finance.totalBalance) : '••••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showAddTransactionModal(isFamilyPreselected: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Catat', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentTab = 2);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.savings_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Celengan', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentTab = 3);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_note_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Hutang', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cashflow Group
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppTheme.incomeGreen.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.incomeGreen),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pemasukan', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatRupiah(finance.totalIncome),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppTheme.iosDivider),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppTheme.expenseRed.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppTheme.expenseRed),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pengeluaran', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatRupiah(finance.totalExpense),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: AppTheme.iosDivider, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Arus Kas Bersih (Bulan Ini)',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatRupiah(finance.netCashflow),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: finance.netCashflow >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaksi Terbaru
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaksi Pribadi Terbaru',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _currentTab = 1);
                    },
                    child: const Row(
                      children: [
                        Text('Lihat Semua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.iosBlue)),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.iosBlue),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            _buildTransactionList(finance.transactions),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ======================= VIEW 2: DEDICATED FAMILY DASHBOARD =======================
  Widget _buildFamilyDashboardView(FinanceProvider finance, AuthProvider auth) {
    final family = finance.currentFamily;
    final inviteCode = family?.inviteCode ?? '--------';
    final sharedSavings = finance.savings.where((s) => s.isFamilyShared).toList();

    // Transactions filtered by selected member if any
    final displayedTransactions = _selectedMemberFilterId == null
        ? finance.transactions
        : finance.transactions.where((t) => t.userId == _selectedMemberFilterId).toList();

    return RefreshIndicator(
      onRefresh: () => finance.fetchDashboard(),
      color: AppTheme.familyPurple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ROYAL VIOLET FAMILY HERO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E1065), Color(0xFF4C1D95), Color(0xFF3B28CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Badge & Members
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.family_restroom_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'RUANG KELUARGA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${finance.familyMembers.length} Anggota',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Saldo Gabungan
                  Text(
                    'Total Kas Bersama Keluarga',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isBalanceVisible ? _formatRupiah(finance.totalBalance) : '••••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Inline ID Undangan Bar (1-Tap Copy)
                  GestureDetector(
                    onTap: () => _copyToClipboard(inviteCode, 'ID Keluarga $inviteCode disalin!'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.vpn_key_rounded, size: 14, color: Colors.amberAccent),
                              const SizedBox(width: 6),
                              Text(
                                'ID KELUARGA: $inviteCode',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text('Salin', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                              SizedBox(width: 4),
                              Icon(Icons.copy_rounded, size: 13, color: Colors.white70),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4 Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showDepositToSharedSavingModal(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.savings_rounded, size: 18, color: Colors.amberAccent),
                                SizedBox(height: 4),
                                Text(
                                  'Nabung',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showAddTransactionModal(isFamilyPreselected: true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                                SizedBox(height: 4),
                                Text(
                                  'Catat',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showCreateFamilySavingModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.flag_rounded, size: 18, color: Colors.white),
                                SizedBox(height: 4),
                                Text(
                                  '+ Target',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showFamilyInfoModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.group_outlined, size: 18, color: Colors.white),
                                SizedBox(height: 4),
                                Text(
                                  'Anggota',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. ARUS KAS KELUARGA
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEDE9FE), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B21A8).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppTheme.incomeGreen.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.incomeGreen),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pemasukan Keluarga', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatRupiah(finance.totalIncome),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppTheme.iosDivider),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppTheme.expenseRed.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppTheme.expenseRed),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pengeluaran Keluarga', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatRupiah(finance.totalExpense),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Color(0xFFEDE9FE), height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Arus Kas Bersih Keluarga',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatRupiah(finance.netCashflow),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: finance.netCashflow >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. FITUR UTAMA 1: CELENGAN BERSAMA (SHARED SAVINGS)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.savings_rounded, size: 20, color: AppTheme.familyPurple),
                    SizedBox(width: 6),
                    Text(
                      'Celengan Bersama',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showCreateFamilySavingModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: AppTheme.familyPurple),
                        SizedBox(width: 3),
                        Text(
                          'Target Baru',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (sharedSavings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEDE9FE)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDE9FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_rounded, color: AppTheme.familyPurple, size: 28),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum Ada Celengan Bersama',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ayo mulai tabungan bersama untuk liburan keluarga, renovasi rumah, atau dana darurat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showCreateFamilySavingModal,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Buat Celengan Bersama'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.familyPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sharedSavings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final saving = sharedSavings[i];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEDE9FE)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B21A8).withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.stars_rounded, color: AppTheme.familyPurple, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      saving.goalName,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                    ),
                                    Text(
                                      'Target: ${_formatRupiah(saving.targetAmount)}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: saving.progressPercentage >= 100
                                    ? AppTheme.incomeGreen.withValues(alpha: 0.12)
                                    : const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${saving.progressPercentage}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: saving.progressPercentage >= 100 ? AppTheme.incomeGreen : AppTheme.familyPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (saving.progressPercentage / 100).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFEDE9FE),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              saving.progressPercentage >= 100 ? AppTheme.incomeGreen : AppTheme.familyPurple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Terkumpul: ${_formatRupiah(saving.currentAmount)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                            ),
                            ElevatedButton(
                              onPressed: () => _showDepositToSharedSavingModal(saving),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.familyPurple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                              child: const Text('Nabung Bersama', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // 4. FITUR UTAMA 2: CATATAN KEUANGAN ANGGOTA KELUARGA (CLICKABLE MEMBER BREAKDOWN)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catatan Keuangan Anggota',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ketuk anggota untuk inspeksi catatan & arus kasnya',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                if (_selectedMemberFilterId != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedMemberFilterId = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.close_rounded, size: 12, color: AppTheme.familyPurple),
                          SizedBox(width: 4),
                          Text('Reset Filter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.familyPurple)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Member Selector
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: finance.familyMembers.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    final isAll = _selectedMemberFilterId == null;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedMemberFilterId = null);
                      },
                      child: Container(
                        width: 78,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isAll ? AppTheme.familyPurple : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isAll ? AppTheme.familyPurple : const Color(0xFFEDE9FE)),
                          boxShadow: isAll
                              ? [
                                  BoxShadow(
                                    color: AppTheme.familyPurple.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.groups_rounded, size: 24, color: isAll ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(height: 4),
                            Text(
                              'Semua',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isAll ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final member = finance.familyMembers[i - 1];
                  final memberId = int.tryParse(member['id'].toString()) ?? 0;
                  final name = member['name']?.toString() ?? 'Anggota';
                  final isCurrent = memberId == auth.currentUser?.id;
                  final isSelected = _selectedMemberFilterId == memberId;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedMemberFilterId = memberId);
                      _showMemberInspectionModal(member);
                    },
                    child: Container(
                      width: 96,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEDE9FE) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? AppTheme.familyPurple : const Color(0xFFEDE9FE), width: isSelected ? 1.5 : 1.0),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.familyPurple.withValues(alpha: 0.15),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppTheme.familyPurple, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCurrent ? '$name (Anda)' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? AppTheme.familyPurple : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 5. FITUR UTAMA 3: AKTIVITAS KEUANGAN BERSAMA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Aktivitas Keuangan Keluarga',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_selectedMemberFilterId != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Filter Aktif', style: TextStyle(fontSize: 10, color: AppTheme.familyPurple, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _currentTab = 1);
                  },
                  child: const Row(
                    children: [
                      Text('Riwayat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.familyPurple)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.familyPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildTransactionList(displayedTransactions, isFamilyMode: true),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ======================= VIEW 3: ONBOARDING RUANG KELUARGA =======================
  Widget _buildFamilyOnboardingView(FinanceProvider finance, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Onboarding Hero Card
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1065), Color(0xFF4C1D95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4C1D95).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.family_restroom_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ruang Finansial Keluarga',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Satu sistem cerdas untuk menabung bersama, memantau pengeluaran transparan, dan mewujudkan impian keluarga Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3 Nilai Fitur
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEDE9FE)),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  Icons.savings_rounded,
                  'Celengan Bersama',
                  'Isi tabungan bersama pasangan/anak hingga target tercapai.',
                  Colors.amber.shade700,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFEDE9FE), height: 1),
                ),
                _buildFeatureRow(
                  Icons.visibility_rounded,
                  'Transparansi Finansial',
                  'Klik dan pantau catatan pemasukan/pengeluaran tiap anggota.',
                  AppTheme.familyPurple,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFEDE9FE), height: 1),
                ),
                _buildFeatureRow(
                  Icons.vpn_key_rounded,
                  'Kode Akses Acak 8 Karakter',
                  'Setiap keluarga memiliki kode rahasia unik untuk bergabung.',
                  AppTheme.iosBlue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Segmented Tab Buat vs Masuk
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _onboardingTab = 0;
                        _onboardingError = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _onboardingTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _onboardingTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        'Buat Keluarga Baru',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _onboardingTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _onboardingTab == 0 ? AppTheme.familyPurple : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _onboardingTab = 1;
                        _onboardingError = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _onboardingTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _onboardingTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        'Masuk dengan Kode ID',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _onboardingTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _onboardingTab == 1 ? AppTheme.familyPurple : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_onboardingError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.expenseRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.expenseRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_onboardingError!, style: const TextStyle(color: AppTheme.expenseRed, fontSize: 13)),
                  ),
                ],
              ),
            ),

          if (_onboardingTab == 0) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDE9FE)),
              ),
              child: TextField(
                controller: _onboardingNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nama Keluarga (contoh: Keluarga Pratama)',
                  prefixIcon: Icon(Icons.home_outlined, color: AppTheme.familyPurple),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isOnboardingLoading
                  ? null
                  : () async {
                      final name = _onboardingNameController.text.trim();
                      if (name.isEmpty) {
                        setState(() => _onboardingError = 'Harap isi nama keluarga');
                        return;
                      }

                      setState(() {
                        _isOnboardingLoading = true;
                        _onboardingError = null;
                      });

                      final result = await auth.createFamily(name);
                      if (result != null && mounted) {
                        await finance.fetchDashboard();
                        setState(() => _isOnboardingLoading = false);
                        _copyToClipboard(result['invite_code'].toString(), 'Keluarga dibuat! Kode ID: ${result['invite_code']}');
                      } else if (mounted) {
                        setState(() {
                          _isOnboardingLoading = false;
                          _onboardingError = auth.errorMessage ?? 'Gagal membuat keluarga';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.familyPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isOnboardingLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Buat Ruang Keluarga Sekarang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDE9FE)),
              ),
              child: TextField(
                controller: _onboardingCodeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2.0),
                decoration: const InputDecoration(
                  hintText: 'MASUKKAN 8 DIGIT KODE ID',
                  hintStyle: TextStyle(letterSpacing: 0, fontSize: 13),
                  prefixIcon: Icon(Icons.vpn_key_rounded, color: AppTheme.familyPurple),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isOnboardingLoading
                  ? null
                  : () async {
                      final code = _onboardingCodeController.text.trim().toUpperCase();
                      if (code.isEmpty) {
                        setState(() => _onboardingError = 'Harap masukkan 8 digit kode');
                        return;
                      }

                      setState(() {
                        _isOnboardingLoading = true;
                        _onboardingError = null;
                      });

                      final success = await auth.joinFamily(code);
                      if (success && mounted) {
                        await finance.fetchDashboard();
                        setState(() => _isOnboardingLoading = false);
                      } else if (mounted) {
                        setState(() {
                          _isOnboardingLoading = false;
                          _onboardingError = auth.errorMessage ?? 'Kode ID tidak ditemukan';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.familyPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isOnboardingLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gabung ke Keluarga', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  // ======================= HELPER: LIST TRANSAKSI =======================
  Widget _buildTransactionList(List transactions, {bool isFamilyMode = false}) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isFamilyMode ? const Color(0xFFEDE9FE) : AppTheme.iosDivider, width: 0.8),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 44, color: isFamilyMode ? const Color(0xFFC4B5FD) : AppTheme.textTertiary),
            const SizedBox(height: 12),
            Text(
              isFamilyMode ? 'Belum ada transaksi keluarga tercatat' : 'Belum ada transaksi tercatat',
              style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFamilyMode ? const Color(0xFFEDE9FE) : AppTheme.iosDivider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length > 10 ? 10 : transactions.length,
          separatorBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(left: 60),
            child: Divider(color: AppTheme.iosDivider, height: 1),
          ),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isExpense = tx.type == 'expense' || tx.type == 'saving_deposit';
            final color = tx.type == 'income'
                ? AppTheme.incomeGreen
                : (tx.type == 'saving_deposit' ? (isFamilyMode ? AppTheme.familyPurple : AppTheme.iosBlue) : AppTheme.expenseRed);
            final icon = tx.type == 'income'
                ? Icons.arrow_downward_rounded
                : (tx.type == 'saving_deposit' ? Icons.savings_rounded : Icons.arrow_upward_rounded);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.notes?.isNotEmpty == true ? tx.notes! : (isExpense ? 'Pengeluaran' : 'Pemasukan'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              tx.transactionDate,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            if (isFamilyMode && tx.userName != null) ...[
                              const Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'Oleh ${tx.userName}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExpense ? "-" : "+"} ${_formatRupiah(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: color,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ======================= HELPER: NAV ITEM =======================
  Widget _buildNavItem(int index, IconData icon, String label, VoidCallback onTap, {bool isFamilyView = false}) {
    final isSelected = _currentTab == index;
    final activeColor = isFamilyView ? AppTheme.familyPurple : AppTheme.iosBlue;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 23,
              color: isSelected ? activeColor : AppTheme.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
