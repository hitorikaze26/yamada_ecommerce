import 'dart:io';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env_config.dart';
import 'secure_storage.dart';
import 'auth_retry_interceptor.dart';

/// API Client configuration for YAMADA backend integration
/// Handles JWT Bearer, CSRF tokens, cookie persistence, and token refresh.
class ApiClient {
  static Dio? _dio;
  static Dio? _refreshDio;
  static PersistCookieJar? _cookieJar;

  /// Called when session is fully expired (refresh also failed).
  /// Registered by [AuthNotifier] to clear local auth state.
  static void Function()? onSessionExpired;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _lastUrlKey = 'yamada_last_api_url';

  /// Get the configured Dio instance.
  ///
  /// If [refreshOnly] is true, returns a lightweight instance without
  /// the full interceptor chain (used internally by AuthRetryInterceptor
  /// to avoid circular retry loops).
  static Future<Dio> getInstance({bool refreshOnly = false}) async {
    if (refreshOnly) {
      if (_refreshDio != null) return _refreshDio!;
      _refreshDio = _buildBaseDio();
      return _refreshDio!;
    }

    if (_dio != null) return _dio!;

    final baseUrl = EnvConfig.apiBaseUrl;

    developer.log('ApiClient initializing with baseUrl: $baseUrl',
        name: 'ApiClient');

    // If the base URL changed since last run, wipe stale cookies
    final lastUrl = await _storage.read(key: _lastUrlKey);
    if (lastUrl != null && lastUrl != baseUrl) {
      developer.log(
        'ApiClient: base URL changed ($lastUrl → $baseUrl), clearing cookies',
        name: 'ApiClient',
      );
      final directory = await getApplicationDocumentsDirectory();
      final cookieDir = Directory('${directory.path}/.cookies/');
      if (await cookieDir.exists()) {
        await cookieDir.delete(recursive: true);
      }
    }
    await _storage.write(key: _lastUrlKey, value: baseUrl);

    _dio = _buildBaseDio();

    // Initialize cookie jar for persistent cookie storage
    _cookieJar = await _initCookieJar();
    _dio!.interceptors.add(CookieManager(_cookieJar!));

    // Auth retry interceptor — handles 401 → refresh → retry
    AuthRetryInterceptor.onRefreshFailed = () {
      onSessionExpired?.call();
    };
    _dio!.interceptors.add(AuthRetryInterceptor());

    // Request interceptor: Bearer JWT + CSRF for mutating requests.
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = options.path;
        final skipCsrf = options.extra['skipCsrf'] == true;
        final isAuthAnonymous =
            path.contains('/accounts/login') ||
            path.contains('/accounts/register') ||
            path.contains('/accounts/forgot-password') ||
            path.contains('/accounts/verify-pin') ||
            path.contains('/accounts/reset-password');

        if (!isAuthAnonymous) {
          final token = await SecureStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        if (!skipCsrf) {
          final method = options.method.toLowerCase();
          if (['post', 'put', 'patch', 'delete'].contains(method)) {
            final csrfToken = await _getCsrfToken();
            if (csrfToken != null) {
              options.headers['X-CSRF-TOKEN'] = csrfToken;
            }
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) async {
        // Handle 403 on role-protected endpoints
        if (error.response?.statusCode == 403) {
          final requestUrl = error.requestOptions.path;
          if (!requestUrl.contains('/accounts/')) {
            developer.log(
              'ApiClient: 403 on $requestUrl — clearing stale cookies',
              name: 'ApiClient',
            );
            await _cookieJar?.deleteAll();
          }
        }
        handler.next(error);
      },
    ));

    // Logging interceptor (debug builds only)
    if (EnvConfig.enableDebugLogging) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('[API] $obj'),
      ));
    }

    return _dio!;
  }

  static Dio _buildBaseDio() {
    return Dio(BaseOptions(
      baseUrl: EnvConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// Initialize persistent cookie jar
  static Future<PersistCookieJar> _initCookieJar() async {
    final directory = await getApplicationDocumentsDirectory();
    final cookiePath = '${directory.path}/.cookies/';
    await Directory(cookiePath).create(recursive: true);

    return PersistCookieJar(
      storage: FileStorage(cookiePath),
      ignoreExpires: false,
    );
  }

  /// Extract CSRF token from cookies
  static Future<String?> _getCsrfToken() async {
    if (_cookieJar == null) return null;

    final uri = Uri.parse(EnvConfig.apiBaseUrl);
    final cookies = await _cookieJar!.loadForRequest(uri);

    for (final cookie in cookies) {
      if (cookie.name == 'csrf_access_token' || cookie.name == 'access_csrf') {
        return cookie.value;
      }
    }
    return null;
  }

  /// Clear all cookies (used on logout)
  static Future<void> clearCookies() async {
    if (_cookieJar != null) {
      await _cookieJar!.deleteAll();
    }
    await _storage.delete(key: _lastUrlKey);
  }

  /// Reset the Dio client (useful after env config change)
  static void reset() {
    developer.log('ApiClient reset called', name: 'ApiClient');
    _dio = null;
    _refreshDio = null;
    _cookieJar = null;
  }

  /// Get API base URL origin (for resolving image URLs)
  static String get baseOrigin => EnvConfig.baseOrigin;

  /// Resolve image URL from backend path.
  ///
  /// The backend already resolves paths to full Supabase public URLs
  /// in API responses (via `public_url_for_stored_path`). This method
  /// handles edge cases:
  /// - Already absolute HTTPS URLs (Supabase public URLs) → pass through
  /// - `/static/...` paths (legacy dev) → prepend base origin
  /// - Relative DB paths → try Supabase Storage URL + bucket mapping
  static String? resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Already absolute — return as-is (Supabase public URLs from backend)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Normalize separators
    String normalized = url.replaceAll('\\', '/');

    // Legacy development paths
    if (normalized.startsWith('/static/')) {
      return '${EnvConfig.baseOrigin}$normalized';
    }

    // Supabase storage direct resolution (relative DB paths like
    // "product_images/uuid.jpg" or "avatars/uuid.jpg")
    final storageUrl = EnvConfig.supabaseStorageUrl;
    if (storageUrl != null && storageUrl.isNotEmpty) {
      final bucket = _inferBucket(normalized);
      if (bucket != null) {
        return '$storageUrl/$bucket/$normalized';
      }
      return '$storageUrl/$normalized';
    }

    // Fallback to /static/ relative path
    if (normalized.contains('/') && !normalized.startsWith('/')) {
      return '${EnvConfig.baseOrigin}/static/$normalized';
    }

    // Simple filename
    if (!normalized.startsWith('/')) {
      return '${EnvConfig.baseOrigin}/static/product_images/$normalized';
    }

    return normalized;
  }

  /// Map folder prefix to Supabase bucket name.
  static String? _inferBucket(String path) {
    final folder = path.split('/').first;
    switch (folder) {
      case 'product_images':
      case 'product_videos':
        return 'product-images';
      case 'avatars':
      case 'seller_avatars':
      case 'rider_avatars':
      case 'seller_banners':
        return 'avatars';
      case 'chat_uploads':
        return 'chat';
      case 'buyer_ids':
      case 'seller_ids':
      case 'seller_dti':
      case 'seller_permits':
      case 'seller_bir':
      case 'rider_docs':
      case 'report_evidence':
      case 'proof_photos':
        return 'docs';
      default:
        return 'misc';
    }
  }
}
