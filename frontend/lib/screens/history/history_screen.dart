import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/family_switcher.dart';

class HistoryScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onAddTransactionPressed;

  const HistoryScreen({
    super.key,
    this.isEmbedded = false,
    this.onAddTransactionPressed,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'all'; // 'all', 'income', 'expense'
  String _datePreset = 'all'; // 'all', 'today', '7days', 'month', 'custom'
  DateTimeRange? _customDateRange;
  int? _selectedWalletId;
  int? _selectedMemberId; // For member filtering in Family mode

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  String _monthName(int month) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }

  String _formatDateHeader(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(parsed.year, parsed.month, parsed.day);
      final diff = today.difference(target).inDays;

      if (diff == 0) return 'Hari Ini, ${parsed.day} ${_monthName(parsed.month)} ${parsed.year}';
      if (diff == 1) return 'Kemarin, ${parsed.day} ${_monthName(parsed.month)} ${parsed.year}';
      return '${parsed.day} ${_monthName(parsed.month)} ${parsed.year}';
    } catch (_) {
      return dateStr;
    }
  }

  DateTimeRange? _computeActiveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_datePreset == 'today') {
      return DateTimeRange(start: today, end: today);
    } else if (_datePreset == '7days') {
      return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today);
    } else if (_datePreset == 'month') {
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: today);
    } else if (_datePreset == 'custom') {
      return _customDateRange;
    }
    return null;
  }

  Future<void> _pickCustomDateRange() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final initialRange = _customDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.iosBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _datePreset = 'custom';
        _customDateRange = picked;
      });
    }
  }

  void _resetAllFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedType = 'all';
      _datePreset = 'all';
      _customDateRange = null;
      _selectedWalletId = null;
      _selectedMemberId = null;
    });
  }

  void _showTransactionDetail(TransactionModel tx, FinanceProvider finance) {
    HapticFeedback.lightImpact();
    final isIncome = tx.type == 'income';
    final color = isIncome ? AppTheme.incomeGreen : (tx.type == 'saving_deposit' ? AppTheme.iosBlue : AppTheme.expenseRed);
    final wallet = finance.wallets.firstWhere(
      (w) => w.id == tx.walletId,
      orElse: () => finance.wallets.isNotEmpty ? finance.wallets.first : finance.wallets.first,
    );

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

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detail Transaksi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
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
              const SizedBox(height: 20),

              // Hero Amount
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${isIncome ? "+" : "-"} ${_formatRupiah(tx.amount)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tx.notes?.isNotEmpty == true ? tx.notes! : (isIncome ? 'Pemasukan' : 'Pengeluaran'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info Table (Apple Inset Grouped)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.iosBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Tanggal', _formatDateHeader(tx.transactionDate)),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.iosDivider),
                    _buildDetailRow('Sumber Dompet', wallet.name),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.iosDivider),
                    _buildDetailRow('Jenis Transaksi', _txTypeLabel(tx.type)),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.iosDivider),
                    _buildDetailRow('Lingkup', tx.scope == 'family' ? 'Keluarga' : 'Pribadi'),
                    if (tx.userName != null) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.iosDivider),
                      _buildDetailRow('Dicatat Oleh', tx.userName!),
                    ],
                    if (tx.notes?.isNotEmpty == true) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.iosDivider),
                      _buildDetailRow('Catatan', tx.notes!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tutup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _txTypeLabel(String type) {
    switch (type) {
      case 'income':
        return 'Pemasukan';
      case 'expense':
        return 'Pengeluaran';
      case 'saving_deposit':
        return 'Setor Celengan';
      case 'debt_payment':
        return 'Pelunasan Hutang';
      case 'transfer':
        return 'Transfer Antar Dompet';
      default:
        return type;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final activeRange = _computeActiveRange();

    // 1. Filter Transactions
    final filtered = finance.transactions.where((tx) {
      // Type Filter
      if (_selectedType == 'income' && tx.type != 'income') return false;
      if (_selectedType == 'expense' &&
          (tx.type != 'expense' && tx.type != 'saving_deposit' && tx.type != 'debt_payment')) {
        return false;
      }

      // Wallet Filter
      if (_selectedWalletId != null && tx.walletId != _selectedWalletId) {
        return false;
      }

      // Member Filter (Family View)
      if (finance.isFamilyView && _selectedMemberId != null && tx.userId != _selectedMemberId) {
        return false;
      }

      // Date Filter
      if (activeRange != null) {
        try {
          final txDate = DateTime.parse(tx.transactionDate);
          final start = DateTime(activeRange.start.year, activeRange.start.month, activeRange.start.day);
          final end = DateTime(activeRange.end.year, activeRange.end.month, activeRange.end.day, 23, 59, 59);
          if (txDate.isBefore(start) || txDate.isAfter(end)) {
            return false;
          }
        } catch (_) {}
      }

      // Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final notes = (tx.notes ?? '').toLowerCase();
        final userName = (tx.userName ?? '').toLowerCase();
        final amountStr = tx.amount.toString();
        final typeStr = _txTypeLabel(tx.type).toLowerCase();

        final walletName = finance.wallets
            .firstWhere((w) => w.id == tx.walletId, orElse: () => finance.wallets.first)
            .name
            .toLowerCase();

        final matches = notes.contains(query) ||
            amountStr.contains(query) ||
            typeStr.contains(query) ||
            walletName.contains(query) ||
            userName.contains(query);

        if (!matches) return false;
      }

      return true;
    }).toList();

    // 2. Compute dynamic metrics on filtered
    int totalIncome = 0;
    int totalExpense = 0;
    for (final tx in filtered) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }
    final netCashflow = totalIncome - totalExpense;

    // 3. Group by date
    final Map<String, List<TransactionModel>> groupedByDate = {};
    for (final tx in filtered) {
      groupedByDate.putIfAbsent(tx.transactionDate, () => []).add(tx);
    }

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
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          const FamilySwitcher(),
          const SizedBox(width: 8),
          if (widget.onAddTransactionPressed != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.iosBlue, size: 24),
              onPressed: widget.onAddTransactionPressed,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => finance.fetchDashboard(),
        color: AppTheme.iosBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Search & Filters Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search Bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Cari catatan, dompet, nominal...',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: const Icon(Icons.cancel_rounded, size: 18, color: AppTheme.textTertiary),
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // iOS Sliding Segmented Type Control
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTypeTab('all', 'Semua'),
                          _buildTypeTab('income', 'Pemasukan'),
                          _buildTypeTab('expense', 'Pengeluaran'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date Preset Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildDateChip('all', 'Semua Waktu', Icons.calendar_today_rounded),
                          const SizedBox(width: 8),
                          _buildDateChip('today', 'Hari Ini', null),
                          const SizedBox(width: 8),
                          _buildDateChip('7days', '7 Hari', null),
                          const SizedBox(width: 8),
                          _buildDateChip('month', 'Bulan Ini', null),
                          const SizedBox(width: 8),
                          _buildCustomDateChip(),
                        ],
                      ),
                    ),

                    // Active Date Range Indicator (if custom or non-all selected)
                    if (activeRange != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.iosBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available_rounded, size: 15, color: AppTheme.iosBlue),
                            const SizedBox(width: 6),
                            Text(
                              '${activeRange.start.day} ${_monthName(activeRange.start.month)} ${activeRange.start.year} - ${activeRange.end.day} ${_monthName(activeRange.end.month)} ${activeRange.end.year}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.iosBlue),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _datePreset = 'all';
                                  _customDateRange = null;
                                });
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.iosBlue),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Member Filter Chips Row (Family Mode)
                    if (finance.isFamilyView && finance.familyMembers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildMemberChip(null, 'Semua Anggota'),
                            ...finance.familyMembers.map((m) {
                              final memberId = m['id'] as int;
                              final memberName = m['name']?.toString() ?? 'Anggota';
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildMemberChip(memberId, memberName),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Dynamic Filter Summary Inset Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${filtered.length} Transaksi Ditemukan',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty || _selectedType != 'all' || _datePreset != 'all' || _selectedMemberId != null)
                                GestureDetector(
                                  onTap: _resetAllFilters,
                                  child: const Text(
                                    'Reset Filter',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.iosBlue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: AppTheme.iosDivider, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.arrow_downward_rounded, size: 13, color: AppTheme.incomeGreen),
                                        SizedBox(width: 4),
                                        Text('Pemasukan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '+ ${_formatRupiah(totalIncome)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.incomeGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 0.8, height: 32, color: AppTheme.iosDivider),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.arrow_upward_rounded, size: 13, color: AppTheme.expenseRed),
                                        SizedBox(width: 4),
                                        Text('Pengeluaran', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '- ${_formatRupiah(totalExpense)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.expenseRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 0.8, height: 32, color: AppTheme.iosDivider),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Selisih Net', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatRupiah(netCashflow),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: netCashflow >= 0 ? AppTheme.textPrimary : AppTheme.expenseRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Empty State
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textTertiary),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Tidak Ada Transaksi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tidak ada transaksi yang cocok dengan kata kunci pencarian atau filter tanggal yang dipilih.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _resetAllFilters,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset Filter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.textPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // Date-Grouped Transaction List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dateKey = groupedByDate.keys.elementAt(index);
                      final items = groupedByDate[dateKey]!;

                      // Calculate day net subtotal
                      int dayNet = 0;
                      for (final it in items) {
                        dayNet += (it.type == 'income' ? it.amount : -it.amount);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDateHeader(dateKey),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${dayNet >= 0 ? "+" : ""}${_formatRupiah(dayNet)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: dayNet >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Inset Grouped Card
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const Padding(
                                    padding: EdgeInsets.only(left: 60),
                                    child: Divider(color: AppTheme.iosDivider, height: 1),
                                  ),
                                  itemBuilder: (ctx, i) {
                                    final tx = items[i];
                                    final isIncome = tx.type == 'income';
                                    final isSaving = tx.type == 'saving_deposit';
                                    final color = isIncome
                                        ? AppTheme.incomeGreen
                                        : (isSaving ? AppTheme.iosBlue : AppTheme.expenseRed);
                                    final icon = isIncome
                                        ? Icons.arrow_downward_rounded
                                        : (isSaving ? Icons.savings_rounded : Icons.arrow_upward_rounded);

                                    final walletName = finance.wallets
                                        .firstWhere((w) => w.id == tx.walletId, orElse: () => finance.wallets.first)
                                        .name;

                                    return InkWell(
                                      onTap: () => _showTransactionDetail(tx, finance),
                                      child: Padding(
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
                                                    tx.notes?.isNotEmpty == true
                                                        ? tx.notes!
                                                        : (isIncome ? 'Pemasukan' : 'Pengeluaran'),
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
                                                      Flexible(
                                                        child: Text(
                                                          walletName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: AppTheme.textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                      if (finance.isFamilyView && tx.userName != null) ...[
                                                        const SizedBox(width: 6),
                                                        Flexible(
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.familyPurple.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              'Oleh: ${tx.userName}',
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w600,
                                                                color: AppTheme.familyPurple,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ] else if (tx.scope == 'family') ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.familyPurple.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text(
                                                            'Keluarga',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppTheme.familyPurple,
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
                                              '${isIncome ? "+" : "-"} ${_formatRupiah(tx.amount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: color,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: AppTheme.textTertiary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: groupedByDate.keys.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(String key, String label) {
    final isSelected = _selectedType == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedType = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
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
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip(String key, String label, IconData? icon) {
    final isSelected = _datePreset == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _datePreset = key;
          _customDateRange = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textPrimary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.textPrimary : AppTheme.iosDivider,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDateChip() {
    final isSelected = _datePreset == 'custom';
    return GestureDetector(
      onTap: _pickCustomDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.iosBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.iosBlue : AppTheme.iosDivider,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range_rounded, size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              isSelected ? 'Rentang Dipilih' : 'Pilih Rentang...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberChip(int? memberId, String label) {
    final isSelected = _selectedMemberId == memberId;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMemberId = memberId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.familyPurple : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.familyPurple : AppTheme.iosDivider,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              memberId == null ? Icons.people_alt_rounded : Icons.person_rounded,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.familyPurple,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
