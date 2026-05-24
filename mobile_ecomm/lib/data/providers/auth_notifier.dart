import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_client.dart';
import '../../core/services/secure_storage.dart';
import '../models/address_model.dart';
import '../models/user_model.dart';
import '../services/auth_api.dart';
import 'cart_notifier.dart';
import 'chat_notifier.dart';
import 'notifications_notifier.dart';
import 'orders_notifier.dart';
import 'wishlist_notifier.dart';
import 'following_stores_notifier.dart';
import 'recently_viewed_notifier.dart';
import '../services/buyer_engagement_migration.dart';

/// Authentication State
class AuthNotifierState {
  final User? user;
  final String? token;
  final bool isLoading;
  final bool isCheckingAuth;
  final String? error;

  const AuthNotifierState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isCheckingAuth = true,
    this.error,
  });

  bool get isAuthenticated => user != null;
  UserRole? get role => user?.role;
  bool get isVerified => user?.isVerified ?? false;

  AuthNotifierState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    bool? isCheckingAuth,
    String? error,
    bool clearError = false,
  }) {
    return AuthNotifierState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      isCheckingAuth: isCheckingAuth ?? this.isCheckingAuth,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Auth Notifier - Main authentication state management
/// Uses Riverpod for state management matching Next.js client behavior
class AuthNotifier extends StateNotifier<AuthNotifierState> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(const AuthNotifierState()) {
    ApiClient.onSessionExpired = _onSessionExpired;
    // Check for existing session on initialization
    checkAuth();
  }

  void _onSessionExpired() {
    if (!state.isAuthenticated) return;
    developer.log(
      'Session expired — signing out locally',
      name: 'AuthNotifier',
    );
    logout();
  }

  static bool _isAuthRoleMismatch403(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('sellers only') ||
        text.contains('riders only') ||
        text.contains('admins only') ||
        text.contains('buyers only');
  }

  static bool _shouldClearSessionOnProfileError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('401') || text.contains('unauthorized')) {
      return true;
    }
    if (_isAuthRoleMismatch403(e)) return true;
    return false;
  }

  /// Check for existing authentication on app startup
  Future<void> checkAuth() async {
    state = state.copyWith(isCheckingAuth: true);

    try {
      final sessionResult = await AuthApi.checkSession();

      if (sessionResult == SessionCheckResult.unknown) {
        final userData = await SecureStorage.getUser();
        final role = await SecureStorage.getRole();
        if (userData != null && role != null) {
          final userRole = UserRole.values.firstWhere(
            (r) => r.name == role,
            orElse: () => UserRole.buyer,
          );
          final user = User.fromJson(userData, defaultRole: userRole);
          state = state.copyWith(
            user: user,
            isCheckingAuth: false,
            clearError: true,
          );
          return;
        }
        state = state.copyWith(isCheckingAuth: false, clearError: true);
        return;
      }

      if (sessionResult == SessionCheckResult.valid) {
        // Load user from secure storage
        final userData = await SecureStorage.getUser();
        final role = await SecureStorage.getRole();

        if (userData != null && role != null) {
          final userRole = UserRole.values.firstWhere(
            (r) => r.name == role,
            orElse: () => UserRole.buyer,
          );

          // Try to load role-specific profile
          try {
            Map<String, dynamic> profile = {};
            switch (userRole) {
              case UserRole.buyer:
                profile = await AuthApi.getBuyerProfile();
                break;
              case UserRole.seller:
                profile = await AuthApi.getSellerProfile();
                break;
              case UserRole.rider:
                final storedVerified = userData['isVerified'] == true;
                profile = await AuthApi.fetchRiderProfileForSession(
                  isVerified: storedVerified,
                  email: userData['email']?.toString(),
                  userId: int.tryParse(
                    userData['id']?.toString() ?? userData['userId']?.toString() ?? '',
                  ),
                  givenName: userData['givenName']?.toString(),
                  surname: userData['surname']?.toString(),
                  contactNumber: userData['contactNumber']?.toString(),
                );
                break;
              case UserRole.admin:
                profile = Map<String, dynamic>.from(userData);
                break;
            }
            // Merge profile data with stored user, preserving isVerified
            final mergedUser = {
              ...userData,
              ...profile,
              // Preserve isVerified from stored user data if not in profile
              if (profile['isVerified'] == null && userData['isVerified'] != null)
                'isVerified': userData['isVerified'],
            };
            final user = User.fromJson(mergedUser, defaultRole: userRole);

            state = state.copyWith(
              user: user,
              isCheckingAuth: false,
              clearError: true,
            );
            if (userRole == UserRole.buyer) {
              ref.read(cartProvider.notifier).loadCart();
              ref.read(wishlistProvider.notifier).fetchWishlist();
              await BuyerEngagementMigration.migrateIfNeeded();
              await ref.read(followingStoresProvider.notifier).fetch();
              await ref.read(recentlyViewedProvider.notifier).fetch();
            }
            await ref.read(notificationsProvider.notifier).connectIfAuthenticated();
            await ref.read(chatProvider.notifier).connectIfAuthenticated();
          } catch (e) {
            if (_shouldClearSessionOnProfileError(e)) {
              developer.log(
                'checkAuth: auth error on profile fetch — clearing session',
                name: 'AuthNotifier',
              );
              await SecureStorage.clearAll();
              await ApiClient.clearCookies();
              ref.read(notificationsProvider.notifier).disconnect();
              ref.read(chatProvider.notifier).disconnect();
              state = state.copyWith(isCheckingAuth: false, clearError: true);
              return;
            }
            // For other errors, fall back to stored user data
            final user = User.fromJson(userData, defaultRole: userRole);
            state = state.copyWith(
              user: user,
              isCheckingAuth: false,
              clearError: true,
            );
            if (userRole == UserRole.buyer) {
              ref.read(cartProvider.notifier).loadCart();
              ref.read(wishlistProvider.notifier).fetchWishlist();
              await BuyerEngagementMigration.migrateIfNeeded();
              await ref.read(followingStoresProvider.notifier).fetch();
              await ref.read(recentlyViewedProvider.notifier).fetch();
            }
            await ref.read(notificationsProvider.notifier).connectIfAuthenticated();
            await ref.read(chatProvider.notifier).connectIfAuthenticated();
          }
        } else {
          state = state.copyWith(isCheckingAuth: false, clearError: true);
        }
      } else {
        // Clear stored data if session is invalid
        await SecureStorage.clearAll();
        await ApiClient.clearCookies();
        ref.read(notificationsProvider.notifier).disconnect();
        ref.read(chatProvider.notifier).disconnect();
        state = state.copyWith(isCheckingAuth: false, clearError: true);
      }
    } catch (e) {
      developer.log('checkAuth error: $e', name: 'AuthNotifier', error: e);
      state = state.copyWith(
        isCheckingAuth: false,
        clearError: true,
      );
    }
  }

  /// Login with email and password
  /// Matches Next.js client login behavior
  Future<bool> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    developer.log('Login started for: $email', name: 'AuthNotifier');

    try {
      final response = await AuthApi.login(
        email: email,
        password: password,
        role: role,
      );

      final accessToken = response['access_token'];
      final isVerified = response['is_verified'] == true;
      final userId = response['user_id'];
      final givenName = response['given_name']?.toString();
      final surname = response['surname']?.toString();
      final contactNumber = response['contact_number']?.toString();

      if (accessToken == null) {
        throw Exception("Missing access token in login response");
      }

      await SecureStorage.saveToken(accessToken);

      Map<String, dynamic> profile = {};
      switch (role) {
        case UserRole.rider:
          profile = await AuthApi.fetchRiderProfileForSession(
            isVerified: isVerified,
            email: email,
            userId: userId is int ? userId : int.tryParse('$userId'),
            givenName: givenName,
            surname: surname,
            contactNumber: contactNumber,
          );
          break;
        case UserRole.seller:
          profile = await AuthApi.getSellerProfile();
          break;
        case UserRole.buyer:
          profile = await AuthApi.getBuyerProfile();
          break;
        case UserRole.admin:
          profile = {'email': email, 'isVerified': isVerified};
          break;
      }

      final userData = {
        'email': email,
        'isVerified': isVerified,
        if (userId != null) 'id': userId.toString(),
        if (userId != null) 'userId': userId.toString(),
        ...profile,
        if (profile['id'] == null && userId != null) 'id': userId.toString(),
      };

      final user = User.fromJson(userData, defaultRole: role);

      // Save user data and role
      await SecureStorage.saveUser(user.toJson());
      await SecureStorage.saveRole(role.name);
      await SecureStorage.saveVerificationStatus(isVerified);

      state = state.copyWith(
        user: user,
        token: accessToken,
        isLoading: false,
        clearError: true,
      );

      if (role == UserRole.buyer) {
        await ref.read(cartProvider.notifier).loadCart();
        await ref.read(wishlistProvider.notifier).fetchWishlist();
        await BuyerEngagementMigration.migrateIfNeeded();
        await ref.read(followingStoresProvider.notifier).fetch();
        await ref.read(recentlyViewedProvider.notifier).fetch();
      }

      await ref.read(notificationsProvider.notifier).connectIfAuthenticated();
      await ref.read(chatProvider.notifier).connectIfAuthenticated();

      return true;
    } on Exception catch (e) {
      developer.log('Login error: $e', name: 'AuthNotifier', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Logout user - clears all user data
  Future<void> logout() async {
    // Close realtime sockets before the server invalidates the session.
    try {
      ref.read(notificationsProvider.notifier).disconnect();
    } catch (e) {
      developer.log('Error disconnecting notifications: $e', name: 'AuthNotifier');
    }
    try {
      ref.read(chatProvider.notifier).disconnect();
    } catch (e) {
      developer.log('Error disconnecting chat: $e', name: 'AuthNotifier');
    }

    try {
      await AuthApi.logout();
    } catch (e) {
      // Ignore logout errors
    } finally {
      // Clear secure storage and cookies
      await SecureStorage.clearAll();
      await ApiClient.clearCookies();
      
      // Clear all user data from providers
      try {
        // Local only — session cookies are already cleared.
        ref.read(cartProvider.notifier).clearCartLocal();
      } catch (e) {
        developer.log('Error clearing cart: $e', name: 'AuthNotifier');
      }
      
      try {
        // Clear orders state
        ref.read(ordersProvider.notifier).clearOrders();
      } catch (e) {
        developer.log('Error clearing orders: $e', name: 'AuthNotifier');
      }

      try {
        ref.read(wishlistProvider.notifier).clear();
      } catch (e) {
        developer.log('Error clearing wishlist: $e', name: 'AuthNotifier');
      }

      try {
        ref.read(followingStoresProvider.notifier).clear();
      } catch (e) {
        developer.log('Error clearing following stores: $e', name: 'AuthNotifier');
      }

      try {
        ref.read(recentlyViewedProvider.notifier).clear();
      } catch (e) {
        developer.log('Error clearing recently viewed: $e', name: 'AuthNotifier');
      }

      // Reset auth state
      state = const AuthNotifierState();
      developer.log('Logout complete - all user data cleared', name: 'AuthNotifier');
    }
  }

  /// Reload seller profile from API and update stored user.
  Future<void> refreshSellerProfile() async {
    if (state.user == null || state.user!.role != UserRole.seller) return;
    try {
      final profile = await AuthApi.getSellerProfile();
      final merged = {
        ...state.user!.toJson(),
        ...profile,
        'role': 'seller',
      };
      final isVerified = profile['isVerified'] == true;
      final user = User.fromJson(merged, defaultRole: UserRole.seller);
      await SecureStorage.saveUser(user.toJson());
      await SecureStorage.saveVerificationStatus(isVerified);
      state = state.copyWith(user: user, clearError: true);
    } catch (e) {
      developer.log('refreshSellerProfile: $e', name: 'AuthNotifier');
    }
  }

  /// Reload buyer profile from API and update stored user.
  Future<void> refreshBuyerProfile() async {
    if (state.user == null || state.user!.role != UserRole.buyer) return;
    try {
      final profile = await AuthApi.getBuyerProfile();
      final merged = {
        ...state.user!.toJson(),
        ...profile,
        if (profile['address'] != null) 'address': profile['address'],
      };
      final user = User.fromJson(merged, defaultRole: UserRole.buyer);
      await SecureStorage.saveUser(user.toJson());
      state = state.copyWith(user: user, clearError: true);
    } catch (e) {
      developer.log('refreshBuyerProfile: $e', name: 'AuthNotifier');
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Register a new buyer
  Future<bool> registerBuyer({
    required String givenName,
    required String surname,
    required String email,
    required String password,
    required String contactNumber,
    required AddressData address,
    File? validId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await AuthApi.registerBuyer(
        givenName: givenName,
        surname: surname,
        email: email,
        password: password,
        contactNumber: contactNumber,
        address: address,
        validId: validId,
      );

      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Register a new seller
  Future<bool> registerSeller({
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
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await AuthApi.registerSeller(
        givenName: givenName,
        surname: surname,
        email: email,
        password: password,
        contactNumber: contactNumber,
        shopName: shopName,
        tagline: tagline,
        description: description,
        categories: categories,
        address: address,
        logo: logo,
        documents: documents,
      );

      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Register a new rider
  Future<bool> registerRider({
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
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await AuthApi.registerRider(
        givenName: givenName,
        surname: surname,
        email: email,
        password: password,
        contactNumber: contactNumber,
        vehicleType: vehicleType,
        licenseNumber: licenseNumber,
        address: address,
        license: license,
        orCr: orCr,
      );

      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Get dashboard route based on user role
  String getDashboardRoute() {
    switch (state.user?.role) {
      case UserRole.buyer:
        return '/home';
      case UserRole.seller:
        return state.isVerified ? '/seller' : '/seller/account';
      case UserRole.rider:
        return '/rider';
      case UserRole.admin:
        return '/admin';
      default:
        return '/landing';
    }
  }
}

/// Riverpod provider for authentication
final authProvider = StateNotifierProvider<AuthNotifier, AuthNotifierState>((ref) {
  return AuthNotifier(ref);
});

/// Provider for quick access to authentication status
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Provider for quick access to current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Provider for quick access to current role
final currentRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider).role;
});

/// Provider for quick access to auth loading state
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

/// Provider for quick access to auth error
final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});
