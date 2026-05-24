import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'data/providers/auth_notifier.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();
  
  // Log configuration for debugging
  final apiUrl = dotenv.env['API_BASE_URL'];
  final geoUrl = dotenv.env['PH_SGG_BASE_URL'] ?? 'https://psgc.gitlab.io/api';
  developer.log('═══════════════════════════════════════', name: 'YAMADA');
  if (apiUrl == null || apiUrl.isEmpty) {
    developer.log(
      'WARNING: API_BASE_URL not set in .env — copy .env.example and set your LAN IP or 10.0.2.2',
      name: 'YAMADA',
    );
  } else {
    developer.log('API_BASE_URL: $apiUrl', name: 'YAMADA');
  }
  developer.log('PH_SGG_BASE_URL: $geoUrl', name: 'YAMADA');
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
