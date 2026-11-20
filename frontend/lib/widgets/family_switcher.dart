import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        borderRadius: BorderRadius.circular(10),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: !isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: !isFamily
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: !isFamily ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Pribadi',
                    style: TextStyle(
                      fontSize: 13,
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
              if (!hasFamily) {
                // Belum punya keluarga -> Tampilkan opsi Buat / Masuk Keluarga
                _showFamilySetupSheet(context);
              } else if (!isFamily) {
                // Punya keluarga -> Aktifkan tampilan keluarga
                finance.toggleFamilyView(true);
              } else {
                // Sedang di tampilan keluarga -> Buka detail keluarga & ID acak
                _showFamilyDetailsSheet(context);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isFamily ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isFamily
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.group_rounded,
                    size: 14,
                    color: isFamily ? AppTheme.familyPurple : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Keluarga',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFamily ? FontWeight.w600 : FontWeight.w500,
                      color: isFamily ? AppTheme.familyPurple : AppTheme.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (hasFamily && isFamily) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.familyPurple),
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
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.incomeGreen, size: 26),
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
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ID / KODE UNDANGAN', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        inviteCode,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: AppTheme.familyPurple,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.iosBlue),
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
            const SizedBox(height: 12),
            const Text(
              'Bagikan ID acak ini kepada anggota keluarga Anda agar mereka dapat masuk dan mencatat keuangan bersama.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Mulai Kelola Keuangan'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // iOS Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Keuangan Keluarga',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
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
          const SizedBox(height: 6),
          const Text(
            'Kelola anggaran rumah tangga bersama keluarga Anda dalam satu sistem tersinkronisasi.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 20),

          // Sliding Segmented Tab: Buat Keluarga vs Masuk Keluarga
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(12),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _activeTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Buat Keluarga',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _activeTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Masuk Keluarga',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
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
          const SizedBox(height: 20),

          // Error Banner if any
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.expenseRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.expenseRed.withValues(alpha: 0.25), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.expenseRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.expenseRed, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Content Tab 0: Buat Keluarga Baru
          if (_activeTab == 0) ...[
            Container(
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nama Keluarga (contoh: Keluarga Pratama)',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.home_outlined, size: 20, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.vpn_key_outlined, size: 15, color: AppTheme.familyPurple),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sistem akan otomatis membuat ID acak unik untuk keluarga Anda yang bisa dibagikan ke anggota lain.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleCreateFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Buat Keluarga Baru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ] else ...[
            // Content Tab 1: Masuk Keluarga
            Container(
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Masukkan 8 Karakter Kode ID',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14, letterSpacing: 0),
                  prefixIcon: Icon(Icons.vpn_key_rounded, size: 20, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.iosBlue),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Minta kode ID acak dari kepala keluarga atau anggota yang sudah membuat keluarga, lalu masukkan di sini.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleJoinFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.familyPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gabung Sekarang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal Detail Keluarga & Tampilan ID Acak (Untuk Keluarga yang Sudah Ada)
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

  @override
  Widget build(BuildContext context) {
    final inviteCode = _familyData?['invite_code']?.toString() ?? '--------';
    final familyName = _familyData?['name']?.toString() ?? 'Keluarga Saya';

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
          // iOS Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Informasi Keluarga',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
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
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppTheme.familyPurple),
              ),
            )
          else ...[
            // Family Card with ID
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5856D6), Color(0xFF3634A3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.familyPurple.withValues(alpha: 0.25),
                    blurRadius: 16,
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
                      Text(
                        familyName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_members.length} Anggota',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('ID / KODE GABUNG KELUARGA:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        inviteCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.0,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Salin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.familyPurple,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Bagikan ID di atas agar anggota keluarga lain dapat bergabung dan sinkronisasi catatan keuangan bersama.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 20),

            // Members List
            const Text(
              'Daftar Anggota Keluarga',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: AppTheme.iosBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _members.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 52, color: AppTheme.iosDivider),
                itemBuilder: (ctx, index) {
                  final member = _members[index] as Map<String, dynamic>;
                  final name = member['name']?.toString() ?? 'Anggota';
                  final email = member['email']?.toString() ?? '';
                  final role = member['role']?.toString() ?? 'user';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.familyPurple.withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.familyPurple, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        if (role == 'admin')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.familyPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.familyPurple)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tutup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}
