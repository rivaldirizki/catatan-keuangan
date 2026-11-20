import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../core/theme/app_theme.dart';

class FamilySwitcher extends StatelessWidget {
  const FamilySwitcher({super.key});

  void _showFamilySetupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FamilySetupModal(),
    );
  }

  void _showFamilyDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FamilyDetailsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finance = context.watch<FinanceProvider>();
    final isFamily = finance.isFamilyView;
    final hasFamily = auth.currentUser?.familyId != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pribadi Tab
          GestureDetector(
            onTap: () {
              if (isFamily) {
                HapticFeedback.lightImpact();
                finance.toggleFamilyView(false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
              decoration: BoxDecoration(
                color: !isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: !isFamily
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
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 13,
                    color: !isFamily ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pribadi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: !isFamily ? FontWeight.w600 : FontWeight.w500,
                      color: !isFamily ? AppTheme.textPrimary : AppTheme.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Keluarga Tab
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (!isFamily) {
                finance.toggleFamilyView(true);
              } else if (hasFamily) {
                _showFamilyDetailsSheet(context);
              } else {
                _showFamilySetupSheet(context);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
              decoration: BoxDecoration(
                color: isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: isFamily
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
                children: [
                  Icon(
                    Icons.group_rounded,
                    size: 13,
                    color: isFamily ? AppTheme.familyPurple : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Keluarga',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isFamily ? FontWeight.w600 : FontWeight.w500,
                      color: isFamily ? AppTheme.familyPurple : AppTheme.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (hasFamily && isFamily) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.familyPurple),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Setup Keluarga (Buat Keluarga Baru vs Masuk Keluarga)
class _FamilySetupModal extends StatefulWidget {
  const _FamilySetupModal();

  @override
  State<_FamilySetupModal> createState() => _FamilySetupModalState();
}

class _FamilySetupModalState extends State<_FamilySetupModal> {
  int _activeTab = 0; // 0: Buat Keluarga, 1: Masuk Keluarga
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateFamily() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Harap masukkan nama keluarga');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();
    final result = await auth.createFamily(name);

    setState(() => _isLoading = false);

    if (result != null && mounted) {
      finance.toggleFamilyView(true);
      Navigator.pop(context);
      _showSuccessCreatedDialog(result['name'].toString(), result['invite_code'].toString());
    } else if (mounted) {
      setState(() => _errorMessage = auth.errorMessage ?? 'Gagal membuat keluarga');
    }
  }

  Future<void> _handleJoinFamily() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Harap masukkan kode ID keluarga');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();
    final success = await auth.joinFamily(code);

    setState(() => _isLoading = false);

    if (success && mounted) {
      finance.toggleFamilyView(true);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Berhasil bergabung ke keluarga dengan kode $code!'),
            ],
          ),
          backgroundColor: AppTheme.incomeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      setState(() => _errorMessage = auth.errorMessage ?? 'Kode ID keluarga tidak valid');
    }
  }

  void _showSuccessCreatedDialog(String familyName, String inviteCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.incomeGreen, size: 22),
            SizedBox(width: 8),
            Text('Keluarga Dibuat!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Grup "$familyName" berhasil dibuat. Setiap keluarga memiliki ID unik acak berikut:',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ID / KODE UNDANGAN', style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        inviteCode,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: AppTheme.familyPurple,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.iosBlue, size: 18),
                    tooltip: 'Salin Kode',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ID Keluarga berhasil disalin ke clipboard!'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bagikan ID acak ini kepada anggota keluarga Anda agar mereka dapat masuk dan mencatat keuangan bersama.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            child: const Text('Mulai Kelola Keuangan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Keuangan Keluarga',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
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
          const SizedBox(height: 4),
          const Text(
            'Kelola tabungan bersama dan pantau catatan keuangan keluarga.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
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
                      setState(() {
                        _activeTab = 0;
                        _errorMessage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _activeTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Buat Keluarga',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _activeTab == 0 ? FontWeight.w600 : FontWeight.w500,
                          color: _activeTab == 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
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
                        _activeTab = 1;
                        _errorMessage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _activeTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Masuk Keluarga',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _activeTab == 1 ? FontWeight.w600 : FontWeight.w500,
                          color: _activeTab == 1 ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.expenseRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.25), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.expenseRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.expenseRed, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_activeTab == 0) ...[
            Container(
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Nama Keluarga (contoh: Keluarga Pratama)',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.home_outlined, size: 18, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.vpn_key_outlined, size: 14, color: AppTheme.familyPurple),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sistem akan otomatis membuat ID acak unik untuk keluarga Anda yang bisa dibagikan ke anggota lain.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleCreateFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Buat Keluarga Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Masukkan 8 Karakter Kode ID',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13, letterSpacing: 0),
                  prefixIcon: Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.iosBlue),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Minta kode ID acak dari keluarga Anda, lalu masukkan di sini untuk bergabung.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleJoinFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.familyPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gabung Sekarang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal Detail Keluarga & Tampilan ID Acak (Dapat Diklik untuk Cek Catatan Anggota)
class _FamilyDetailsModal extends StatefulWidget {
  const _FamilyDetailsModal();

  @override
  State<_FamilyDetailsModal> createState() => _FamilyDetailsModalState();
}

class _FamilyDetailsModalState extends State<_FamilyDetailsModal> {
  Map<String, dynamic>? _familyData;
  List<dynamic> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyInfo();
  }

  Future<void> _loadFamilyInfo() async {
    final auth = context.read<AuthProvider>();
    final data = await auth.getCurrentFamily();
    if (mounted) {
      setState(() {
        _familyData = data?['family'] as Map<String, dynamic>?;
        _members = (data?['members'] as List<dynamic>?) ?? [];
        _isLoading = false;
      });
    }
  }

  void _showMemberInspection(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberInspectionModal(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inviteCode = _familyData?['invite_code']?.toString() ?? '--------';
    final familyName = _familyData?['name']?.toString() ?? 'Keluarga Saya';

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
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Informasi Keluarga',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(color: AppTheme.familyPurple),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E1065), Color(0xFF4C1D95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.familyPurple.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        familyName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${_members.length} Anggota',
                          style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('ID / KODE GABUNG KELUARGA:', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        inviteCode,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2.5, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ID Keluarga berhasil disalin ke clipboard!'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 13),
                        label: const Text('Salin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.familyPurple,
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Bagikan ID di atas agar anggota keluarga lain dapat bergabung dan sinkronisasi catatan keuangan bersama.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 16),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daftar Anggota Keluarga', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text('Ketuk untuk catatan', style: TextStyle(fontSize: 11, color: AppTheme.familyPurple, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _members.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: AppTheme.iosDivider),
                itemBuilder: (ctx, index) {
                  final member = _members[index] as Map<String, dynamic>;
                  final name = member['name']?.toString() ?? 'Anggota';
                  final email = member['email']?.toString() ?? '';
                  final role = member['role']?.toString() ?? 'user';
                  final totalBalance = int.tryParse(member['total_balance']?.toString() ?? '0') ?? 0;

                  return InkWell(
                    onTap: () => _showMemberInspection(member),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: AppTheme.familyPurple.withValues(alpha: 0.15),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppTheme.familyPurple, fontWeight: FontWeight.w700, fontSize: 11.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    if (role == 'admin') ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppTheme.familyPurple.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Admin', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppTheme.familyPurple)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(email, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalBalance),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                              ),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Catatan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.iosBlue)),
                                  Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.iosBlue),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
        ],
      ),
    );
  }
}

/// Modal Inspeksi Catatan Keuangan Anggota Keluarga Tertentu
class _MemberInspectionModal extends StatefulWidget {
  final Map<String, dynamic> member;
  const _MemberInspectionModal({required this.member});

  @override
  State<_MemberInspectionModal> createState() => _MemberInspectionModalState();
}

class _MemberInspectionModalState extends State<_MemberInspectionModal> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMemberSummary();
  }

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  Future<void> _fetchMemberSummary() async {
    final finance = context.read<FinanceProvider>();
    final memberId = widget.member['id'] as int;
    final res = await finance.getMemberFinancialSummary(memberId);
    if (mounted) {
      setState(() {
        _summary = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.member['name']?.toString() ?? 'Anggota';
    final memberEmail = widget.member['email']?.toString() ?? '';
    final txList = (_summary?['transactions'] as List<dynamic>?) ?? [];
    final totalBalance = int.tryParse(_summary?['total_balance']?.toString() ?? '0') ?? 0;
    final income = int.tryParse(_summary?['total_income']?.toString() ?? '0') ?? 0;
    final expense = int.tryParse(_summary?['total_expense']?.toString() ?? '0') ?? 0;

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
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.familyPurple.withValues(alpha: 0.15),
                    child: Text(
                      memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppTheme.familyPurple, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan: $memberName',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      Text(memberEmail, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
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
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(color: AppTheme.familyPurple),
              ),
            )
          else ...[
            // Summary Inset Grouped Card: Saldo Akhir | Pemasukan | Pengeluaran
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo Akhir', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatRupiah(totalBalance),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 0.8, height: 26, color: AppTheme.iosDivider),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pemasukan', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '+ ${_formatRupiah(income)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.incomeGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 0.8, height: 26, color: AppTheme.iosDivider),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pengeluaran', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '- ${_formatRupiah(expense)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.expenseRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Riwayat Transaksi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text('${txList.length} mutasi', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),

            if (txList.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.iosBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                ),
                child: Center(
                  child: Text(
                    'Belum ada transaksi yang dicatat oleh $memberName.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.iosBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: txList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: AppTheme.iosDivider),
                    itemBuilder: (ctx, idx) {
                      final tx = txList[idx] as Map<String, dynamic>;
                      final type = tx['type']?.toString() ?? 'expense';
                      final isIncome = type == 'income';
                      final isSaving = type == 'saving_deposit';
                      final color = isIncome ? AppTheme.incomeGreen : (isSaving ? AppTheme.iosBlue : AppTheme.expenseRed);
                      final icon = isIncome
                          ? Icons.arrow_downward_rounded
                          : (isSaving ? Icons.savings_rounded : Icons.arrow_upward_rounded);
                      final amount = int.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
                      final date = tx['transaction_date']?.toString().split('T')[0] ?? '';
                      final notes = tx['notes']?.toString();

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
                                    notes?.isNotEmpty == true ? notes! : (isIncome ? 'Pemasukan' : 'Pengeluaran'),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                  ),
                                  Text(date, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            Text(
                              '${isIncome ? "+" : "-"} ${_formatRupiah(amount)}',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
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
        ],
      ),
    );
  }
}
