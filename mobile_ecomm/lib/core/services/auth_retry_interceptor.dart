import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'secure_storage.dart';
import 'api_client.dart';

/// Dio interceptor that orchestrates token refresh on 401.
///
/// Design:
/// - Catches 401 from non-auth endpoints
/// - Acquires a global refresh lock (prevents concurrent /accounts/refresh calls)
/// - Calls `POST /accounts/refresh` with the current Bearer token
/// - On success: updates stored token, replays the failed request
/// - On failure: clears session, calls onSessionExpired
/// - Infinite-loop safe: never retries the refresh endpoint itself
class AuthRetryInterceptor extends Interceptor {
  static bool _isRefreshing = false;
  static final List<_PendingRequest> _pendingRequests = [];

  /// Maximum number of consecutive refresh attempts before giving up.
  static const int _maxRetries = 1;

  /// Called when refresh fails and session must be cleared.
  static void Function()? onRefreshFailed;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final statusCode = err.response?.statusCode;
    final requestPath = requestOptions.path;

    // Only handle 401 from non-auth, non-refresh endpoints
    if (statusCode != 401) {
      return handler.next(err);
    }

    if (_isAuthEndpoint(requestPath)) {
      return handler.next(err);
    }

    if (_isRefreshEndpoint(requestPath)) {
      return handler.next(err);
    }

    developer.log(
      'AuthRetryInterceptor: 401 on $requestPath — attempting refresh',
      name: 'AuthRetry',
    );

    // Check if we have a token to refresh with
    final currentToken = await SecureStorage.getToken();
    if (currentToken == null || currentToken.isEmpty) {
      developer.log(
        'AuthRetryInterceptor: no token stored — session expired',
        name: 'AuthRetry',
      );
      _clearSession();
      return handler.next(err);
    }

    // If another request is already refreshing, queue this one
    if (_isRefreshing) {
      developer.log(
        'AuthRetryInterceptor: refresh in progress — queuing request',
        name: 'AuthRetry',
      );
      return _addPendingRequest(
        requestOptions,
        err,
        handler,
      );
    }

    // Attempt refresh
    _isRefreshing = true;
    try {
      final success = await _tryRefreshToken();
      if (success) {
        _isRefreshing = false;
        // Retry all queued requests + this one
        await _retryOriginalRequest(requestOptions, handler);
        _flushPendingRequests();
      } else {
        _isRefreshing = false;
        _failPendingRequests(err);
        _clearSession();
        return handler.next(err);
      }
    } catch (e) {
      _isRefreshing = false;
      _failPendingRequests(
        DioException(
          requestOptions: requestOptions,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
      _clearSession();
      return handler.next(err);
    }
  }

  /// POST /accounts/refresh with the current Bearer token.
  static Future<bool> _tryRefreshToken() async {
    try {
      final dio = await ApiClient.getInstance(refreshOnly: true);
      final token = await SecureStorage.getToken();

      if (token == null || token.isEmpty) return false;

      developer.log(
        'AuthRetryInterceptor: calling /accounts/refresh',
        name: 'AuthRetry',
      );

      final response = await dio.post(
        '/accounts/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          // Don't trigger CSRF for refresh
          extra: {'skipCsrf': true},
        ),
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'] as String?;
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await SecureStorage.saveToken(newAccessToken);
          developer.log(
            'AuthRetryInterceptor: token refreshed successfully',
            name: 'AuthRetry',
          );
          return true;
        }
      }

      developer.log(
        'AuthRetryInterceptor: refresh returned ${response.statusCode}',
        name: 'AuthRetry',
      );
      return false;
    } on DioException catch (e) {
      developer.log(
        'AuthRetryInterceptor: refresh failed — ${e.response?.statusCode} ${e.message}',
        name: 'AuthRetry',
      );
      return false;
    } catch (e) {
      developer.log(
        'AuthRetryInterceptor: refresh error — $e',
        name: 'AuthRetry',
      );
      return false;
    }
  }

  /// Retry the original failed request with the new token.
  static Future<void> _retryOriginalRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final dio = await ApiClient.getInstance(refreshOnly: true);
      final token = await SecureStorage.getToken();

      // Clone the original request options and update the auth header
      final retryOptions = requestOptions.copyWith(
        headers: {
          ...requestOptions.headers,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final response = await dio.fetch(retryOptions);
      handler.resolve(response);
    } catch (e) {
      developer.log(
        'AuthRetryInterceptor: retry failed — $e',
        name: 'AuthRetry',
      );
      // If retry also fails, create a 401 error
      handler.next(
        DioException(
          requestOptions: requestOptions,
          error: e,
          type: DioExceptionType.unknown,
          response: e is DioException ? e.response : null,
        ),
      );
    }
  }

  static void _addPendingRequest(
    RequestOptions requestOptions,
    DioException error,
    ErrorInterceptorHandler handler,
  ) {
    _pendingRequests.add(_PendingRequest(
      requestOptions: requestOptions,
      handler: handler,
    ));
  }

  static void _flushPendingRequests() async {
    final pending = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final req in pending) {
      await _retryOriginalRequest(req.requestOptions, req.handler);
    }
  }

  static void _failPendingRequests(DioException baseError) {
    final pending = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final req in pending) {
      req.handler.next(baseError);
    }
  }

  static void _clearSession() async {
    await SecureStorage.clearAll();
    await ApiClient.clearCookies();
    onRefreshFailed?.call();
  }

  static bool _isAuthEndpoint(String path) {
    return path.contains('/accounts/login') ||
        path.contains('/accounts/register') ||
        path.contains('/accounts/forgot-password') ||
        path.contains('/accounts/verify-pin') ||
        path.contains('/accounts/reset-password');
  }

  static bool _isRefreshEndpoint(String path) {
    return path.contains('/accounts/refresh');
  }
}

class _PendingRequest {
  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;

  _PendingRequest({
    required this.requestOptions,
    required this.handler,
  });
}
