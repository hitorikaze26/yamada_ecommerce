import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState();

  AuthState get state => _state;

  bool get isAuthenticated => _state.isAuthenticated;
  User? get user => _state.user;
  UserRole? get role => _state.user?.role;

  Future<void> login(String email, String password, UserRole role) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Mock successful login
      final user = User(
        id: '1',
        email: email,
        name: email.split('@').first,
        role: role,
        contactNumber: '+63 912 345 6789',
      );

      _state = AuthState(
        user: user,
        token: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        isLoading: false,
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Invalid email or password. Please try again.',
      );
    }

    notifyListeners();
  }

  Future<void> register(String email, String password, UserRole role,
      {String? name}) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Mock successful registration
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        name: name ?? email.split('@').first,
        role: role,
      );

      _state = AuthState(
        user: user,
        token: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        isLoading: false,
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Registration failed. Please try again.',
      );
    }

    notifyListeners();
  }

  void logout() {
    _state = AuthState();
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }
}
