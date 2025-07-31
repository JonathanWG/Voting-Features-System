// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkLoginStatus(); // Check if user is already logged in on app start
  }

  Future<void> _checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();
    // Attempt to fetch current user, which will also try to refresh token
    _currentUser = await _apiService.getCurrentUser();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null; // Clear previous errors
    notifyListeners();

    final user = await _apiService.login(username, password);
    _currentUser = user;
    _isLoading = false;
    if (user == null) {
      _errorMessage = 'Invalid username or password.';
    }
    notifyListeners();
    return user != null;
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _errorMessage = null; // Clear previous errors
    notifyListeners();

    final success = await _apiService.register(username, email, password);
    _isLoading = false;
    if (!success) {
      _errorMessage = 'Registration failed. Username or email might be taken.';
    }
    notifyListeners();
    return success;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _apiService.logout(); // Clear tokens
    _currentUser = null; // Clear current user
    _isLoading = false;
    notifyListeners();
  }
}