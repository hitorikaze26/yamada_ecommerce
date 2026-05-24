import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data
/// Uses flutter_secure_storage for encrypted key-value storage
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys for stored data
  static const String _userKey = 'yamada_user';
  static const String _tokenKey = 'yamada_token';
  static const String _roleKey = 'yamada_role';
  static const String _isVerifiedKey = 'yamada_verified';

  /// Save user data securely
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    await _storage.write(
      key: _userKey,
      value: jsonEncode(userData),
    );
  }

  /// Get stored user data
  static Future<Map<String, dynamic>?> getUser() async {
    final data = await _storage.read(key: _userKey);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Save access token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Get stored token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Save user role
  static Future<void> saveRole(String role) async {
    await _storage.write(key: _roleKey, value: role);
  }

  /// Get stored role
  static Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  /// Save verification status
  static Future<void> saveVerificationStatus(bool isVerified) async {
    await _storage.write(
      key: _isVerifiedKey,
      value: isVerified.toString(),
    );
  }

  /// Get verification status
  static Future<bool> getVerificationStatus() async {
    final value = await _storage.read(key: _isVerifiedKey);
    return value == 'true';
  }

  /// Clear all stored data (used on logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Delete specific keys
  static Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
