import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Network debugging utility
/// Helps diagnose connection issues between Flutter app and backend
class NetworkDebug {
  /// Log current API configuration
  static void logConfig() {
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'NOT SET';
    final phGeoUrl = dotenv.env['PH_SGG_BASE_URL'] ?? 'NOT SET';
    
    developer.log('═' * 50, name: 'NetworkDebug');
    developer.log('API Configuration:', name: 'NetworkDebug');
    developer.log('  API_BASE_URL: $apiUrl', name: 'NetworkDebug');
    developer.log('  PH_SGG_BASE_URL: $phGeoUrl', name: 'NetworkDebug');
    developer.log('═' * 50, name: 'NetworkDebug');
  }

  /// Test if backend is reachable
  static Future<bool> testBackendConnection() async {
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api';
    final baseUrl = apiUrl.replaceAll('/api', '');
    
    developer.log('Testing connection to: $baseUrl', name: 'NetworkDebug');
    
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      final request = await client.getUrl(Uri.parse(baseUrl));
      final response = await request.close();
      
      developer.log('Connection test: HTTP ${response.statusCode}', name: 'NetworkDebug');
      return response.statusCode == 200;
    } catch (e) {
      developer.log('Connection test FAILED: $e', name: 'NetworkDebug');
      return false;
    }
  }

  /// Check if running on emulator
  static bool get isEmulator {
    return Platform.isAndroid && 
           (dotenv.env['API_BASE_URL']?.contains('10.0.2.2') ?? false);
  }

  /// Check if running on physical device (likely)
  static bool get isPhysicalDevice {
    if (kIsWeb) return false;
    final apiUrl = dotenv.env['API_BASE_URL'] ?? '';
    return apiUrl.contains('192.168.') || apiUrl.contains('10.0.') && !apiUrl.contains('10.0.2.2');
  }

  /// Get recommended configuration based on platform
  static String getRecommendedConfig() {
    if (Platform.isAndroid) {
      if (isEmulator) {
        return 'Emulator detected. Using 10.0.2.2 should work.';
      } else {
        return '''
Physical Android device detected.
ACTION REQUIRED:
1. Find your PC's IP: Open Command Prompt, run: ipconfig
2. Look for IPv4 Address (e.g., 192.168.1.100)
3. Update .env file: API_BASE_URL=http://YOUR_IP:5000/api
4. Ensure phone and PC are on SAME Wi-Fi network
5. Restart Flask backend to bind to 0.0.0.0 (not localhost)
   Run: flask run --host=0.0.0.0 --port=5000
6. Rebuild and reinstall app: flutter clean && flutter run
        ''';
      }
    } else if (Platform.isIOS) {
      return 'iOS detected. Use localhost for simulator, or your Mac\'s IP for physical device.';
    }
    return 'Unknown platform';
  }
}
