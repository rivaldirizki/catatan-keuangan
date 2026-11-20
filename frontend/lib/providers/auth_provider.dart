import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;

  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required this.apiClient});

  UserModel? get currentUser => _currentUser;
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

  void logout() {
    _currentUser = null;
    _token = null;
    apiClient.setToken(null);
    notifyListeners();
  }
}
