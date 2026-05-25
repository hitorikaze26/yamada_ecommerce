import 'dart:developer' as developer;

/// Production-safe environment configuration.
///
/// Resolution order (highest priority first):
/// 1. `--dart-define=API_BASE_URL=...` (build-time, safe for release builds)
/// 2. `dotenv.env['API_BASE_URL']` (local dev only, bundled in debug builds)
/// 3. Hardcoded default (local dev fallback)
///
/// In production (release mode) only #1 is used — .env is never bundled.
class EnvConfig {
  EnvConfig._();

  static const _defaultApiBaseUrl = 'http://10.0.2.2:5000/api';

  static String? _dartDefineUrl;
  static String? _dotEnvUrl;

  /// Must be called once at app startup (from main).
  static void init({
    String? dartDefineUrl,
    String? dotEnvUrl,
  }) {
    _dartDefineUrl = dartDefineUrl;
    _dotEnvUrl = dotEnvUrl;
    developer.log(
      'EnvConfig initialized — API_BASE_URL: $apiBaseUrl${_inProd ? " (PROD)" : ""}',
      name: 'EnvConfig',
    );
  }

  /// The resolved API base URL.
  static String get apiBaseUrl {
    if (_dartDefineUrl != null && _dartDefineUrl!.isNotEmpty) {
      return _dartDefineUrl!;
    }
    if (_dotEnvUrl != null && _dotEnvUrl!.isNotEmpty) {
      return _dotEnvUrl!;
    }
    return _defaultApiBaseUrl;
  }

  /// Base origin (scheme + host + port) derived from apiBaseUrl.
  static String get baseOrigin => apiBaseUrl.replaceAll('/api', '');

  /// True if running in a release build.
  static bool get _inProd =>
      const bool.fromEnvironment('dart.vm.product');

  /// Supabase Storage public URL pattern (for direct image access).
  static String? get supabaseStorageUrl {
    return const String.fromEnvironment(
      'SUPABASE_STORAGE_URL',
      defaultValue: '',
    ).nullIfEmpty;
  }

  /// PSGC geographic API base URL.
  static String get phSggBaseUrl {
    return const String.fromEnvironment(
      'PH_SGG_BASE_URL',
      defaultValue: 'https://psgc.gitlab.io/api',
    ).nullIfEmpty ?? 'https://psgc.gitlab.io/api';
  }

  /// Share base URL for product/listing sharing links (Vercel web URL).
  static String? get shareBaseUrl {
    return const String.fromEnvironment(
      'APP_SHARE_BASE_URL',
      defaultValue: '',
    ).nullIfEmpty;
  }

  /// The Railway-hosted Flask API base URL (production).
  /// Passed via --dart-define during release builds.
  static String get productionApiBaseUrl {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    ).nullIfEmpty ?? '';
  }

  static bool get hasProductionApiUrl =>
      productionApiBaseUrl.isNotEmpty;

  /// Whether to log verbose Dio traffic (off in release builds).
  static bool get enableDebugLogging => !_inProd;

  /// Environment label for display.
  static String get label {
    if (hasProductionApiUrl) return 'production';
    if (_dartDefineUrl != null) return 'staging';
    return 'development';
  }
}

extension _StringNullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
