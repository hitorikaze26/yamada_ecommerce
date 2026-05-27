import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/config/env_config.dart';
import 'data/providers/auth_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env for local development (not bundled in release builds)
  await dotenv.load();

  // Initialize production-safe environment config
  // Resolution: --dart-define > .env > hardcoded default
  final dartDefineUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  EnvConfig.init(
    dartDefineUrl: dartDefineUrl.isNotEmpty ? dartDefineUrl : null,
    dotEnvUrl: dotenv.env['API_BASE_URL'],
    dotEnvSupabaseUrl: dotenv.env['SUPABASE_STORAGE_URL'],
  );

  // Log configuration for debugging
  developer.log('═══════════════════════════════════════', name: 'YAMADA');
  developer.log('ENV: ${EnvConfig.label}', name: 'YAMADA');
  developer.log('API_BASE_URL: ${EnvConfig.apiBaseUrl}', name: 'YAMADA');
  developer.log('SUPABASE_STORAGE_URL: ${EnvConfig.supabaseStorageUrl}', name: 'YAMADA');
  developer.log('PH_SGG_BASE_URL: ${EnvConfig.phSggBaseUrl}', name: 'YAMADA');
  developer.log('═══════════════════════════════════════', name: 'YAMADA');

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: YamadaApp(),
    ),
  );
}

class YamadaApp extends ConsumerWidget {
  const YamadaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'YAMADA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.createRouter(ref),
    );
  }
}
