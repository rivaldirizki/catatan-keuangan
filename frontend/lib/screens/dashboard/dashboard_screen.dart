import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../models/saving_model.dart';
import '../../models/project_model.dart';
import '../../widgets/family_switcher.dart';
import '../history/history_screen.dart';
import '../savings/savings_screen.dart';
import '../debts/debts_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../providers/chat_provider.dart';
import '../../services/permission_service.dart';
import '../../services/fcm_service.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int _currentTab = 0;
  int _companySubTab = 0; // 0: Proyek, 1: Arus Kas, 2: Outstanding, 3: Modal (Hutang)
  bool _isBalanceVisible = true;
  int? _selectedMemberFilterId; // null = semua anggota

  // Family Onboarding controllers
  int _onboardingTab = 0; // 0: Buat Keluarga, 1: Masuk Keluarga
  final _onboardingNameController = TextEditingController();
  final _onboardingCodeController = TextEditingController();
  bool _isOnboardingLoading = false;
  String? _onboardingError;

  // Company Onboarding controllers
  int _onboardingCompanyTab = 0; // 0: Buat, 1: Masuk
  final _onboardingCompanyNameController = TextEditingController();
  final _onboardingCompanyCodeController = TextEditingController();
  bool _isOnboardingCompanyLoading = false;
  String? _onboardingCompanyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final finance = context.read<FinanceProvider>();
      final chat = context.read<ChatProvider>();
      if (auth.currentUser != null) {
        finance.setCurrentUserId(auth.currentUser!.id.toString());
        chat.startHeartbeat(auth.currentUser!.id);
      }
      finance.fetchDashboard();
      chat.refreshAll();
      if (auth.currentUser?.companyId != null) {
        auth.getCurrentCompany();
      }
      _checkAndPromptBackgroundPermission();
      FcmService.syncToken(finance.apiClient);
    });
  }

  Future<void> _checkAndPromptBackgroundPermission() async {
    if (kIsWeb) return;
    try {
      final granted = await PermissionService.isBackgroundPermissionGranted();
      if (!granted && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final hasPrompted = prefs.getBool('prompted_bg_permission') ?? false;
        if (!hasPrompted) {
          await prefs.setBool('prompted_bg_permission', true);
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.notifications_active_rounded, color: Color(0xFF007AFF)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Izin Latar Belakang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              content: const Text(
                'Agar notifikasi obrolan dan pesan masuk tetap diterima secara realtime saat aplikasi berada di latar belakang atau layar terkunci, izinkan aplikasi berjalan di latar belakang.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF3A3A3C), height: 1.35),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Nanti Saja', style: TextStyle(color: Color(0xFF8E8E93))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await PermissionService.requestBackgroundPermission();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Izinkan Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final chat = context.read<ChatProvider>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      chat.isAppInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      chat.isAppInBackground = false;
      chat.refreshAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onboardingNameController.dispose();
    _onboardingCodeController.dispose();
    _onboardingCompanyNameController.dispose();
    _onboardingCompanyCodeController.dispose();
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
    bool isCompany = finance.isCompanyView;
    String fundingSource = isCompany
        ? (finance.wallets.any((w) => w.scope == 'company') ? 'company' : 'personal')
        : (isFamily ? 'family' : 'personal');
    int? selectedWalletId = finance.wallets.isNotEmpty ? finance.wallets.first.id : null;
    int? selectedCategoryId = finance.expenseCategories.isNotEmpty
        ? finance.expenseCategories.first.id
        : (finance.categories.isNotEmpty ? finance.categories.first.id : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentCategories = type == 'expense' ? finance.expenseCategories : finance.incomeCategories;
            if (selectedCategoryId != null && !currentCategories.any((c) => c.id == selectedCategoryId)) {
              selectedCategoryId = currentCategories.isNotEmpty ? currentCategories.first.id : null;
            }
            final companyWallets = finance.wallets.where((w) => w.scope == 'company').toList();
            final personalWallets = finance.wallets.where((w) => w.scope != 'company').toList();
            final availableWallets = isCompany
                ? (fundingSource == 'company'
                    ? (companyWallets.isNotEmpty ? companyWallets : finance.wallets)
                    : (personalWallets.isNotEmpty ? personalWallets : finance.wallets))
                : finance.wallets;
            if (availableWallets.isNotEmpty && !availableWallets.any((w) => w.id == selectedWalletId)) {
              selectedWalletId = availableWallets.first.id;
            }
            final accentColor = isCompany
                ? AppTheme.companyTeal
                : (isFamily ? const Color(0xFFEE4D2D) : const Color(0xFF118EEA));

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
                        child: Row(
                          children: [
                            Icon(
                              isCompany
                                  ? Icons.business_center_rounded
                                  : (isFamily ? Icons.family_restroom_rounded : Icons.edit_note_rounded),
                              color: isCompany
                                  ? AppTheme.companyTeal
                                  : (isFamily ? AppTheme.familyPurple : AppTheme.iosBlue),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isCompany
                                    ? 'Catat Finansial Perusahaan'
                                    : (isFamily ? 'Catat Finansial Keluarga' : 'Catat Transaksi Pribadi'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              setModalState(() {
                                type = 'expense';
                                if (finance.expenseCategories.isNotEmpty) {
                                  selectedCategoryId = finance.expenseCategories.first.id;
                                }
                              });
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
                              setModalState(() {
                                type = 'income';
                                if (finance.incomeCategories.isNotEmpty) {
                                  selectedCategoryId = finance.incomeCategories.first.id;
                                }
                              });
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

                  // Funding Source Switcher (for Company Mode)
                  if (isCompany) ...[
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() {
                                  fundingSource = 'company';
                                  if (companyWallets.isNotEmpty) {
                                    selectedWalletId = companyWallets.first.id;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: fundingSource == 'company' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: fundingSource == 'company'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.business_center_rounded,
                                      size: 13,
                                      color: fundingSource == 'company' ? AppTheme.companyTeal : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Kas Perusahaan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: fundingSource == 'company' ? FontWeight.w700 : FontWeight.w500,
                                        color: fundingSource == 'company' ? AppTheme.companyTeal : AppTheme.textSecondary,
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
                                HapticFeedback.selectionClick();
                                setModalState(() {
                                  fundingSource = 'personal';
                                  if (personalWallets.isNotEmpty) {
                                    selectedWalletId = personalWallets.first.id;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: fundingSource == 'personal' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: fundingSource == 'personal'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 13,
                                      color: fundingSource == 'personal' ? AppTheme.iosBlue : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Talangan Pribadi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: fundingSource == 'personal' ? FontWeight.w700 : FontWeight.w500,
                                        color: fundingSource == 'personal' ? AppTheme.iosBlue : AppTheme.textSecondary,
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
                  ],

                  // Wallet selector
                  DropdownButtonFormField<int>(
                    initialValue: availableWallets.any((w) => w.id == selectedWalletId)
                        ? selectedWalletId
                        : (availableWallets.isNotEmpty ? availableWallets.first.id : null),
                    decoration: InputDecoration(
                      labelText: isCompany
                          ? (fundingSource == 'company' ? 'Pilih Rekening Kas Perusahaan' : 'Pilih Dompet Talangan Pribadi')
                          : 'Pilih Dompet / Rekening',
                      labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                    items: availableWallets.map((w) {
                      final isComp = w.scope == 'company';
                      final label = isCompany
                          ? '${isComp ? "🏢 [Kas Perusahaan]" : "👤 [Dompet Pribadi]"} ${w.name} (${_formatRupiah(w.balance)})'
                          : '${w.name} (${_formatRupiah(w.balance)})';
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 12),

                  // Category Selector
                  if (currentCategories.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pilih Kategori',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                            if (selectedCategoryId != null)
                              Text(
                                currentCategories.firstWhere((c) => c.id == selectedCategoryId, orElse: () => currentCategories.first).name,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: currentCategories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, idx) {
                              final cat = currentCategories[idx];
                              final isSelected = cat.id == selectedCategoryId;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() => selectedCategoryId = cat.id);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? accentColor : const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? accentColor : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        cat.iconData,
                                        size: 15,
                                        color: isSelected ? Colors.white : cat.colorValue,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cat.name,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

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
                          isCompany: isCompany,
                          categoryId: selectedCategoryId,
                        );
                      } else {
                        await finance.addIncome(
                          walletId: selectedWalletId!,
                          amount: amount,
                          date: date,
                          notes: notesController.text,
                          isFamily: isFamily,
                          isCompany: isCompany,
                          categoryId: selectedCategoryId,
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
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.savings_rounded, color: AppTheme.familyPurple, size: 24),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Nabung Bersama Keluarga',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
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
                      Expanded(
                        child: Row(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          memberName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                        ),
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
                                  Text(memberEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                                const Text('Saldo Akhir', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatRupiah(int.tryParse(snapshot.data!['total_balance']?.toString() ?? '0') ?? 0),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                                  ),
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
                                const Text('Pemasukan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatRupiah(int.tryParse(snapshot.data!['total_income']?.toString() ?? '0') ?? 0),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                                  ),
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
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatRupiah(int.tryParse(snapshot.data!['total_expense']?.toString() ?? '0') ?? 0),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
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
                        const Expanded(
                          child: Text(
                            'Riwayat Catatan Transaksi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                  const Expanded(
                    child: Text(
                      'Informasi Ruang Keluarga',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        Flexible(
                          child: Text(
                            inviteCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3.0, color: Colors.white),
                          ),
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

  Future<void> _showLogoutDialog(BuildContext context, AuthProvider auth) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.expenseRed, size: 22),
            SizedBox(width: 8),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Dompet Linc Anda?',
          style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Tidak',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      HapticFeedback.mediumImpact();
      auth.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showAdminPortalModal(BuildContext context) {
    final finance = context.read<FinanceProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<dynamic>(
          future: finance.apiClient.get(ApiConstants.adminDashboard),
          builder: (context, snapshot) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header with LiNC Company Logo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(
                          'assets/images/linc_logo.png',
                          width: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            'LiNC Admin',
                            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0038FF), fontSize: 18),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0038FF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Backend Control',
                            style: TextStyle(color: Color(0xFF0038FF), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0038FF)),
                      ),
                    )
                  else if (snapshot.hasError)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Gagal memuat portal admin: ${snapshot.error}',
                          style: const TextStyle(color: AppTheme.expenseRed, fontSize: 13),
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildAdminDashboardContent(snapshot.data as Map<String, dynamic>),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Text(
                    'Sistem by Rivaldi Rizki Alvian',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminDashboardContent(Map<String, dynamic> data) {
    final totalUsers = data['total_users'] ?? 0;
    final adminCount = data['admin_count'] ?? 0;
    final totalFamilies = data['total_families'] ?? 0;
    final totalCompanies = data['total_companies'] ?? 0;
    final totalProjects = data['total_projects'] ?? 0;
    final totalTx = data['total_transactions'] ?? 0;
    final systemBalance = int.tryParse(data['total_system_balance']?.toString() ?? '0') ?? 0;
    final savingsBalance = int.tryParse(data['total_savings_balance']?.toString() ?? '0') ?? 0;
    final activeDebts = int.tryParse(data['total_active_debts']?.toString() ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ikhtisar Global Sistem',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildAdminStatCard(
                'Total Pengguna',
                '$totalUsers Akun',
                '$adminCount Administrator',
                Icons.people_outline_rounded,
                AppTheme.iosBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAdminStatCard(
                'Keluarga & Bisnis',
                '$totalFamilies Kel • $totalCompanies PT',
                '$totalProjects Proyek Terdata',
                Icons.domain_rounded,
                const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildAdminStatCard(
                'Kas Seluruh Sistem',
                _formatRupiah(systemBalance),
                '$totalTx Mutasi Tercatat',
                Icons.account_balance_wallet_outlined,
                AppTheme.incomeGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAdminStatCard(
                'Simpanan & Hutang',
                _formatRupiah(savingsBalance),
                'Hutang: ${_formatRupiah(activeDebts)}',
                Icons.savings_outlined,
                AppTheme.warningOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.iosDivider, width: 0.8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF0038FF)),
                  SizedBox(width: 6),
                  Text(
                    'Status Sistem Terverifikasi',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Seluruh fitur CRUD Admin, manajemen data pengguna, keluarga, perusahaan, proyek, dan audit transaksi aktif.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAdminStatCard(String title, String mainValue, String subValue, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.iosDivider, width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              mainValue,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ======================= MAIN BUILD =======================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finance = context.watch<FinanceProvider>();
    final isFamily = finance.isFamilyView;
    final isCompany = finance.isCompanyView;
    final hasFamily = auth.currentUser?.familyId != null;
    final hasCompany = auth.currentUser?.companyId != null;

    final modeScheme = AppTheme.getModeScheme(finance.currentMode);
    final bgColor = modeScheme.scaffoldBg;
    final appBarBg = modeScheme.appBarBg;

    final avatarBg = modeScheme.primary.withValues(alpha: 0.14);
    final avatarColor = modeScheme.primary;
    final avatarIcon = isCompany
        ? Icons.business_rounded
        : (isFamily ? Icons.family_restroom_rounded : Icons.person_rounded);

    final headerTitle = isCompany
        ? (auth.currentCompany?.name ?? (hasCompany ? 'Ruang Perusahaan' : 'Finansial Perusahaan'))
        : (isFamily
            ? (finance.currentFamily?.name ?? (hasFamily ? 'Ruang Keluarga' : 'Finansial Keluarga'))
            : 'Halo, ${auth.currentUser?.name ?? "Pengguna"}');

    final headerSubtitle = isCompany
        ? (hasCompany
            ? 'ID: ${auth.currentCompany?.inviteCode ?? "..."} • ${finance.projects.length} Proyek'
            : 'Kelola Kas & Anggaran Proyek Tim')
        : (isFamily
            ? (hasFamily
                ? 'ID: ${finance.currentFamily?.inviteCode ?? "..."} • ${finance.familyMembers.length} Anggota'
                : 'Mulai Ruang Keuangan Bersama')
            : 'Dompet Linc • Finansial Pribadi');

    final headerSubtitleColor = modeScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _currentTab == 0
          ? AppBar(
              toolbarHeight: 56,
              backgroundColor: appBarBg,
              elevation: 0,
              titleSpacing: 12,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: avatarBg,
                    child: Icon(
                      avatarIcon,
                      size: 15,
                      color: avatarColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          headerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          headerSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: headerSubtitleColor,
                            fontWeight: (isFamily || isCompany) ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (auth.currentUser?.role == 'admin') ...[
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Admin Backend Portal',
                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFF0038FF)),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showAdminPortalModal(context);
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FamilySwitcher(),
                ),
                IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.textSecondary),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showLogoutDialog(context, auth);
                  },
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: Column(
        children: [
          if (finance.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border(bottom: BorderSide(color: Colors.amber.shade200, width: 0.8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      finance.pendingSyncCount > 0
                          ? 'Mode Offline • ${finance.pendingSyncCount} transaksi tertunda (otomatis sinkron saat online)'
                          : 'Mode Offline • Menampilkan data lokal tersimpan',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (finance.isSyncing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                    )
                  else
                    InkWell(
                      onTap: () => finance.syncPendingQueue(),
                      child: const Text(
                        'Coba Sambung',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildSummaryView(finance, auth),
                HistoryScreen(
                  isEmbedded: true,
                  onAddTransactionPressed: () => _showAddTransactionModal(isFamilyPreselected: finance.isFamilyView),
                ),
                const SavingsScreen(isEmbedded: true),
                const DebtsScreen(isEmbedded: true),
                const ChatListScreen(isEmbedded: true),
              ],
            ),
          ),
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
                _buildNavItem(
                  0,
                  isCompany
                      ? Icons.business_rounded
                      : (isFamily ? Icons.family_restroom_rounded : Icons.account_balance_wallet_rounded),
                  isCompany ? 'Perusahaan' : (isFamily ? 'Keluarga' : 'Ringkasan'),
                  () {
                    setState(() => _currentTab = 0);
                  },
                  isFamilyView: isFamily,
                  isCompanyView: isCompany,
                ),
                _buildNavItem(
                  1,
                  Icons.receipt_long_rounded,
                  isCompany ? 'Mutasi Bisnis' : (isFamily ? 'Riwayat Keluarga' : 'Riwayat'),
                  () {
                    setState(() => _currentTab = 1);
                  },
                  isFamilyView: isFamily,
                  isCompanyView: isCompany,
                ),
                _buildNavItem(
                  2,
                  isCompany ? Icons.folder_special_rounded : Icons.savings_rounded,
                  isCompany ? 'Proyek & Kas' : (isFamily ? 'Tabungan Bersama' : 'Celengan'),
                  () {
                    setState(() => _currentTab = 2);
                  },
                  isFamilyView: isFamily,
                  isCompanyView: isCompany,
                ),
                _buildNavItem(
                  3,
                  Icons.event_note_rounded,
                  isCompany ? 'Hutang Usaha' : (isFamily ? 'Hutang Keluarga' : 'Hutang'),
                  () {
                    setState(() => _currentTab = 3);
                  },
                  isFamilyView: isFamily,
                  isCompanyView: isCompany,
                ),
                _buildNavItem(
                  4,
                  Icons.chat_bubble_outline_rounded,
                  'Pesan',
                  () {
                    setState(() => _currentTab = 4);
                  },
                  isFamilyView: isFamily,
                  isCompanyView: isCompany,
                  badgeCount: context.watch<ChatProvider>().totalUnreadCount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/linc_logo.png',
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 6),
            Text(
              'Sistem by Rivaldi Rizki Alvian',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: AppTheme.textSecondary.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardDebtReminderBanner(FinanceProvider finance, String currentScope) {
    final reminders = finance.debtReminders.where((r) {
      if (currentScope == 'company') {
        return r.scope == 'company' || r.companyId != null;
      } else if (currentScope == 'family') {
        return r.scope == 'family' || r.familyId != null;
      } else {
        return r.scope == 'personal' || (r.familyId == null && r.companyId == null);
      }
    }).toList();

    if (reminders.isEmpty) return const SizedBox.shrink();

    final hasOverdue = reminders.any((r) => r.isOverdue || r.urgency == 'high');
    final bg = hasOverdue ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB);
    final border = hasOverdue ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A);
    final accent = hasOverdue ? const Color(0xFFE11D48) : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.notifications_active_rounded, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasOverdue ? 'Tagihan Hutang Jatuh Tempo!' : 'Pengingat Tagihan Hutang',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                ),
                const SizedBox(height: 1),
                Text(
                  reminders.first.reminderMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasOverdue ? const Color(0xFF881337) : const Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _currentTab = 3);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Cek',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView(FinanceProvider finance, AuthProvider auth) {
    if (finance.isCompanyView) {
      final hasCompany = auth.currentUser?.companyId != null;
      if (!hasCompany) {
        return _buildCompanyOnboardingView(finance, auth);
      }
      return _buildCompanyDashboardView(finance, auth);
    }

    if (finance.isFamilyView) {
      final hasFamily = auth.currentUser?.familyId != null;
      if (!hasFamily) {
        return _buildFamilyOnboardingView(finance, auth);
      }
      return _buildFamilyDashboardView(finance, auth);
    }

    return _buildPersonalDashboardView(finance, auth);
  }

  // ======================= VIEW 1: PERSONAL DASHBOARD =======================
  Widget _buildPersonalDashboardView(FinanceProvider finance, AuthProvider auth) {
    final modeScheme = AppTheme.getModeScheme(AppViewMode.personal);
    return RefreshIndicator(
      onRefresh: () => finance.fetchDashboard(),
      color: modeScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDashboardDebtReminderBanner(finance, 'personal'),
            // DANA Vibrant Cyan-Blue Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: modeScheme.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: modeScheme.heroCardShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
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
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              'KAS PRIBADI',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${finance.wallets.length} Akun aktif',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Total Saldo Saya',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isBalanceVisible ? _formatRupiah(finance.totalBalance) : '••••••••',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showAddTransactionModal(isFamilyPreselected: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 5),
                                Text('Catat', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentTab = 2);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.savings_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 5),
                                Text('Celengan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentTab = 3);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_note_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 5),
                                Text('Hutang', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
            const SizedBox(height: 16),

            // Cashflow Group (Pemasukan & Pengeluaran)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.incomeGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_downward_rounded, size: 14, color: AppTheme.incomeGreen),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pemasukan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatRupiah(finance.totalIncome),
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 0.8, height: 30, color: AppTheme.iosDivider),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.expenseRed.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.expenseRed),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pengeluaran', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatRupiah(finance.totalExpense),
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
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
            ),
            const SizedBox(height: 18),

            // Dompet Saya Section (Apple Wallet horizontal cards)
            if (finance.wallets.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dompet Saya',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${finance.wallets.length} Akun',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: finance.wallets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final wallet = finance.wallets[i];
                    return Container(
                      width: 124,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, size: 12, color: AppTheme.iosBlue),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  wallet.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _formatRupiah(wallet.balance),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Analisis Pengeluaran per Kategori
            _buildCategoryExpenseAnalysis(finance.transactions, isFamily: false),

            // Transaksi Terbaru
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaksi Pribadi Terbaru',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _currentTab = 1);
                    },
                    child: const Row(
                      children: [
                        Text('Lihat Semua', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.iosBlue)),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.iosBlue),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            _buildTransactionList(finance.transactions),
            const SizedBox(height: 12),
            _buildBrandFooter(),
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
    final totalSharedSavings = sharedSavings.fold<int>(0, (sum, s) => sum + s.currentAmount);

    // Transactions filtered by selected member if any
    final displayedTransactions = _selectedMemberFilterId == null
        ? finance.transactions
        : finance.transactions.where((t) => t.userId == _selectedMemberFilterId).toList();

    final modeScheme = AppTheme.getModeScheme(AppViewMode.family);
    return RefreshIndicator(
      onRefresh: () => finance.fetchDashboard(),
      color: modeScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDashboardDebtReminderBanner(finance, 'family'),
            // ShopeePay Sunset-Orange Family Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: modeScheme.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: modeScheme.heroCardShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
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
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.family_restroom_rounded, size: 11, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'RUANG KELUARGA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tabungan Bersama Terkumpul
                  Text(
                    'Total Celengan Bersama Terkumpul',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isBalanceVisible ? _formatRupiah(totalSharedSavings) : '••••••••',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sharedSavings.length} target celengan aktif',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Inline ID Undangan Bar (1-Tap Copy)
                  GestureDetector(
                    onTap: () => _copyToClipboard(inviteCode, 'ID Keluarga $inviteCode disalin!'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.vpn_key_rounded, size: 13, color: Colors.amberAccent),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'ID KELUARGA: $inviteCode',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Row(
                            children: [
                              Text('Salin', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                              SizedBox(width: 3),
                              Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3 Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showDepositToSharedSavingModal(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.savings_rounded, size: 16, color: Colors.amberAccent),
                                SizedBox(height: 3),
                                Text(
                                  'Nabung',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 16, color: Colors.white),
                                SizedBox(height: 3),
                                Text(
                                  '+ Catat',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                                SizedBox(height: 3),
                                Text(
                                  'Undang',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
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
            const SizedBox(height: 18),

            // 2. FITUR UTAMA 1: CELENGAN BERSAMA (SHARED SAVINGS)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.savings_rounded, size: 20, color: AppTheme.familyPurple),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Celengan Bersama',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                            Expanded(
                              child: Row(
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          saving.goalName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                        ),
                                        Text(
                                          'Target: ${_formatRupiah(saving.targetAmount)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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
                            Expanded(
                              child: Text(
                                'Terkumpul: ${_formatRupiah(saving.currentAmount)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan Keuangan Anggota',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ketuk anggota untuk inspeksi catatan & saldo akhirnya',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_selectedMemberFilterId != null) ...[
                  const SizedBox(width: 8),
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
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Member Selector
            SizedBox(
              height: 98,
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
                        width: 92,
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
                            Icon(Icons.groups_rounded, size: 22, color: isAll ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(height: 4),
                            Text(
                              'Semua',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isAll ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${finance.familyMembers.length} Anggota',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isAll ? Colors.white.withValues(alpha: 0.8) : AppTheme.textSecondary,
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
                  final totalBalance = int.tryParse(member['total_balance']?.toString() ?? '0') ?? 0;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedMemberFilterId = memberId);
                      _showMemberInspectionModal(member);
                    },
                    child: Container(
                      width: 102,
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
                            radius: 15,
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
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatRupiah(totalBalance),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppTheme.familyPurple : AppTheme.textSecondary,
                              ),
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

            // Analisis Pengeluaran per Kategori Keluarga
            _buildCategoryExpenseAnalysis(displayedTransactions, isFamily: true),

            // 5. FITUR UTAMA 3: AKTIVITAS KEUANGAN BERSAMA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Aktivitas Keuangan Keluarga',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
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
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _currentTab = 1);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 12),
            _buildBrandFooter(),
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
          // Onboarding Hero Card (ShopeePay Sunset Orange)
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEE4D2D), Color(0xFFFF6633)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEE4D2D).withValues(alpha: 0.3),
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

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  // ======================= HELPER: ANALISIS PENGELUARAN PER KATEGORI =======================
  Widget _buildCategoryExpenseAnalysis(List<TransactionModel> transactions, {bool isFamily = false}) {
    final expenseTxs = transactions.where((t) => t.type == 'expense').toList();
    if (expenseTxs.isEmpty) return const SizedBox.shrink();

    final Map<String, int> catAmounts = {};
    final Map<String, Color> catColors = {};
    final Map<String, IconData> catIcons = {};
    int totalExpense = 0;

    for (final tx in expenseTxs) {
      final name = tx.categoryName ?? 'Lain-lain';
      final color = tx.categoryColor != null ? _parseHexColor(tx.categoryColor!) : const Color(0xFFEF4444);
      final icon = tx.categoryIcon != null
          ? CategoryModel(id: 0, name: name, type: 'expense', color: '', icon: tx.categoryIcon!).iconData
          : Icons.category_rounded;

      catAmounts[name] = (catAmounts[name] ?? 0) + tx.amount;
      catColors[name] = color;
      catIcons[name] = icon;
      totalExpense += tx.amount;
    }

    if (totalExpense <= 0) return const SizedBox.shrink();

    final sortedEntries = catAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final accentColor = isFamily ? const Color(0xFFEE4D2D) : const Color(0xFF118EEA);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFamily ? const Color(0xFFEDE9FE) : AppTheme.iosDivider,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.donut_large_rounded, size: 16, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFamily ? 'Analisis Pengeluaran Keluarga' : 'Analisis Pengeluaran per Kategori',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Text(
                _formatRupiah(totalExpense),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.expenseRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Multi-color segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: sortedEntries.map((e) {
                  final pct = (e.value / totalExpense).clamp(0.01, 1.0);
                  return Expanded(
                    flex: (pct * 100).round().clamp(1, 100),
                    child: Container(
                      color: catColors[e.key] ?? AppTheme.expenseRed,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category items
          Column(
            children: sortedEntries.take(4).map((e) {
              final pct = ((e.value / totalExpense) * 100).toStringAsFixed(1);
              final col = catColors[e.key] ?? AppTheme.expenseRed;
              final icon = catIcons[e.key] ?? Icons.category_rounded;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 13, color: col),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%  ',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      _formatRupiah(e.value),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
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
                            if (tx.categoryName != null) ...[
                              const Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (tx.categoryColor != null
                                            ? _parseHexColor(tx.categoryColor!)
                                            : const Color(0xFF10B981))
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    tx.categoryName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: tx.categoryColor != null
                                          ? _parseHexColor(tx.categoryColor!)
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (isFamilyMode && tx.userName != null) ...[
                              const Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'Oleh ${tx.userName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                                  ),
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
  Widget _buildNavItem(int index, IconData icon, String label, VoidCallback onTap, {bool isFamilyView = false, bool isCompanyView = false, int badgeCount = 0}) {
    final isSelected = _currentTab == index;
    final activeColor = isCompanyView
        ? const Color(0xFF1C1C1E)
        : (isFamilyView ? const Color(0xFFEE4D2D) : const Color(0xFF118EEA));

    Widget iconWidget = Icon(
      icon,
      size: 21,
      color: isSelected ? activeColor : AppTheme.textSecondary,
    );

    if (badgeCount > 0) {
      iconWidget = Badge.count(
        count: badgeCount,
        backgroundColor: const Color(0xFFFF3B30),
        child: iconWidget,
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? activeColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================= VIEW 4: ONBOARDING RUANG PERUSAHAAN =======================
  Widget _buildCompanyOnboardingView(FinanceProvider finance, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Onboarding Hero Card (Obsidian Executive Titanium)
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF38383A), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
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
                  child: const Icon(Icons.business_center_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ruang Perusahaan & Proyek',
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
                  'Kelola anggaran proyek, kolaborasi kas masuk dan keluar secara transparan bersama seluruh tim.',
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
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildFeatureRow(Icons.folder_special_rounded, 'Multi-Proyek Terpisah', 'Kelola anggaran dan pantau realisasi pemasukan serta pengeluaran per proyek.', const Color(0xFF1C1C1E)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, indent: 40, color: Color(0xFFF1F5F9)),
                ),
                _buildFeatureRow(Icons.account_balance_wallet_rounded, 'Kas Terintegrasi', 'Catat pembayaran termin klien dan belanja kebutuhan proyek langsung dari rekening terpilih.', AppTheme.incomeGreen),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, indent: 40, color: Color(0xFFF1F5F9)),
                ),
                _buildFeatureRow(Icons.groups_rounded, 'Kolaborasi Anggota Tim', 'Setiap anggota tim yang bergabung dapat mencatat dan melihat histori mutasi proyek.', AppTheme.iosBlue),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Segmented Switcher Buat vs Gabung
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _onboardingCompanyTab = 0;
                        _onboardingCompanyError = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _onboardingCompanyTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _onboardingCompanyTab == 0
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
                        'Buat Perusahaan Baru',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _onboardingCompanyTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _onboardingCompanyTab == 0 ? const Color(0xFF1C1C1E) : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _onboardingCompanyTab = 1;
                        _onboardingCompanyError = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _onboardingCompanyTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _onboardingCompanyTab == 1
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
                          fontWeight: _onboardingCompanyTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _onboardingCompanyTab == 1 ? const Color(0xFF1C1C1E) : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_onboardingCompanyError != null)
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
                    child: Text(_onboardingCompanyError!, style: const TextStyle(color: AppTheme.expenseRed, fontSize: 13)),
                  ),
                ],
              ),
            ),

          if (_onboardingCompanyTab == 0) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _onboardingCompanyNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nama Perusahaan (contoh: PT Solusi Jaya)',
                  prefixIcon: Icon(Icons.business_outlined, color: Color(0xFF1C1C1E)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isOnboardingCompanyLoading
                  ? null
                  : () async {
                      final name = _onboardingCompanyNameController.text.trim();
                      if (name.isEmpty) {
                        setState(() => _onboardingCompanyError = 'Harap isi nama perusahaan');
                        return;
                      }

                      setState(() {
                        _isOnboardingCompanyLoading = true;
                        _onboardingCompanyError = null;
                      });

                      final result = await auth.createCompany(name);
                      if (result != null && mounted) {
                        await finance.fetchDashboard();
                        setState(() => _isOnboardingCompanyLoading = false);
                        _copyToClipboard(result['invite_code'].toString(), 'Perusahaan dibuat! Kode Tim: ${result['invite_code']}');
                      } else if (mounted) {
                        setState(() {
                          _isOnboardingCompanyLoading = false;
                          _onboardingCompanyError = auth.errorMessage ?? 'Gagal membuat perusahaan';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isOnboardingCompanyLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Buat Ruang Perusahaan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _onboardingCompanyCodeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                decoration: const InputDecoration(
                  hintText: '8 Karakter Kode ID Perusahaan',
                  prefixIcon: Icon(Icons.vpn_key_rounded, color: Color(0xFF1C1C1E)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isOnboardingCompanyLoading
                  ? null
                  : () async {
                      final code = _onboardingCompanyCodeController.text.trim().toUpperCase();
                      if (code.isEmpty) {
                        setState(() => _onboardingCompanyError = 'Harap isi kode ID');
                        return;
                      }

                      setState(() {
                        _isOnboardingCompanyLoading = true;
                        _onboardingCompanyError = null;
                      });

                      final success = await auth.joinCompany(code);
                      if (success && mounted) {
                        await finance.fetchDashboard();
                        setState(() => _isOnboardingCompanyLoading = false);
                      } else if (mounted) {
                        setState(() {
                          _isOnboardingCompanyLoading = false;
                          _onboardingCompanyError = auth.errorMessage ?? 'Kode ID tidak valid';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isOnboardingCompanyLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gabung ke Perusahaan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ======================= VIEW 5: PERUSAHAAN & PROYEK DASHBOARD =======================
  Widget _buildCompanyDashboardView(FinanceProvider finance, AuthProvider auth) {
    final company = auth.currentCompany;
    final inviteCode = company?.inviteCode ?? '--------';
    final projects = finance.projects;

    final totalBudget = projects.fold<int>(0, (sum, p) => sum + p.targetBudget);
    final totalIncome = projects.fold<int>(0, (sum, p) => sum + p.currentIncome);
    final totalExpense = projects.fold<int>(0, (sum, p) => sum + p.currentExpense);
    final netProfit = totalIncome - totalExpense;

    final modeScheme = AppTheme.getModeScheme(AppViewMode.company);
    return RefreshIndicator(
      onRefresh: () async {
        await finance.fetchDashboard();
        await auth.getCurrentCompany();
      },
      color: modeScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDashboardDebtReminderBanner(finance, 'company'),
            // Obsidian Titanium Carbon Hero Card (Executive Dark)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: modeScheme.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF38383A), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.business_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'RUANG PERUSAHAAN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${auth.companyMembers.isNotEmpty ? auth.companyMembers.length : 1} Anggota',
                          style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    company?.name ?? 'Perusahaan Saya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Invite Code Pill
                  Row(
                    children: [
                      const Text(
                        'KODE TIM: ',
                        style: TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        inviteCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _copyToClipboard(inviteCode, 'Kode tim $inviteCode disalin!'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text('Salin', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCreateProjectModal(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.add_task_rounded, size: 16, color: Color(0xFF1C1C1E)),
                                SizedBox(height: 3),
                                Text(
                                  '+ Proyek Baru',
                                  style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showRecordProjectCashflowModal(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.post_add_rounded, size: 16, color: Colors.white),
                                SizedBox(height: 3),
                                Text(
                                  'Catat Kas Proyek',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _copyToClipboard(inviteCode, 'Kode tim $inviteCode disalin!'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                                SizedBox(height: 3),
                                Text(
                                  'Undang Tim',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
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
            const SizedBox(height: 18),

            // 2. RINGKASAN METRIK FINANSIAL PROYEK
            const Text(
              'Ringkasan Proyek Perusahaan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.flag_rounded, size: 13, color: Color(0xFF1C1C1E)),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Target Anggaran',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formatRupiah(totalBudget),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: netProfit >= 0 ? AppTheme.incomeGreen.withValues(alpha: 0.12) : AppTheme.expenseRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                netProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                size: 13,
                                color: netProfit >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Laba / Margin',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${netProfit >= 0 ? "+" : ""}${_formatRupiah(netProfit)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: netProfit >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.incomeGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.arrow_downward_rounded, size: 13, color: AppTheme.incomeGreen),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Kas Masuk Proyek',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+ ${_formatRupiah(totalIncome)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.incomeGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.expenseRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.arrow_upward_rounded, size: 13, color: AppTheme.expenseRed),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Biaya Proyek',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '- ${_formatRupiah(totalExpense)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.expenseRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2b. SUB-TAB NAVIGATOR RUANG PERUSAHAAN
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCompanySubTabChip(0, 'Proyek', Icons.folder_copy_rounded),
                  const SizedBox(width: 8),
                  _buildCompanySubTabChip(1, 'Arus Kas', Icons.account_balance_wallet_rounded),
                  const SizedBox(width: 8),
                  _buildCompanySubTabChip(2, 'Outstanding', Icons.receipt_long_rounded),
                  const SizedBox(width: 8),
                  _buildCompanySubTabChip(3, 'Modal (Hutang)', Icons.handshake_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_companySubTab == 1) ...[
              _buildCompanyCashflowLedgerSection(finance),
            ] else if (_companySubTab == 2) ...[
              _buildCompanyOutstandingProjectsSection(finance),
            ] else if (_companySubTab == 3) ...[
              _buildCompanyCapitalInvestmentsSection(finance),
            ] else ...[
            // 3. DAFTAR PROYEK PERUSAHAAN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.folder_copy_rounded, size: 18, color: Color(0xFF1C1C1E)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Daftar Proyek (${projects.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showCreateProjectModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 13, color: Color(0xFF1C1C1E)),
                        SizedBox(width: 3),
                        Text(
                          'Proyek Baru',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (projects.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.folder_open_rounded, color: Color(0xFF1C1C1E), size: 30),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum Ada Proyek',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Buat proyek pertama Anda untuk mulai mencatat arus kas, pemasukan dari klien, dan pengeluaran operasional.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateProjectModal(context),
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Buat Proyek Pertama', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final project = projects[idx];
                  final isPositiveProfit = project.netProfit >= 0;

                  Color statusColor = const Color(0xFF1C1C1E);
                  String statusLabel = 'Aktif';
                  if (project.status == 'completed') {
                    statusColor = AppTheme.incomeGreen;
                    statusLabel = 'Selesai';
                  } else if (project.status == 'on_hold') {
                    statusColor = const Color(0xFFF59E0B);
                    statusLabel = 'Ditunda';
                  }

                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (project.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            project.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.3),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Progress Bar Target Anggaran
                        if (project.targetBudget > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Anggaran: ${_formatRupiah(project.targetBudget)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${project.budgetProgress}% Terpakai',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: project.budgetProgress > 100 ? AppTheme.expenseRed : const Color(0xFF1C1C1E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: (project.budgetProgress / 100).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                project.budgetProgress > 100 ? AppTheme.expenseRed : const Color(0xFF1C1C1E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Income / Expense / Profit Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Masuk', style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 1),
                                  Text(
                                    '+${_formatRupiah(project.currentIncome)}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Biaya', style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 1),
                                  Text(
                                    '-${_formatRupiah(project.currentExpense)}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Laba Bersih', style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${isPositiveProfit ? "+" : ""}${_formatRupiah(project.netProfit)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isPositiveProfit ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Actions Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showRecordProjectCashflowModal(context, preselectedProject: project),
                                icon: const Icon(Icons.post_add_rounded, size: 14),
                                label: const Text('Catat Kas', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1C1C1E),
                                  side: const BorderSide(color: Color(0xFF1C1C1E), width: 0.8),
                                  minimumSize: const Size(0, 34),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showProjectDetailModal(context, project),
                                icon: const Icon(Icons.receipt_long_rounded, size: 14),
                                label: const Text('Detail & Mutasi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1C1C1E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size(0, 34),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ], // end if (_companySubTab == 0)
            const SizedBox(height: 12),
            _buildBrandFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySubTabChip(int index, String label, IconData icon) {
    final isSelected = _companySubTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _companySubTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================= SECTION: CATATAN ARUS KAS PERUSAHAAN =======================
  Widget _buildCompanyCashflowLedgerSection(FinanceProvider finance) {
    final summary = finance.companyCashflowSummary;
    final entries = finance.companyCashflowEntries;
    final totalIn = int.tryParse(summary['total_cash_in']?.toString() ?? '0') ?? 0;
    final totalOut = int.tryParse(summary['total_cash_out']?.toString() ?? '0') ?? 0;
    final finalBal = int.tryParse(summary['final_balance']?.toString() ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF1C1C1E)),
            SizedBox(width: 6),
            Text(
              'Catatan Arus Kas Perusahaan',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMiniKpiTile('Total Kas Masuk', '+ ${_formatRupiah(totalIn)}', AppTheme.incomeGreen),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniKpiTile('Total Kas Keluar', '- ${_formatRupiah(totalOut)}', AppTheme.expenseRed),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniKpiTile('Balance Akhir', _formatRupiah(finalBal), const Color(0xFF1C1C1E)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          _buildEmptyReportBox('Belum ada mutasi arus kas perusahaan.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 58,
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('No', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('No Invoice / Nama Project', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Deskripsi (Kegiatan)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Kas Masuk', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('Kas Keluar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('Balance', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                ],
                rows: entries.map((e) {
                  final rowNo = e['row_number']?.toString() ?? '-';
                  final invProj = e['invoice_or_project']?.toString() ?? 'Operasional Umum';
                  final desc = e['description']?.toString() ?? '-';
                  final cashIn = int.tryParse(e['cash_in']?.toString() ?? '0') ?? 0;
                  final cashOut = int.tryParse(e['cash_out']?.toString() ?? '0') ?? 0;
                  final bal = int.tryParse(e['balance']?.toString() ?? '0') ?? 0;

                  return DataRow(cells: [
                    DataCell(Text(rowNo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(invProj, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    )),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                    )),
                    DataCell(Text(
                      cashIn > 0 ? '+${_formatRupiah(cashIn)}' : '-',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cashIn > 0 ? AppTheme.incomeGreen : AppTheme.textSecondary),
                    )),
                    DataCell(Text(
                      cashOut > 0 ? '-${_formatRupiah(cashOut)}' : '-',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cashOut > 0 ? AppTheme.expenseRed : AppTheme.textSecondary),
                    )),
                    DataCell(Text(
                      _formatRupiah(bal),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: bal >= 0 ? const Color(0xFF1C1C1E) : AppTheme.expenseRed),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ======================= SECTION: OUTSTANDING PROJECT =======================
  Widget _buildCompanyOutstandingProjectsSection(FinanceProvider finance) {
    final summary = finance.outstandingSummary;
    final items = finance.outstandingProjects;
    final totalBilling = int.tryParse(summary['total_billing']?.toString() ?? '0') ?? 0;
    final totalNetto = int.tryParse(summary['total_netto']?.toString() ?? '0') ?? 0;
    final totalUnpaid = int.tryParse(summary['total_unpaid_netto']?.toString() ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF1C1C1E)),
                SizedBox(width: 6),
                Text(
                  'Outstanding Project',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showCreateProjectModal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(8)),
                child: const Text('+ Tagihan Proyek', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMiniKpiTile('Total Tagihan', _formatRupiah(totalBilling), const Color(0xFF1C1C1E))),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniKpiTile('Total Netto', _formatRupiah(totalNetto), AppTheme.incomeGreen)),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniKpiTile('Belum Lunas', _formatRupiah(totalUnpaid), AppTheme.expenseRed)),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _buildEmptyReportBox('Belum ada data proyek & tagihan.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 62,
                columnSpacing: 14,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('No', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('No Invoice & Nama Project', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Deskripsi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Nilai Tagihan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('Fee Mgmt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('PPN', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('PPh', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('Netto', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('Keterangan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Aksi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                ],
                rows: items.map((item) {
                  final id = item['id'] as int;
                  final rowNo = item['row_number']?.toString() ?? '-';
                  final invName = item['invoice_and_name']?.toString() ?? '-';
                  final desc = item['description']?.toString() ?? '-';
                  final billing = int.tryParse(item['billing_amount']?.toString() ?? '0') ?? 0;
                  final fee = int.tryParse(item['fee_management']?.toString() ?? '0') ?? 0;
                  final ppn = int.tryParse(item['ppn_amount']?.toString() ?? '0') ?? 0;
                  final pph = int.tryParse(item['pph_amount']?.toString() ?? '0') ?? 0;
                  final netto = int.tryParse(item['netto_amount']?.toString() ?? '0') ?? 0;
                  final isPaid = item['payment_status'] == 'paid';

                  return DataRow(cells: [
                    DataCell(Text(rowNo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(invName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    )),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                    )),
                    DataCell(Text(_formatRupiah(billing), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                    DataCell(Text(_formatRupiah(fee), style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary))),
                    DataCell(Text(_formatRupiah(ppn), style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary))),
                    DataCell(Text(_formatRupiah(pph), style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary))),
                    DataCell(Text(_formatRupiah(netto), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.incomeGreen))),
                    DataCell(
                      GestureDetector(
                        onTap: () async {
                          final nextStatus = isPaid ? 'unpaid' : 'paid';
                          await finance.updateProjectPaymentStatus(id, nextStatus);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPaid ? AppTheme.incomeGreen.withValues(alpha: 0.14) : AppTheme.expenseRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPaid ? 'Lunas' : 'Belum Lunas',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isPaid ? AppTheme.incomeGreen : AppTheme.expenseRed,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF1C1C1E)),
                        tooltip: 'Edit Tagihan',
                        onPressed: () {
                          final proj = finance.projects.firstWhere((p) => p.id == id);
                          _showEditProjectBillingModal(context, proj);
                        },
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ======================= SECTION: RINCIAN PENANAMAN MODAL (HUTANG) =======================
  Widget _buildCompanyCapitalInvestmentsSection(FinanceProvider finance) {
    final summary = finance.capitalSummary;
    final items = finance.capitalInvestments;
    final totalTransferred = int.tryParse(summary['total_capital_transferred']?.toString() ?? '0') ?? 0;
    final totalRemaining = int.tryParse(summary['total_capital_remaining']?.toString() ?? '0') ?? 0;
    final totalRepaid = int.tryParse(summary['total_capital_repaid']?.toString() ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.handshake_rounded, size: 18, color: Color(0xFF1C1C1E)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Rincian Penanaman Modal (Hutang)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showCreateCapitalInvestmentModal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(8)),
                child: const Text('+ Modal Baru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMiniKpiTile('Total Modal Masuk', _formatRupiah(totalTransferred), const Color(0xFF1C1C1E))),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniKpiTile('Sudah Dikembalikan', _formatRupiah(totalRepaid), AppTheme.incomeGreen)),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniKpiTile('Sisa Hutang Modal', _formatRupiah(totalRemaining), AppTheme.expenseRed)),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _buildEmptyReportBox('Belum ada catatan penanaman modal / hutang perusahaan.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 60,
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('No', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Deskripsi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Tgl Terbit Invoice', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Total Modal Ditransfer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)), numeric: true),
                  DataColumn(label: Text('Deadline Pengembalian', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Sisa & Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                ],
                rows: items.map((item) {
                  final rowNo = item['row_number']?.toString() ?? '-';
                  final desc = item['description']?.toString() ?? '-';
                  final invDate = item['invoice_date']?.toString().split('T')[0] ?? '-';
                  final total = int.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
                  final remaining = int.tryParse(item['remaining_amount']?.toString() ?? '0') ?? 0;
                  final dueDate = item['due_date']?.toString().split('T')[0] ?? '-';
                  final status = item['computed_status']?.toString() ?? 'unpaid';
                  final isPaid = status == 'paid' || remaining <= 0;

                  return DataRow(cells: [
                    DataCell(Text(rowNo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    )),
                    DataCell(Text(invDate, style: const TextStyle(fontSize: 11.5))),
                    DataCell(Text(_formatRupiah(total), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                    DataCell(Text(dueDate, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: status == 'overdue' ? AppTheme.expenseRed : AppTheme.textPrimary))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid ? AppTheme.incomeGreen.withValues(alpha: 0.14) : AppTheme.expenseRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPaid ? 'Lunas' : 'Sisa ${_formatRupiah(remaining)}',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isPaid ? AppTheme.incomeGreen : AppTheme.expenseRed),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMiniKpiTile(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReportBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
      ),
    );
  }

  // ======================= MODAL: BUAT / EDIT PROYEK & TAGIHAN =======================
  void _showCreateProjectModal(BuildContext context) {
    _showProjectFormModal(context);
  }

  void _showEditProjectBillingModal(BuildContext context, ProjectModel project) {
    _showProjectFormModal(context, existing: project);
  }

  void _showProjectFormModal(BuildContext context, {ProjectModel? existing}) {
    final isEdit = existing != null;
    final invoiceCtrl = TextEditingController(text: existing?.invoiceNumber ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final budgetCtrl = TextEditingController(text: (existing?.targetBudget ?? 0) > 0 ? existing!.targetBudget.toString() : '');
    final billingCtrl = TextEditingController(text: (existing?.billingAmount ?? 0) > 0 ? existing!.billingAmount.toString() : '');
    final feePctCtrl = TextEditingController(text: (existing?.feeManagementPercent ?? 0) > 0 ? existing!.feeManagementPercent.toString() : '');
    final ppnPctCtrl = TextEditingController(text: (existing?.ppnPercent ?? 0) > 0 ? existing!.ppnPercent.toString() : '');
    final pphPctCtrl = TextEditingController(text: (existing?.pphPercent ?? 0) > 0 ? existing!.pphPercent.toString() : '');
    String paymentStatus = existing?.paymentStatus ?? 'unpaid';
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final billingVal = int.tryParse(billingCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final feePct = double.tryParse(feePctCtrl.text.replaceAll(',', '.')) ?? 0;
          final ppnPct = double.tryParse(ppnPctCtrl.text.replaceAll(',', '.')) ?? 0;
          final pphPct = double.tryParse(pphPctCtrl.text.replaceAll(',', '.')) ?? 0;
          final feeVal = ((billingVal * feePct) / 100).round();
          final ppnVal = ((billingVal * ppnPct) / 100).round();
          final pphVal = ((billingVal * pphPct) / 100).round();
          final nettoPreview = (billingVal - feeVal - ppnVal - pphVal).clamp(0, billingVal);

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Proyek & Tagihan' : 'Buat Proyek Baru',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.expenseRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.25), width: 0.8),
                      ),
                      child: Text(errorText!, style: const TextStyle(color: AppTheme.expenseRed, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],

                  _buildCompactInput(invoiceCtrl, 'No. Invoice (contoh: INV/2026/001)', Icons.confirmation_number_outlined),
                  const SizedBox(height: 10),
                  _buildCompactInput(nameCtrl, 'Nama Proyek *', Icons.folder_outlined),
                  const SizedBox(height: 10),
                  _buildCompactInput(descCtrl, 'Deskripsi kegiatan / proyek (opsional)', Icons.notes_rounded, maxLines: 2),
                  const SizedBox(height: 10),
                  _buildCompactInput(budgetCtrl, 'Target Anggaran / Budget (Rp)', Icons.account_balance_wallet_outlined, isNumber: true),
                  const SizedBox(height: 10),
                  _buildCompactInput(
                    billingCtrl,
                    'Nilai Tagihan Outstanding (Rp)',
                    Icons.request_quote_outlined,
                    isNumber: true,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactInput(
                          feePctCtrl,
                          'Fee Mgmt (%)',
                          Icons.percent_rounded,
                          isNumber: true,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactInput(
                          ppnPctCtrl,
                          'PPN (%)',
                          Icons.percent_rounded,
                          isNumber: true,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactInput(
                          pphPctCtrl,
                          'PPh (%)',
                          Icons.percent_rounded,
                          isNumber: true,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (billingVal > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Potongan Fee / PPN / PPh:', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                              Text('- ${_formatRupiah(feeVal + ppnVal + pphVal)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.expenseRed)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Estimasi Netto Diterima:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              Text(_formatRupiah(nettoPreview), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.incomeGreen)),
                            ],
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      const Text('Status Pelunasan:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('Belum Lunas', style: TextStyle(fontSize: 11.5)),
                        selected: paymentStatus == 'unpaid',
                        onSelected: (_) => setModalState(() => paymentStatus = 'unpaid'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Lunas', style: TextStyle(fontSize: 11.5)),
                        selected: paymentStatus == 'paid',
                        onSelected: (_) => setModalState(() => paymentStatus = 'paid'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setModalState(() => errorText = 'Nama proyek tidak boleh kosong');
                              return;
                            }
                            final budget = int.tryParse(budgetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

                            setModalState(() {
                              isSaving = true;
                              errorText = null;
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            final finance = context.read<FinanceProvider>();
                            final bool success;
                            if (isEdit) {
                              success = await finance.updateProject(existing.id, {
                                'invoice_number': invoiceCtrl.text.trim().isNotEmpty ? invoiceCtrl.text.trim() : null,
                                'name': name,
                                'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                                'target_budget': budget,
                                'billing_amount': billingVal,
                                'fee_management_percent': feePct,
                                'ppn_percent': ppnPct,
                                'pph_percent': pphPct,
                                'payment_status': paymentStatus,
                              });
                            } else {
                              success = await finance.createProject(
                                invoiceNumber: invoiceCtrl.text.trim().isNotEmpty ? invoiceCtrl.text.trim() : null,
                                name: name,
                                description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                                targetBudget: budget,
                                billingAmount: billingVal,
                                feeManagementPercent: feePct,
                                ppnPercent: ppnPct,
                                pphPercent: pphPct,
                                paymentStatus: paymentStatus,
                              );
                            }

                            if (success && mounted) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Proyek "$name" diperbarui!' : 'Proyek "$name" berhasil dibuat!'),
                                  backgroundColor: const Color(0xFF1C1C1E),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (mounted) {
                              setModalState(() {
                                isSaving = false;
                                errorText = finance.errorMessage ?? 'Gagal menyimpan proyek';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'Simpan Perubahan' : 'Simpan Proyek', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactInput(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.iosBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.iosDivider, width: 0.8),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
          prefixIcon: Icon(icon, size: 17, color: const Color(0xFF1C1C1E)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    );
  }

  // ======================= MODAL: TAMBAH PENANAMAN MODAL (HUTANG) =======================
  void _showCreateCapitalInvestmentModal(BuildContext context) {
    final investorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final invoiceDateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final dueDateCtrl = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0]);
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Catat Penanaman Modal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(errorText!, style: const TextStyle(color: AppTheme.expenseRed, fontSize: 12)),
                    ),
                  _buildCompactInput(investorCtrl, 'Sumber Modal / Nama Investor *', Icons.person_outline_rounded),
                  const SizedBox(height: 10),
                  _buildCompactInput(descCtrl, 'Deskripsi Penanaman Modal *', Icons.description_outlined),
                  const SizedBox(height: 10),
                  _buildCompactInput(amountCtrl, 'Total Modal yang di Transfer (Rp) *', Icons.attach_money_rounded, isNumber: true),
                  const SizedBox(height: 10),
                  _buildCompactInput(invoiceDateCtrl, 'Tanggal Terbit Invoice (YYYY-MM-DD)', Icons.date_range_rounded),
                  const SizedBox(height: 10),
                  _buildCompactInput(dueDateCtrl, 'Deadline Pengembalian (YYYY-MM-DD) *', Icons.event_available_rounded),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final investor = investorCtrl.text.trim();
                            final amount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                            final due = dueDateCtrl.text.trim();
                            if (investor.isEmpty || amount <= 0 || due.isEmpty) {
                              setModalState(() => errorText = 'Sumber modal, nominal, dan deadline wajib diisi');
                              return;
                            }
                            setModalState(() {
                              isSaving = true;
                              errorText = null;
                            });
                            final finance = context.read<FinanceProvider>();
                            final ok = await finance.createDebt(
                              type: 'payable',
                              personName: investor,
                              amount: amount,
                              dueDate: due,
                              notes: descCtrl.text.trim(),
                              scope: 'company',
                              invoiceDate: invoiceDateCtrl.text.trim(),
                            );
                            if (ok && mounted) {
                              if (ctx.mounted) Navigator.pop(ctx);
                            } else if (mounted) {
                              setModalState(() {
                                isSaving = false;
                                errorText = finance.errorMessage ?? 'Gagal mencatat penanaman modal';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Penanaman Modal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================= MODAL: CATAT KAS PROYEK =======================
  void _showRecordProjectCashflowModal(BuildContext context, {ProjectModel? preselectedProject}) {
    final finance = context.read<FinanceProvider>();
    if (finance.projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buat proyek terlebih dahulu sebelum mencatat kas proyek.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _showCreateProjectModal(context);
      return;
    }

    final hasCompanyWallets = finance.wallets.any((w) => w.scope == 'company');
    String fundingSource = hasCompanyWallets ? 'company' : 'personal';
    int selectedProjectId = preselectedProject?.id ?? finance.projects.first.id;
    int? selectedWalletId = finance.wallets.isNotEmpty ? finance.wallets.first.id : null;
    int? selectedCategoryId = finance.incomeCategories.isNotEmpty ? finance.incomeCategories.first.id : null;
    String selectedType = 'income'; // 'income' or 'expense'
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isIncome = selectedType == 'income';
          final currentCategories = isIncome ? finance.incomeCategories : finance.expenseCategories;
          if (selectedCategoryId != null && !currentCategories.any((c) => c.id == selectedCategoryId)) {
            selectedCategoryId = currentCategories.isNotEmpty ? currentCategories.first.id : null;
          }
          final companyWallets = finance.wallets.where((w) => w.scope == 'company').toList();
          final personalWallets = finance.wallets.where((w) => w.scope != 'company').toList();
          final availableWallets = fundingSource == 'company'
              ? (companyWallets.isNotEmpty ? companyWallets : finance.wallets)
              : (personalWallets.isNotEmpty ? personalWallets : finance.wallets);
          if (availableWallets.isNotEmpty && !availableWallets.any((w) => w.id == selectedWalletId)) {
            selectedWalletId = availableWallets.first.id;
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Catat Kas Proyek',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Catat pemasukan atau pengeluaran operasional yang terhubung langsung ke proyek & dompet kas.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 16),

                // Tipe Kas Switcher: Pemasukan vs Pengeluaran
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => selectedType = 'income');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: isIncome ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isIncome
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward_rounded, size: 14, color: isIncome ? AppTheme.incomeGreen : AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Pemasukan (Termin/DP)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isIncome ? FontWeight.w700 : FontWeight.w500,
                                    color: isIncome ? AppTheme.incomeGreen : AppTheme.textSecondary,
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
                            HapticFeedback.selectionClick();
                            setModalState(() => selectedType = 'expense');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: !isIncome ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !isIncome
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward_rounded, size: 14, color: !isIncome ? AppTheme.expenseRed : AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Pengeluaran (Biaya)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !isIncome ? FontWeight.w700 : FontWeight.w500,
                                    color: !isIncome ? AppTheme.expenseRed : AppTheme.textSecondary,
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
                const SizedBox(height: 14),

                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: Text(errorText!, style: const TextStyle(color: AppTheme.expenseRed, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ],

                // Dropdown Pilih Proyek
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.iosBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedProjectId,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
                      items: finance.projects.map((p) {
                        return DropdownMenuItem<int>(
                          value: p.id,
                          child: Text(
                            'Proyek: ${p.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedProjectId = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Funding Source Switcher: Kas Perusahaan vs Talangan Pribadi
                const Text(
                  'Sumber Dana Transaksi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() {
                              fundingSource = 'company';
                              if (companyWallets.isNotEmpty) {
                                selectedWalletId = companyWallets.first.id;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: fundingSource == 'company' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: fundingSource == 'company'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business_center_rounded,
                                  size: 13,
                                  color: fundingSource == 'company' ? AppTheme.companyTeal : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Kas Perusahaan',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: fundingSource == 'company' ? FontWeight.w700 : FontWeight.w500,
                                    color: fundingSource == 'company' ? AppTheme.companyTeal : AppTheme.textSecondary,
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
                            HapticFeedback.selectionClick();
                            setModalState(() {
                              fundingSource = 'personal';
                              if (personalWallets.isNotEmpty) {
                                selectedWalletId = personalWallets.first.id;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: fundingSource == 'personal' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: fundingSource == 'personal'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 13,
                                  color: fundingSource == 'personal' ? AppTheme.iosBlue : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Talangan Pribadi',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: fundingSource == 'personal' ? FontWeight.w700 : FontWeight.w500,
                                    color: fundingSource == 'personal' ? AppTheme.iosBlue : AppTheme.textSecondary,
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
                const SizedBox(height: 10),

                // Dropdown Pilih Dompet Rekening
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.iosBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: availableWallets.any((w) => w.id == selectedWalletId)
                          ? selectedWalletId
                          : (availableWallets.isNotEmpty ? availableWallets.first.id : null),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
                      items: availableWallets.map((w) {
                        final isComp = w.scope == 'company';
                        return DropdownMenuItem<int>(
                          value: w.id,
                          child: Text(
                            '${isComp ? "🏢 [Kas Perusahaan]" : "👤 [Dompet Pribadi]"} ${w.name} (${_formatRupiah(w.balance)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedWalletId = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Selector (Kategori Analisa)
                if (currentCategories.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kategori Analisa',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                      if (selectedCategoryId != null)
                        Text(
                          currentCategories.firstWhere((c) => c.id == selectedCategoryId, orElse: () => currentCategories.first).name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: currentCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final cat = currentCategories[idx];
                        final isSelected = cat.id == selectedCategoryId;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => selectedCategoryId = cat.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? (isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.iconData,
                                  size: 13,
                                  color: isSelected ? Colors.white : cat.colorValue,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Input Nominal
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.iosBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                  ),
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Nominal Transaksi (Rp)',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.normal),
                      prefixIcon: Icon(
                        isIncome ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                        size: 18,
                        color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Input Catatan
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.iosBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                  ),
                  child: TextField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: const InputDecoration(
                      hintText: 'Catatan (contoh: DP Termin 1 / Beli domain & server)',
                      hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.edit_note_rounded, size: 18, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          if (amount <= 0 || selectedWalletId == null) {
                            setModalState(() => errorText = 'Nominal dan rekening harus diisi dengan benar');
                            return;
                          }

                          setModalState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          final success = await finance.recordProjectTransaction(
                            projectId: selectedProjectId,
                            walletId: selectedWalletId!,
                            categoryId: selectedCategoryId,
                            type: selectedType,
                            amount: amount,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          );

                          if (success && mounted) {
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Kas proyek berhasil dicatat: ${_formatRupiah(amount)}'),
                                backgroundColor: isIncome ? AppTheme.incomeGreen : const Color(0xFF1C1C1E),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else if (mounted) {
                            setModalState(() {
                              isSaving = false;
                              errorText = finance.errorMessage ?? 'Gagal mencatat kas proyek';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isIncome ? AppTheme.incomeGreen : const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          isIncome ? 'Catat Pemasukan Proyek' : 'Catat Pengeluaran Proyek',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ======================= MODAL: DETAIL & MUTASI PROYEK =======================
  void _showProjectDetailModal(BuildContext context, ProjectModel project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProjectDetailBottomSheet(project: project),
    );
  }
}

/// Bottom Sheet Detail & Mutasi Kas Proyek
class _ProjectDetailBottomSheet extends StatefulWidget {
  final ProjectModel project;
  const _ProjectDetailBottomSheet({required this.project});

  @override
  State<_ProjectDetailBottomSheet> createState() => _ProjectDetailBottomSheetState();
}

class _ProjectDetailBottomSheetState extends State<_ProjectDetailBottomSheet> {
  Map<String, dynamic>? _projectDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final finance = context.read<FinanceProvider>();
    final data = await finance.getProjectDetails(widget.project.id);
    if (mounted) {
      setState(() {
        _projectDetails = data;
        _isLoading = false;
      });
    }
  }

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  Future<void> _changeStatus(String newStatus) async {
    final finance = context.read<FinanceProvider>();
    final success = await finance.updateProjectStatus(widget.project.id, newStatus);
    if (success && mounted) {
      _fetchDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final proj = _projectDetails?['project'] as Map<String, dynamic>?;
    final transactions = (_projectDetails?['transactions'] as List<dynamic>?) ?? [];

    final name = proj?['name']?.toString() ?? widget.project.name;
    final description = proj?['description']?.toString() ?? widget.project.description;
    final status = proj?['status']?.toString() ?? widget.project.status;
    final targetBudget = int.tryParse(proj?['target_budget']?.toString() ?? '') ?? widget.project.targetBudget;
    final currentIncome = int.tryParse(proj?['current_income']?.toString() ?? '') ?? widget.project.currentIncome;
    final currentExpense = int.tryParse(proj?['current_expense']?.toString() ?? '') ?? widget.project.currentExpense;
    final netProfit = currentIncome - currentExpense;
    final isPositiveProfit = netProfit >= 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Color(0xFFF2F2F7), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(description!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
          ],
          const SizedBox(height: 14),

          // Status selector chips
          Row(
            children: [
              const Text('Status Proyek: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(width: 6),
              _buildStatusChip('active', 'Aktif', status),
              const SizedBox(width: 5),
              _buildStatusChip('completed', 'Selesai', status),
              const SizedBox(width: 5),
              _buildStatusChip('on_hold', 'Ditunda', status),
            ],
          ),
          const SizedBox(height: 14),

          // Summary Mini Cards
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Anggaran', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_formatRupiah(targetBudget), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    const Text('Kas Masuk', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('+${_formatRupiah(currentIncome)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen)),
                  ],
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    const Text('Biaya Keluar', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('-${_formatRupiah(currentExpense)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.expenseRed)),
                  ],
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    const Text('Laba Bersih', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${isPositiveProfit ? "+" : ""}${_formatRupiah(netProfit)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isPositiveProfit ? AppTheme.incomeGreen : AppTheme.expenseRed)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Riwayat Mutasi Kas Proyek
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Riwayat Kas Proyek (${transactions.length})', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
              ),
            )
          else if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 28, color: AppTheme.textSecondary),
                  SizedBox(height: 8),
                  Text('Belum Ada Mutasi Kas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text('Catat kas termin klien atau biaya belanja proyek.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.iosBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: AppTheme.iosDivider),
                  itemBuilder: (ctx, idx) {
                    final tx = transactions[idx] as Map<String, dynamic>;
                    final type = tx['type']?.toString() ?? 'expense';
                    final isIncome = type == 'income';
                    final color = isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed;
                    final icon = isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
                    final amount = int.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
                    final date = tx['transaction_date']?.toString().split('T')[0] ?? '';
                    final notes = tx['notes']?.toString();
                    final userName = tx['user_name']?.toString() ?? 'Anggota Tim';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 13, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notes?.isNotEmpty == true ? notes! : (isIncome ? 'Pemasukan Proyek' : 'Pengeluaran Proyek'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                                Text(
                                  '$date • oleh $userName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncome ? "+" : "-"} ${_formatRupiah(amount)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 18),

          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            child: const Text('Tutup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String statusCode, String label, String currentStatus) {
    final isSelected = currentStatus == statusCode;
    Color color = const Color(0xFF1C1C1E);
    if (statusCode == 'completed') color = AppTheme.incomeGreen;
    if (statusCode == 'on_hold') color = const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () => _changeStatus(statusCode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
