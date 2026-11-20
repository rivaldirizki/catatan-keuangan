import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/saving_model.dart';
import '../models/debt_model.dart';

class FinanceProvider extends ChangeNotifier {
  final ApiClient apiClient;

  bool _isFamilyView = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<WalletModel> _wallets = [];
  List<TransactionModel> _transactions = [];
  List<SavingModel> _savings = [];
  List<DebtModel> _debts = [];

  int _totalBalance = 0;
  int _totalIncome = 0;
  int _totalExpense = 0;
  int _netCashflow = 0;

  FinanceProvider({required this.apiClient});

  bool get isFamilyView => _isFamilyView;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<WalletModel> get wallets => _wallets;
  List<TransactionModel> get transactions => _transactions;
  List<SavingModel> get savings => _savings;
  List<DebtModel> get debts => _debts;

  int get totalBalance => _totalBalance;
  int get totalIncome => _totalIncome;
  int get totalExpense => _totalExpense;
  int get netCashflow => _netCashflow;

  void toggleFamilyView(bool value) {
    _isFamilyView = value;
    notifyListeners();
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = {'familyView': _isFamilyView ? 'true' : 'false'};

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

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> addIncome({required int walletId, required int amount, required String date, String notes = '', bool isFamily = false}) async {
    try {
      await apiClient.post(ApiConstants.transactionIncome, body: {
        'wallet_id': walletId,
        'amount': amount,
        'date': date,
        'notes': notes,
        'isFamily': isFamily,
      });
      await fetchDashboard();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> addExpense({required int walletId, required int amount, required String date, String notes = '', bool isFamily = false}) async {
    try {
      await apiClient.post(ApiConstants.transactionExpense, body: {
        'wallet_id': walletId,
        'amount': amount,
        'date': date,
        'notes': notes,
        'isFamily': isFamily,
      });
      await fetchDashboard();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> depositToSaving({required int walletId, required int savingId, required int amount, String notes = ''}) async {
    try {
      await apiClient.post(ApiConstants.savingsDeposit, body: {
        'wallet_id': walletId,
        'saving_id': savingId,
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
}
