import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;

  UserModel? _currentUser;
  CompanyModel? _currentCompany;
  List<Map<String, dynamic>> _companyMembers = [];
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required this.apiClient});

  UserModel? get currentUser => _currentUser;
  CompanyModel? get currentCompany => _currentCompany;
  List<Map<String, dynamic>> get companyMembers => _companyMembers;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(ApiConstants.login, body: {
        'email': email.trim(),
        'password': password,
      });

      _token = res['token'] as String;
      _currentUser = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      apiClient.setToken(_token);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', jsonEncode(res['user']));
      } catch (_) {}

      FcmService.syncToken(apiClient);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(ApiConstants.register, body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      });

      _token = res['token'] as String;
      _currentUser = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      apiClient.setToken(_token);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', jsonEncode(res['user']));
      } catch (_) {}

      FcmService.syncToken(apiClient);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_token');
      final savedUser = prefs.getString('user_data');
      if (savedToken != null && savedToken.isNotEmpty && savedUser != null && savedUser.isNotEmpty) {
        _token = savedToken;
        _currentUser = UserModel.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
        apiClient.setToken(_token);
        notifyListeners();
        FcmService.syncToken(apiClient);
        // Refresh silently in background
        refreshUser();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> refreshUser() async {
    try {
      final res = await apiClient.get(ApiConstants.me);
      if (res is Map<String, dynamic> && res['user'] != null) {
        _currentUser = UserModel.fromJson(res['user'] as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> createFamily(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(ApiConstants.familyCreate, body: {
        'name': name.trim(),
      });
      await refreshUser();
      _isLoading = false;
      notifyListeners();
      return res as Map<String, dynamic>;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> joinFamily(String inviteCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await apiClient.post(ApiConstants.familyJoin, body: {
        'invite_code': inviteCode.trim().toUpperCase(),
      });
      await refreshUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentFamily() async {
    try {
      final res = await apiClient.get(ApiConstants.familyCurrent);
      if (res is Map<String, dynamic>) {
        return res;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createCompany(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(ApiConstants.companyCreate, body: {
        'name': name.trim(),
      });
      await refreshUser();
      await getCurrentCompany();
      _isLoading = false;
      notifyListeners();
      return res as Map<String, dynamic>;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> joinCompany(String inviteCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await apiClient.post(ApiConstants.companyJoin, body: {
        'invite_code': inviteCode.trim().toUpperCase(),
      });
      await refreshUser();
      await getCurrentCompany();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentCompany() async {
    try {
      final res = await apiClient.get(ApiConstants.companyCurrent);
      if (res is Map<String, dynamic>) {
        if (res['company'] != null && res['company'] is Map<String, dynamic>) {
          _currentCompany = CompanyModel.fromJson(res['company'] as Map<String, dynamic>);
        }
        if (res['members'] is List) {
          _companyMembers = (res['members'] as List).cast<Map<String, dynamic>>();
        }
        notifyListeners();
        return res;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await FcmService.unregisterToken(apiClient);
    } catch (_) {}

    _currentUser = null;
    _currentCompany = null;
    _companyMembers = [];
    _token = null;
    apiClient.setToken(null);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    } catch (_) {}
  }
}
