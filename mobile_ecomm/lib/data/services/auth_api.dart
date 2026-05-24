import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../../core/utils/file_utils.dart';
import '../models/address_model.dart';
import '../models/user_model.dart';

/// Result of [AuthApi.checkSession].
enum SessionCheckResult {
  /// Session is valid (200 from protected endpoint).
  valid,

  /// Session is invalid or expired (401).
  invalid,

  /// Network or server error — keep cached session locally.
  unknown,
}

/// Auth API Service
/// Maps to Flask backend endpoints under /api/accounts
class AuthApi {
  /// Login endpoint
  /// POST /api/accounts/login
  /// Backend expects: {username, password}
  /// Returns: {access_token, is_verified, msg}
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final dio = await ApiClient.getInstance();
    developer.log('AuthApi.login: Starting login request to: ${dio.options.baseUrl}/accounts/login', name: 'AuthApi');

    try {
      final response = await dio.post(
        '/accounts/login',
        data: {
          'username': email, // Backend accepts email as username
          'password': password,
          'role': role.name,
        },
      );
      developer.log('AuthApi.login: Success - Status ${response.statusCode}', name: 'AuthApi');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'access_token': response.data['access_token'],
          'is_verified': response.data['is_verified'] ?? false,
          'user_id': response.data['user_id'],
          'roles': response.data['roles'],
          'message': response.data['msg'] ?? 'Successfully logged in!',
        };
      }

      throw Exception(response.data['msg'] ?? 'Login failed');
    } on DioException catch (e) {
      developer.log('AuthApi.login: DioException - Type: ${e.type}, Message: ${e.message}', name: 'AuthApi', error: e);
      developer.log('AuthApi.login: DioException - Response: ${e.response?.statusCode}, Data: ${e.response?.data}', name: 'AuthApi');
      final msg = e.response?.data['msg']?.toString();
      if (e.response?.statusCode == 403 && msg != null) {
        throw Exception(msg);
      }
      if (e.response?.statusCode == 401) {
        if (msg == "Please input your credentials!") {
          throw Exception("Please input your credentials!");
        } else if (msg == "User does not exist!") {
          throw Exception("User does not exist!");
        } else if (msg == "Incorrect password!") {
          throw Exception("Incorrect password!");
        }
      }
      // Handle connection errors specifically
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw Exception('Cannot connect to server at ${dio.options.baseUrl}. Check your network and server.');
      }
      throw Exception(msg ?? 'An error occurred during login: ${e.message}');
    }
  }

  /// Logout endpoint
  /// POST /api/accounts/logout
  /// Requires JWT authentication
  static Future<void> logout() async {
    final dio = await ApiClient.getInstance();

    try {
      await dio.post('/accounts/logout');
    } on DioException catch (e) {
      // Even if logout fails, clear local data
      throw Exception(e.response?.data['msg'] ?? 'Logout failed');
    } finally {
      // Clear cookies
      await ApiClient.clearCookies();
    }
  }

  /// Check session validity
  /// GET /api/accounts/protected
  /// Requires JWT authentication
  static Future<SessionCheckResult> checkSession() async {
    final dio = await ApiClient.getInstance();
    developer.log('AuthApi.checkSession: Checking session at: ${dio.options.baseUrl}/accounts/protected', name: 'AuthApi');

    try {
      await dio.get('/accounts/protected');
      developer.log('AuthApi.checkSession: Session valid', name: 'AuthApi');
      return SessionCheckResult.valid;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        developer.log('AuthApi.checkSession: Session expired (401)', name: 'AuthApi');
        return SessionCheckResult.invalid;
      }
      developer.log('AuthApi.checkSession: Connection error - ${e.type}: ${e.message}', name: 'AuthApi', error: e);
      return SessionCheckResult.unknown;
    }
  }

  /// Register Buyer
  /// POST /api/accounts/register-buyer
  /// Expects multipart/form-data with buyer profile + valid ID
  static Future<Map<String, dynamic>> registerBuyer({
    required String givenName,
    required String surname,
    required String email,
    required String password,
    required String contactNumber,
    required AddressData address,
    File? validId,
  }) async {
    final dio = await ApiClient.getInstance();

    try {
      final formData = FormData.fromMap({
        'givenName': givenName,
        'surname': surname,
        'email': email,
        'password': password,
        'contactNumber': contactNumber,
        'address': address.toJsonString(),
        if (validId != null)
          'validId': await MultipartFile.fromFile(
            validId.path,
            filename: multipartFilename(validId.path),
          ),
      });

      final response = await dio.post(
        '/accounts/register-buyer',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['msg'] ?? 'Successfully registered buyer. Awaiting admin approval.',
        };
      }

      throw Exception(response.data['msg'] ?? 'Registration failed');
    } on DioException catch (e) {
      final msg = e.response?.data['msg'];
      if (e.response?.statusCode == 400) {
        if (msg?.contains('already exists') == true) {
          throw Exception("Email already exists!");
        }
        throw Exception(msg ?? 'Invalid registration data');
      }
      throw Exception(msg ?? 'An error occurred during registration');
    }
  }

  /// Register Seller
  /// POST /api/accounts/register-seller
  /// Expects multipart/form-data with seller profile + documents
  static Future<Map<String, dynamic>> registerSeller({
    required String givenName,
    required String surname,
    required String email,
    required String password,
    required String contactNumber,
    required String shopName,
    required String tagline,
    required String description,
    required List<String> categories,
    required AddressData address,
    File? logo,
    required SellerDocuments documents,
  }) async {
    final dio = await ApiClient.getInstance();

    try {
      final formData = FormData.fromMap({
        'givenName': givenName,
        'surname': surname,
        'email': email,
        'password': password,
        'contactNumber': contactNumber,
        'shopName': shopName,
        'tagline': tagline,
        'description': description,
        'categories': jsonEncode(categories),
        'address': address.toJsonString(),
        if (logo != null)
          'logo': await MultipartFile.fromFile(
            logo.path,
            filename: multipartFilename(logo.path),
          ),
        if (documents.dti != null)
          'dti': await MultipartFile.fromFile(
            documents.dti!.path,
            filename: multipartFilename(documents.dti!.path),
          ),
        if (documents.birTin != null)
          'birTin': await MultipartFile.fromFile(
            documents.birTin!.path,
            filename: multipartFilename(documents.birTin!.path),
          ),
        if (documents.businessPermit != null)
          'businessPermit': await MultipartFile.fromFile(
            documents.businessPermit!.path,
            filename: multipartFilename(documents.businessPermit!.path),
          ),
        if (documents.validId != null)
          'validId': await MultipartFile.fromFile(
            documents.validId!.path,
            filename: multipartFilename(documents.validId!.path),
          ),
      });

      final response = await dio.post(
        '/accounts/register-seller',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['msg'] ?? 'Successfully registered seller. Awaiting admin approval.',
        };
      }

      throw Exception(response.data['msg'] ?? 'Registration failed');
    } on DioException catch (e) {
      final msg = e.response?.data['msg'];
      if (e.response?.statusCode == 400) {
        if (msg?.contains('already exists') == true) {
          throw Exception("Email already exists!");
        }
        throw Exception(msg ?? 'Invalid registration data');
      }
      throw Exception(msg ?? 'An error occurred during registration');
    }
  }

  /// Register Rider
  /// POST /api/accounts/register-rider
  /// Expects multipart/form-data with rider profile + license + OR/CR
  static Future<Map<String, dynamic>> registerRider({
    required String givenName,
    required String surname,
    required String email,
    required String password,
    required String contactNumber,
    required String vehicleType,
    required String licenseNumber,
    required AddressData address,
    File? license,
    File? orCr,
  }) async {
    final dio = await ApiClient.getInstance();

    try {
      final formData = FormData.fromMap({
        'givenName': givenName,
        'surname': surname,
        'email': email,
        'password': password,
        'contactNumber': contactNumber,
        'vehicleType': vehicleType,
        'licenseNumber': licenseNumber,
        'address': address.toJsonString(),
        if (license != null)
          'license': await MultipartFile.fromFile(
            license.path,
            filename: multipartFilename(license.path),
          ),
        if (orCr != null)
          'orCr': await MultipartFile.fromFile(
            orCr.path,
            filename: multipartFilename(orCr.path),
          ),
      });

      final response = await dio.post(
        '/accounts/register-rider',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['msg'] ?? 'Successfully registered rider. Awaiting admin approval.',
        };
      }

      throw Exception(response.data['msg'] ?? 'Registration failed');
    } on DioException catch (e) {
      final msg = e.response?.data['msg'];
      if (e.response?.statusCode == 400) {
        if (msg?.contains('already exists') == true) {
          throw Exception("Email already exists!");
        }
        throw Exception(msg ?? 'Invalid registration data');
      }
      throw Exception(msg ?? 'An error occurred during registration');
    }
  }

  /// Get Buyer Profile
  /// GET /api/accounts/buyer/profile
  static Future<Map<String, dynamic>> getBuyerProfile() async {
    final dio = await ApiClient.getInstance();

    try {
      final response = await dio.get('/accounts/buyer/profile');
      return response.data['profile'] ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to load profile');
    }
  }

  /// Get Seller Profile
  /// GET /api/accounts/seller/profile
  static Future<Map<String, dynamic>> getSellerProfile() async {
    final dio = await ApiClient.getInstance();

    try {
      final response = await dio.get('/accounts/seller/profile');
      return response.data['profile'] ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to load profile');
    }
  }

  /// Get Rider Profile
  /// GET /api/accounts/rider/profile
  static Future<Map<String, dynamic>> getRiderProfile() async {
    final dio = await ApiClient.getInstance();

    try {
      final response = await dio.get('/accounts/rider/profile');
      return response.data['profile'] ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to load profile');
    }
  }

  /// Rider profile for login/session; falls back to JWT snapshot on failure.
  static Future<Map<String, dynamic>> fetchRiderProfileForSession({
    required bool isVerified,
    String? email,
    int? userId,
    String? givenName,
    String? surname,
    String? contactNumber,
  }) async {
    try {
      final profile = await getRiderProfile();
      return {
        ...profile,
        'isVerified': profile['isVerified'] ?? isVerified,
      };
    } catch (_) {
      // Fall through to session snapshot.
    }
    return {
      if (email != null) 'email': email,
      if (userId != null) 'id': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
      if (givenName != null) 'givenName': givenName,
      if (surname != null) 'surname': surname,
      if (contactNumber != null) 'contactNumber': contactNumber,
      'isVerified': isVerified,
    };
  }

  /// Update Buyer Profile
  /// PUT /api/accounts/buyer/profile
  /// Expects JSON body with optional fields: givenName, surname, email, contactNumber
  static Future<Map<String, dynamic>> updateBuyerProfile({
    String? givenName,
    String? surname,
    String? email,
    String? contactNumber,
    Map<String, dynamic>? address,
  }) async {
    final dio = await ApiClient.getInstance();

    try {
      final response = await dio.put(
        '/accounts/buyer/profile',
        data: {
          if (givenName != null) 'givenName': givenName,
          if (surname != null) 'surname': surname,
          if (email != null) 'email': email,
          if (contactNumber != null) 'contactNumber': contactNumber,
          if (address != null) 'address': address,
        },
      );

      return response.data['profile'] ?? {};
    } on DioException catch (e) {
      final msg = e.response?.data['msg'];
      if (e.response?.statusCode == 400) {
        if (msg?.contains('already exists') == true) {
          throw Exception("Email already exists!");
        }
      }
      throw Exception(msg ?? 'Failed to update profile');
    }
  }

  /// Update Rider Profile
  /// PUT /api/accounts/rider/profile
  /// Expects JSON body with optional fields: givenName, surname, email, contactNumber, vehicleType, licenseNumber
  static Future<Map<String, dynamic>> updateRiderProfile({
    String? givenName,
    String? surname,
    String? email,
    String? contactNumber,
    String? vehicleType,
    String? licenseNumber,
    Map<String, dynamic>? address,
  }) async {
    final dio = await ApiClient.getInstance();

    try {
      final response = await dio.put(
        '/accounts/rider/profile',
        data: {
          if (givenName != null) 'givenName': givenName,
          if (surname != null) 'surname': surname,
          if (email != null) 'email': email,
          if (contactNumber != null) 'contactNumber': contactNumber,
          if (vehicleType != null) 'vehicleType': vehicleType,
          if (licenseNumber != null) 'licenseNumber': licenseNumber,
          if (address != null) 'address': address,
        },
      );

      return response.data['profile'] ?? {};
    } on DioException catch (e) {
      final msg = e.response?.data['msg'];
      if (e.response?.statusCode == 400) {
        if (msg?.contains('already exists') == true) {
          throw Exception("Email already exists!");
        }
      }
      throw Exception(msg ?? 'Failed to update profile');
    }
  }

  /// POST /api/accounts/rider/documents — re-upload license and/or OR/CR
  static Future<Map<String, dynamic>> uploadRiderDocuments({
    File? license,
    File? orCr,
  }) async {
    final dio = await ApiClient.getInstance();

    try {
      final formData = FormData.fromMap({
        if (license != null)
          'license': await MultipartFile.fromFile(
            license.path,
            filename: multipartFilename(license.path),
          ),
        if (orCr != null)
          'orCr': await MultipartFile.fromFile(
            orCr.path,
            filename: multipartFilename(orCr.path),
          ),
      });

      final response = await dio.post(
        '/accounts/rider/documents',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return response.data['profile'] ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to upload documents');
    }
  }

  /// Change password — PUT /api/accounts/change-password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.put('/accounts/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['msg'];
      throw Exception(msg ?? 'Failed to change password');
    }
  }

  /// Change email — PUT /api/accounts/change-email
  static Future<void> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.put('/accounts/change-email', data: {
        'newEmail': newEmail,
        'password': password,
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['msg'];
      if (e.response?.statusCode == 400 &&
          msg?.contains('already in use') == true) {
        throw Exception('Email already in use');
      }
      throw Exception(msg ?? 'Failed to change email');
    }
  }

  /// Upload buyer avatar — POST /api/accounts/buyer/avatar
  static Future<String> uploadBuyerAvatar(File avatar) async {
    final dio = await ApiClient.getInstance();

    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          avatar.path,
          filename: multipartFilename(avatar.path),
        ),
      });

      final response = await dio.post(
        '/accounts/buyer/avatar',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return response.data['avatarUrl']?.toString() ?? '';
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to upload avatar');
    }
  }

  /// Upload rider avatar — POST /api/accounts/rider/avatar
  static Future<String> uploadRiderAvatar(File avatar) async {
    final dio = await ApiClient.getInstance();

    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          avatar.path,
          filename: avatar.path.split('/').last,
        ),
      });

      final response = await dio.post(
        '/accounts/rider/avatar',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return response.data['avatarUrl']?.toString() ?? '';
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to upload avatar');
    }
  }

  /// Update contact number — reuses the seller profile PUT endpoint
  static Future<void> updateContactNumber(String contactNumber) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.put('/accounts/seller/profile',
          data: {'contactNumber': contactNumber});
    } on DioException catch (e) {
      final msg = e.response?.data?['msg'];
      throw Exception(msg ?? 'Failed to update contact number');
    }
  }

  /// POST /api/accounts/forgot-password/contact-lookup
  static Future<String?> lookupContactForReset({required String email}) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.post(
        '/accounts/forgot-password/contact-lookup',
        data: {'email': email.trim()},
      );
      return response.data['contactNumber'] as String?;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['msg'] ?? 'Failed to load contact number',
      );
    }
  }

  /// POST /api/accounts/forgot-password
  static Future<Map<String, dynamic>> forgotPassword({
    String? email,
    String? contactNumber,
    String channel = 'email',
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.post(
        '/accounts/forgot-password',
        data: {
          if (email != null && email.isNotEmpty) 'email': email.trim(),
          if (contactNumber != null && contactNumber.isNotEmpty)
            'contactNumber': contactNumber.trim(),
          'channel': channel,
        },
      );
      return {
        'msg': response.data['msg'] as String? ??
            'If an account exists, a code has been sent.',
        'email': response.data['email'] as String?,
      };
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to send reset code');
    }
  }

  /// POST /api/accounts/verify-pin
  static Future<void> verifyPin({
    required String email,
    required String pin,
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.post(
        '/accounts/verify-pin',
        data: {'email': email, 'pin': pin},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Invalid PIN');
    }
  }

  /// POST /api/accounts/reset-password
  static Future<void> resetPassword({
    required String email,
    required String pin,
    required String newPassword,
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.post(
        '/accounts/reset-password',
        data: {
          'email': email,
          'pin': pin,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to reset password');
    }
  }

  /// Delete account — DELETE /api/accounts/delete-account
  static Future<void> deleteAccount({required String password}) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.delete('/accounts/delete-account',
          data: {'password': password});
    } on DioException catch (e) {
      final msg = e.response?.data?['msg'];
      throw Exception(msg ?? 'Failed to delete account');
    }
  }
}

/// Seller documents container
class SellerDocuments {
  final File? dti;
  final File? birTin;
  final File? businessPermit;
  final File? validId;

  SellerDocuments({
    this.dti,
    this.birTin,
    this.businessPermit,
    this.validId,
  });
}
