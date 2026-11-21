import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/saving_model.dart';

class SavingsScreen extends StatelessWidget {
  final bool isEmbedded;
  const SavingsScreen({super.key, this.isEmbedded = false});

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
                  // iOS Drag Handle
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
                            const Text(
                              'Nabung ke Celengan',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            Text(
                              goal.goalName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppTheme.iosBlue, fontWeight: FontWeight.w600),
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
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.iosBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.iosBlue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saldo dompet berkurang & celengan bertambah secara instan.',
                            style: TextStyle(color: AppTheme.iosBlue, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Wallet selector
                  DropdownButtonFormField<int>(
                    initialValue: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: 'Dompet Sumber Dana',
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

                  // Nominal input
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Nominal Setoran',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick preset chips
                  Row(
                    children: [20000, 50000, 100000, 500000].map((preset) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              amountController.text = preset.toString();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: const BorderSide(color: AppTheme.iosDivider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              '+${preset ~/ 1000}k',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  ElevatedButton(
                    onPressed: () async {
                      final amount = int.tryParse(amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (amount <= 0 || selectedWalletId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harap pilih dompet dan isi nominal setoran')),
                        );
                        return;
                      }

                      HapticFeedback.mediumImpact();
                      Navigator.pop(modalCtx);
                      final success = await finance.depositToSaving(walletId: selectedWalletId!, savingId: goal.id, amount: amount);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Berhasil menyetor ke tabungan!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.iosBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Setor Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddGoalModal(BuildContext context) {
    final finance = context.read<FinanceProvider>();
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    final auth = context.read<AuthProvider>();
    final hasFamily = auth.currentUser?.familyId != null;
    String selectedScope = finance.isFamilyView && hasFamily ? 'family' : 'personal';

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
                    'Buat Celengan Baru',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // Scope selector if user has family
                  if (hasFamily) ...[
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
                                setModalState(() => selectedScope = 'personal');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedScope == 'personal' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: selectedScope == 'personal'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 14, color: selectedScope == 'personal' ? AppTheme.textPrimary : AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pribadi',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: selectedScope == 'personal' ? FontWeight.w600 : FontWeight.w500,
                                        color: selectedScope == 'personal' ? AppTheme.textPrimary : AppTheme.textSecondary,
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
                                setModalState(() => selectedScope = 'family');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedScope == 'family' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: selectedScope == 'family'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.family_restroom_rounded, size: 14, color: selectedScope == 'family' ? AppTheme.familyPurple : AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Bersama Keluarga',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: selectedScope == 'family' ? FontWeight.w600 : FontWeight.w500,
                                        color: selectedScope == 'family' ? AppTheme.familyPurple : AppTheme.textSecondary,
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
                    const SizedBox(height: 8),
                    Text(
                      selectedScope == 'family'
                          ? '🎯 Celengan bersama dapat diakses dan diisi oleh seluruh anggota keluarga hingga target tercapai.'
                          : '🔒 Celengan pribadi hanya dapat dilihat dan diisi oleh Anda.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Target (misal: Liburan, DP Rumah, Gadget)',
                      prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Target Nominal',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final target = int.tryParse(targetController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                      if (name.isEmpty || target <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harap masukkan nama dan target nominal')),
                        );
                        return;
                      }

                      HapticFeedback.mediumImpact();
                      Navigator.pop(modalCtx);
                      await finance.createSavingGoal(
                        goalName: name,
                        targetAmount: target,
                        scope: selectedScope,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Buat Celengan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

    int totalSaved = finance.savings.fold(0, (sum, g) => sum + g.currentAmount);
    int totalTarget = finance.savings.fold(0, (sum, g) => sum + g.targetAmount);
    double totalProgress = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.iosBg,
      appBar: AppBar(
        automaticallyImplyLeading: !isEmbedded,
        leading: isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text('Celengan & Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.iosBlue, size: 24),
            onPressed: () => _showAddGoalModal(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
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
                      const Expanded(
                        child: Text(
                          'Total Terkumpul di Celengan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.iosBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(totalProgress * 100).toStringAsFixed(0)}% Tercapai',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.iosBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatRupiah(totalSaved),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalProgress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E5EA),
                      valueColor: const AlwaysStoppedAnimation(AppTheme.iosBlue),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dari total target ${_formatRupiah(totalTarget)} di ${finance.savings.length} celengan aktif',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daftar Celengan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  Text('${finance.savings.length} target', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (finance.savings.isEmpty)
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
                    Icon(Icons.savings_outlined, size: 48, color: AppTheme.textTertiary),
                    SizedBox(height: 12),
                    Text('Belum ada target celengan', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: finance.savings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final goal = finance.savings[index];
                  final progress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
                  final percentage = (progress * 100).toStringAsFixed(0);

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.iosDivider, width: 0.8),
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
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.iosBlue.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.savings_rounded, color: AppTheme.iosBlue, size: 20),
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
                                                goal.goalName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2),
                                              ),
                                            ),
                                            if (goal.isFamilyShared) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.familyPurple.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.family_restroom_rounded, size: 11, color: AppTheme.familyPurple),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'Bersama',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          'Target: ${_formatRupiah(goal.targetAmount)}',
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: progress >= 1.0
                                    ? AppTheme.incomeGreen.withValues(alpha: 0.12)
                                    : AppTheme.iosBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                progress >= 1.0 ? 'Tercapai! 🎉' : '$percentage%',
                                style: TextStyle(
                                  color: progress >= 1.0 ? AppTheme.incomeGreen : AppTheme.iosBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE5E5EA),
                            valueColor: AlwaysStoppedAnimation(
                              progress >= 1.0 ? AppTheme.incomeGreen : AppTheme.iosBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _formatRupiah(goal.currentAmount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showDepositModal(context, goal);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosBlue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Nabung',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Contributors list for family shared goals
                        if (goal.isFamilyShared) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppTheme.iosDivider),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Kontribusi Anggota:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              Text(
                                '${goal.contributors.length} Kontributor',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (goal.contributors.isEmpty)
                            const Text(
                              'Belum ada setoran dari anggota keluarga.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: goal.contributors.map((c) {
                                final share = goal.targetAmount > 0
                                    ? ((c.totalContributed / goal.targetAmount) * 100).toStringAsFixed(0)
                                    : '0';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.iosBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 8,
                                        backgroundColor: AppTheme.familyPurple.withValues(alpha: 0.15),
                                        child: Text(
                                          c.userName.isNotEmpty ? c.userName[0].toUpperCase() : '?',
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppTheme.familyPurple),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                                        child: Text(
                                          '${c.userName}: ${_formatRupiah(c.totalContributed)} ($share%)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
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
}
