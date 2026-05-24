import 'dart:io';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

/// API Client configuration for YAMADA backend integration
/// Handles JWT cookies, CSRF tokens, and request/response interceptors
class ApiClient {
  static Dio? _dio;
  static PersistCookieJar? _cookieJar;

  /// Called when a protected API returns 401 (expired/invalid session).
  /// Registered by [AuthNotifier] to clear local auth state.
  static void Function()? onSessionExpired;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _lastUrlKey = 'yamada_last_api_url';

  /// Get the configured Dio instance
  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api';

    developer.log('ApiClient initializing with baseUrl: $baseUrl',
        name: 'ApiClient');

    // If the base URL changed since last run, wipe stale cookies so the
    // old host's JWT is not sent to the new host (causes 401).
    final lastUrl = await _storage.read(key: _lastUrlKey);
    if (lastUrl != null && lastUrl != baseUrl) {
      developer.log(
        'ApiClient: base URL changed ($lastUrl → $baseUrl), clearing cookies',
        name: 'ApiClient',
      );
      // Delete cookie files directly before the jar is initialised
      final directory = await getApplicationDocumentsDirectory();
      final cookieDir = Directory('${directory.path}/.cookies/');
      if (await cookieDir.exists()) {
        await cookieDir.delete(recursive: true);
      }
    }
    await _storage.write(key: _lastUrlKey, value: baseUrl);

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Initialize cookie jar for persistent cookie storage
    _cookieJar = await _initCookieJar();
    _dio!.interceptors.add(CookieManager(_cookieJar!));

    // Request interceptor: Bearer JWT (mobile) + CSRF for mutating requests.
    // Login returns `access_token` in JSON and stores it in [SecureStorage];
    // cookies may not be present or sent reliably on Android/iOS, while the
    // backend accepts JWT via Authorization (see JWT_TOKEN_LOCATION).
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = options.path;
        final isAuthAnonymous = path.contains('/accounts/login') ||
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

        final method = options.method.toLowerCase();
        if (['post', 'put', 'patch', 'delete'].contains(method)) {
          final csrfToken = await _getCsrfToken();
          if (csrfToken != null) {
            options.headers['X-CSRF-TOKEN'] = csrfToken;
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized
        if (error.response?.statusCode == 401) {
          final requestUrl = error.requestOptions.path;

          // Let auth endpoints handle their own 401s
          if (requestUrl.contains('/accounts/login') ||
              requestUrl.contains('/accounts/protected')) {
            handler.next(error);
            return;
          }

          developer.log(
            'ApiClient: 401 on $requestUrl — clearing session',
            name: 'ApiClient',
          );
          await _cookieJar?.deleteAll();
          await SecureStorage.deleteToken();
          onSessionExpired?.call();
        }

        // Handle 403 on role-protected endpoints — stale JWT claims.
        // Clear cookies so the next checkAuth forces a fresh login.
        if (error.response?.statusCode == 403) {
          final requestUrl = error.requestOptions.path;
          // Only clear for role-gated API paths, not auth endpoints
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

    // Logging interceptor for debugging (only in debug mode)
    if (const bool.fromEnvironment('dart.vm.product') != true) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('[API] $obj'),
      ));
    }

    return _dio!;
  }

  /// Initialize persistent cookie jar
  static Future<PersistCookieJar> _initCookieJar() async {
    final directory = await getApplicationDocumentsDirectory();
    final cookiePath = '${directory.path}/.cookies/';

    // Ensure directory exists
    await Directory(cookiePath).create(recursive: true);

    return PersistCookieJar(
      storage: FileStorage(cookiePath),
      ignoreExpires: false,
    );
  }

  /// Extract CSRF token from cookies
  static Future<String?> _getCsrfToken() async {
    if (_cookieJar == null) return null;

    final uri = Uri.parse(dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api');
    final cookies = await _cookieJar!.loadForRequest(uri);

    // Look for CSRF token cookie (Flask-JWT-Extended uses csrf_access_token)
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
    // Also clear the stored URL so next init doesn't skip the stale-check
    await _storage.delete(key: _lastUrlKey);
  }

  /// Reset the Dio client (useful after changing .env config)
  static void reset() {
    developer.log('ApiClient reset called', name: 'ApiClient');
    _dio = null;
    _cookieJar = null;
  }

  /// Get API base URL origin (for resolving image URLs)
  static String get baseOrigin {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api';
    return baseUrl.replaceAll('/api', '');
  }

  /// Resolve image URL from backend path
  static String? resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // If already a full URL, return as-is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Normalize path separators (Windows backslashes to forward slashes)
    String normalizedUrl = url.replaceAll('\\', '/');

    // If starts with /static/, prepend base origin
    if (normalizedUrl.startsWith('/static/')) {
      return '$baseOrigin$normalizedUrl';
    }

    // Handle relative paths like "product_images/filename.jpg"
    // by prepending /static/
    if (normalizedUrl.contains('/') && !normalizedUrl.startsWith('/')) {
      return '$baseOrigin/static/$normalizedUrl';
    }

    // Handle legacy paths or simple filenames
    if (!normalizedUrl.startsWith('/')) {
      return '$baseOrigin/static/product_images/$normalizedUrl';
    }

    return normalizedUrl;
  }
}
