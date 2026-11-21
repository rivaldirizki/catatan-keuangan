import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/saving_model.dart';
import '../models/debt_model.dart';
import '../models/family_model.dart';
import '../models/project_model.dart';
import '../models/offline_sync_item.dart';
import '../services/offline_sync_service.dart';

enum AppViewMode { personal, family, company }

class FinanceProvider extends ChangeNotifier {
  final ApiClient apiClient;

  AppViewMode _currentMode = AppViewMode.personal;
  bool _isLoading = false;
  String? _errorMessage;

  bool _isOffline = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  String _currentUserId = 'default';

  List<WalletModel> _wallets = [];
  List<TransactionModel> _transactions = [];
  List<SavingModel> _savings = [];
  List<DebtModel> _debts = [];
  List<DebtReminderModel> _debtReminders = [];
  List<Map<String, dynamic>> _familyMembers = [];
  FamilyModel? _currentFamily;
  List<ProjectModel> _projects = [];

  int _totalBalance = 0;
  int _totalIncome = 0;
  int _totalExpense = 0;
  int _netCashflow = 0;

  FinanceProvider({required this.apiClient});

  AppViewMode get currentMode => _currentMode;
  bool get isFamilyView => _currentMode == AppViewMode.family;
  bool get isCompanyView => _currentMode == AppViewMode.company;
  bool get isPersonalView => _currentMode == AppViewMode.personal;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isOffline => _isOffline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  String get currentUserId => _currentUserId;

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    checkPendingSync();
  }

  Future<void> checkPendingSync() async {
    final queue = await OfflineSyncService.getQueue(_currentUserId);
    _pendingSyncCount = queue.length;
    notifyListeners();
  }

  bool _isNetworkError(dynamic e) {
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('clientexception') ||
        str.contains('connection refused') ||
        str.contains('failed host lookup') ||
        str.contains('network') ||
        str.contains('xmlhttprequest error') ||
        str.contains('err_connection_refused');
  }

  List<WalletModel> get wallets => _wallets;
  List<TransactionModel> get transactions => _transactions;
  List<SavingModel> get savings => _savings;
  List<DebtModel> get debts => _debts;
  List<DebtReminderModel> get debtReminders => _debtReminders;
  List<Map<String, dynamic>> get familyMembers => _familyMembers;
  FamilyModel? get currentFamily => _currentFamily;
  List<ProjectModel> get projects => _projects;

  int get totalBalance => _totalBalance;
  int get totalIncome => _totalIncome;
  int get totalExpense => _totalExpense;
  int get netCashflow => _netCashflow;

  void setViewMode(AppViewMode mode) {
    _currentMode = mode;
    notifyListeners();
    fetchDashboard();
  }

  void toggleFamilyView(bool value) {
    _currentMode = value ? AppViewMode.family : AppViewMode.personal;
    notifyListeners();
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = {
        'familyView': isFamilyView ? 'true' : 'false',
        'companyView': isCompanyView ? 'true' : 'false',
        'viewMode': _currentMode.name,
      };

      // 1. Wallets
      final walletsData = await apiClient.get(ApiConstants.wallets, queryParams: queryParams);
      if (walletsData is List) {
        _wallets = walletsData.map((w) => WalletModel.fromJson(w as Map<String, dynamic>)).toList();
      }

      // 2. Summary
      final summaryData = await apiClient.get(ApiConstants.transactionSummary, queryParams: queryParams);
      if (summaryData is Map<String, dynamic>) {
        _totalBalance = int.tryParse(summaryData['total_balance'].toString()) ?? 0;
        _totalIncome = int.tryParse(summaryData['total_income'].toString()) ?? 0;
        _totalExpense = int.tryParse(summaryData['total_expense'].toString()) ?? 0;
        _netCashflow = int.tryParse(summaryData['net_cashflow'].toString()) ?? 0;
      }

      // 3. Transactions
      final txData = await apiClient.get(ApiConstants.transactions, queryParams: queryParams);
      if (txData is List) {
        _transactions = txData.map((t) => TransactionModel.fromJson(t as Map<String, dynamic>)).toList();
      }

      // 4. Savings
      final savingsData = await apiClient.get(ApiConstants.savings, queryParams: queryParams);
      if (savingsData is List) {
        _savings = savingsData.map((s) => SavingModel.fromJson(s as Map<String, dynamic>)).toList();
      }

      // 5. Debts
      final debtsData = await apiClient.get(ApiConstants.debts, queryParams: queryParams);
      if (debtsData is List) {
        _debts = debtsData.map((d) => DebtModel.fromJson(d as Map<String, dynamic>)).toList();
      }

      // 5b. Debt Reminders (due/overdue)
      dynamic remindersData;
      try {
        remindersData = await apiClient.get(ApiConstants.debtReminders, queryParams: queryParams);
        if (remindersData is List) {
          _debtReminders = remindersData.map((r) => DebtReminderModel.fromJson(r as Map<String, dynamic>)).toList();
        } else {
          _debtReminders = [];
        }
      } catch (_) {
        _debtReminders = [];
      }

      // 6. Family members and family info if family view
      if (isFamilyView) {
        try {
          final famData = await apiClient.get(ApiConstants.familyCurrent);
          if (famData is Map<String, dynamic>) {
            if (famData['family'] != null && famData['family'] is Map<String, dynamic>) {
              _currentFamily = FamilyModel.fromJson(famData['family'] as Map<String, dynamic>);
            } else {
              _currentFamily = null;
            }
            if (famData['members'] is List) {
              _familyMembers = (famData['members'] as List).cast<Map<String, dynamic>>();
            } else {
              _familyMembers = [];
            }
          }
        } catch (_) {
          _currentFamily = null;
          _familyMembers = [];
        }
      } else {
        _familyMembers = [];
        _currentFamily = null;
      }

      // 7. Projects if company view
      if (isCompanyView) {
        await fetchProjectsInternal();
      } else {
        _projects = [];
      }

      // Save complete snapshot to local storage
      await OfflineSyncService.cacheDashboard(_currentUserId, {
        'wallets': walletsData,
        'summary': summaryData,
        'transactions': txData,
        'savings': savingsData,
        'debts': debtsData,
        'debtReminders': remindersData,
      });

      _isOffline = false;
      await checkPendingSync();
      _isLoading = false;
      notifyListeners();

      // Trigger automatic background sync of any pending queue
      syncPendingQueue();
    } catch (e) {
      final cached = await OfflineSyncService.getCachedDashboard(_currentUserId);
      if (cached != null) {
        _applyCachedData(cached);
        _isOffline = true;
        _errorMessage = null;
      } else {
        _isOffline = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      _isLoading = false;
      await checkPendingSync();
      notifyListeners();
    }
  }

  void _applyCachedData(Map<String, dynamic> cached) {
    if (cached['wallets'] is List) {
      _wallets = (cached['wallets'] as List).map((w) => WalletModel.fromJson(w as Map<String, dynamic>)).toList();
    }
    if (cached['summary'] is Map<String, dynamic>) {
      final summaryData = cached['summary'] as Map<String, dynamic>;
      _totalBalance = int.tryParse(summaryData['total_balance'].toString()) ?? 0;
      _totalIncome = int.tryParse(summaryData['total_income'].toString()) ?? 0;
      _totalExpense = int.tryParse(summaryData['total_expense'].toString()) ?? 0;
      _netCashflow = int.tryParse(summaryData['net_cashflow'].toString()) ?? 0;
    }
    if (cached['transactions'] is List) {
      _transactions = (cached['transactions'] as List).map((t) => TransactionModel.fromJson(t as Map<String, dynamic>)).toList();
    }
    if (cached['savings'] is List) {
      _savings = (cached['savings'] as List).map((s) => SavingModel.fromJson(s as Map<String, dynamic>)).toList();
    }
    if (cached['debts'] is List) {
      _debts = (cached['debts'] as List).map((d) => DebtModel.fromJson(d as Map<String, dynamic>)).toList();
    }
    if (cached['debtReminders'] is List) {
      _debtReminders = (cached['debtReminders'] as List).map((r) => DebtReminderModel.fromJson(r as Map<String, dynamic>)).toList();
    }
  }

  Future<void> fetchProjectsInternal() async {
    try {
      final res = await apiClient.get(ApiConstants.projects);
      if (res is List) {
        _projects = res.map((p) => ProjectModel.fromJson(p as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _projects = [];
    }
  }

  Future<void> fetchProjects() async {
    await fetchProjectsInternal();
    notifyListeners();
  }

  Future<bool> createProject({
    required String name,
    String? description,
    int targetBudget = 0,
    String? startDate,
    String? endDate,
  }) async {
    try {
      await apiClient.post(ApiConstants.projects, body: {
        'name': name.trim(),
        'description': description?.trim(),
        'target_budget': targetBudget,
        'start_date': startDate,
        'end_date': endDate,
      });
      await fetchProjects();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordProjectTransaction({
    required int projectId,
    required int walletId,
    int? categoryId,
    required String type,
    required int amount,
    String? notes,
  }) async {
    try {
      await apiClient.post(ApiConstants.projectTransaction(projectId), body: {
        'wallet_id': walletId,
        'category_id': categoryId,
        'type': type,
        'amount': amount,
        'notes': notes,
      });
      await fetchDashboard();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProjectDetails(int projectId) async {
    try {
      final res = await apiClient.get(ApiConstants.projectDetail(projectId));
      if (res is Map<String, dynamic>) {
        return res;
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateProjectStatus(int projectId, String status) async {
    try {
      await apiClient.patch(ApiConstants.projectStatus(projectId), body: {
        'status': status,
      });
      await fetchProjects();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> addIncome({required int walletId, required int amount, required String date, String notes = '', bool isFamily = false}) async {
    final idempotencyKey = OfflineSyncService.generateIdempotencyKey();
    final body = {
      'wallet_id': walletId,
      'amount': amount,
      'date': date,
      'notes': notes,
      'isFamily': isFamily,
      'idempotency_key': idempotencyKey,
    };

    if (!_isOffline) {
      try {
        await apiClient.post(ApiConstants.transactionIncome, body: body);
        await fetchDashboard();
        return true;
      } catch (e) {
        if (!_isNetworkError(e)) {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          notifyListeners();
          return false;
        }
      }
    }

    // Offline optimistic handling
    final item = OfflineSyncItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      endpoint: ApiConstants.transactionIncome,
      method: 'POST',
      body: body,
      idempotencyKey: idempotencyKey,
      timestamp: DateTime.now(),
      description: 'Pemasukan Rp $amount',
    );
    await OfflineSyncService.enqueue(_currentUserId, item);

    // Optimistic UI updates
    _wallets = _wallets.map((w) => w.id == walletId ? w.copyWith(balance: w.balance + amount) : w).toList();
    _totalBalance += amount;
    _totalIncome += amount;
    _netCashflow = _totalIncome - _totalExpense;

    final optTx = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: int.tryParse(_currentUserId) ?? 1,
      familyId: isFamily ? _currentFamily?.id : null,
      walletId: walletId,
      type: 'income',
      amount: amount,
      transactionDate: date,
      notes: notes.isNotEmpty ? '$notes (Offline)' : '(Offline)',
      scope: isFamily ? 'family' : 'personal',
    );
    _transactions = [optTx, ..._transactions];

    _isOffline = true;
    await checkPendingSync();
    notifyListeners();
    return true;
  }

  Future<bool> addExpense({required int walletId, required int amount, required String date, String notes = '', bool isFamily = false}) async {
    final idempotencyKey = OfflineSyncService.generateIdempotencyKey();
    final body = {
      'wallet_id': walletId,
      'amount': amount,
      'date': date,
      'notes': notes,
      'isFamily': isFamily,
      'idempotency_key': idempotencyKey,
    };

    if (!_isOffline) {
      try {
        await apiClient.post(ApiConstants.transactionExpense, body: body);
        await fetchDashboard();
        return true;
      } catch (e) {
        if (!_isNetworkError(e)) {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          notifyListeners();
          return false;
        }
      }
    }

    // Offline optimistic handling
    final item = OfflineSyncItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      endpoint: ApiConstants.transactionExpense,
      method: 'POST',
      body: body,
      idempotencyKey: idempotencyKey,
      timestamp: DateTime.now(),
      description: 'Pengeluaran Rp $amount',
    );
    await OfflineSyncService.enqueue(_currentUserId, item);

    // Optimistic UI updates
    _wallets = _wallets.map((w) => w.id == walletId ? w.copyWith(balance: w.balance - amount) : w).toList();
    _totalBalance -= amount;
    _totalExpense += amount;
    _netCashflow = _totalIncome - _totalExpense;

    final optTx = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: int.tryParse(_currentUserId) ?? 1,
      familyId: isFamily ? _currentFamily?.id : null,
      walletId: walletId,
      type: 'expense',
      amount: amount,
      transactionDate: date,
      notes: notes.isNotEmpty ? '$notes (Offline)' : '(Offline)',
      scope: isFamily ? 'family' : 'personal',
    );
    _transactions = [optTx, ..._transactions];

    _isOffline = true;
    await checkPendingSync();
    notifyListeners();
    return true;
  }

  Future<bool> depositToSaving({required int walletId, required int savingId, required int amount, String notes = ''}) async {
    final idempotencyKey = OfflineSyncService.generateIdempotencyKey();
    final body = {
      'wallet_id': walletId,
      'saving_id': savingId,
      'amount': amount,
      'notes': notes,
      'idempotency_key': idempotencyKey,
    };

    if (!_isOffline) {
      try {
        await apiClient.post(ApiConstants.savingsDeposit, body: body);
        await fetchDashboard();
        return true;
      } catch (e) {
        if (!_isNetworkError(e)) {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          notifyListeners();
          return false;
        }
      }
    }

    // Offline optimistic handling
    final item = OfflineSyncItem(
      id: 'sav_${DateTime.now().millisecondsSinceEpoch}',
      endpoint: ApiConstants.savingsDeposit,
      method: 'POST',
      body: body,
      idempotencyKey: idempotencyKey,
      timestamp: DateTime.now(),
      description: 'Nabung Rp $amount',
    );
    await OfflineSyncService.enqueue(_currentUserId, item);

    _wallets = _wallets.map((w) => w.id == walletId ? w.copyWith(balance: w.balance - amount) : w).toList();
    _savings = _savings.map((s) => s.id == savingId ? SavingModel(
      id: s.id,
      userId: s.userId,
      familyId: s.familyId,
      goalName: s.goalName,
      targetAmount: s.targetAmount,
      currentAmount: s.currentAmount + amount,
      targetDate: s.targetDate,
      scope: s.scope,
      status: (s.currentAmount + amount) >= s.targetAmount ? 'completed' : 'active',
      progressPercentage: s.targetAmount > 0 ? (((s.currentAmount + amount) / s.targetAmount) * 100).round() : 0,
      contributors: s.contributors,
    ) : s).toList();

    _isOffline = true;
    await checkPendingSync();
    notifyListeners();
    return true;
  }

  Future<bool> createSavingGoal({
    required String goalName,
    required int targetAmount,
    String? targetDate,
    String scope = 'personal',
  }) async {
    try {
      await apiClient.post(ApiConstants.savingsGoals, body: {
        'goal_name': goalName,
        'target_amount': targetAmount,
        'target_date': targetDate,
        'scope': scope,
      });
      await fetchDashboard();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> createDebt({
    required String type,
    required String personName,
    required int amount,
    required String dueDate,
    String notes = '',
    String scope = 'personal',
    int installmentsCount = 1,
  }) async {
    final idempotencyKey = OfflineSyncService.generateIdempotencyKey();
    final body = {
      'type': type,
      'person_name': personName,
      'amount': amount,
      'due_date': dueDate,
      'notes': notes,
      'scope': scope,
      'installments_count': installmentsCount,
      'idempotency_key': idempotencyKey,
    };

    if (!_isOffline) {
      try {
        await apiClient.post(ApiConstants.debts, body: body);
        await fetchDashboard();
        return true;
      } catch (e) {
        if (!_isNetworkError(e)) {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          notifyListeners();
          return false;
        }
      }
    }

    // Offline optimistic handling
    final item = OfflineSyncItem(
      id: 'debt_${DateTime.now().millisecondsSinceEpoch}',
      endpoint: ApiConstants.debts,
      method: 'POST',
      body: body,
      idempotencyKey: idempotencyKey,
      timestamp: DateTime.now(),
      description: 'Hutang/Piutang $personName Rp $amount',
    );
    await OfflineSyncService.enqueue(_currentUserId, item);

    final optDebt = DebtModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: int.tryParse(_currentUserId) ?? 1,
      type: type,
      personName: personName,
      totalAmount: amount,
      remainingAmount: amount,
      installmentsCount: installmentsCount,
      dueDate: dueDate,
      status: 'unpaid',
      computedStatus: 'unpaid',
      scope: scope,
      notes: notes.isNotEmpty ? '$notes (Offline)' : '(Offline)',
    );
    _debts = [optDebt, ..._debts];

    _isOffline = true;
    await checkPendingSync();
    notifyListeners();
    return true;
  }

  Future<int> syncPendingQueue() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;
    try {
      final queue = await OfflineSyncService.getQueue(_currentUserId);
      if (queue.isEmpty) {
        _pendingSyncCount = 0;
        _isSyncing = false;
        notifyListeners();
        return 0;
      }

      for (final item in queue) {
        try {
          if (item.method == 'POST') {
            await apiClient.post(item.endpoint, body: item.body);
          } else if (item.method == 'PATCH') {
            await apiClient.patch(item.endpoint, body: item.body);
          }
          await OfflineSyncService.remove(_currentUserId, item.id);
          syncedCount++;
        } catch (itemErr) {
          if (_isNetworkError(itemErr)) {
            // Still offline, halt replay
            break;
          } else {
            // Already processed or invalid, remove to prevent queue blockage
            await OfflineSyncService.remove(_currentUserId, item.id);
            syncedCount++;
          }
        }
      }

      final remaining = await OfflineSyncService.getQueue(_currentUserId);
      _pendingSyncCount = remaining.length;
      if (syncedCount > 0) {
        _isOffline = false;
        await fetchDashboard();
      }
    } catch (_) {}

    _isSyncing = false;
    notifyListeners();
    return syncedCount;
  }

  Future<bool> payDebt({required int debtId, required int walletId, required int amount, String notes = ''}) async {
    try {
      await apiClient.post(ApiConstants.debtPay(debtId), body: {
        'wallet_id': walletId,
        'amount': amount,
        'notes': notes,
      });
      await fetchDashboard();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMemberFinancialSummary(int memberId) async {
    try {
      final res = await apiClient.get(ApiConstants.familyMemberSummary(memberId));
      if (res is Map<String, dynamic>) {
        return res;
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }
}
