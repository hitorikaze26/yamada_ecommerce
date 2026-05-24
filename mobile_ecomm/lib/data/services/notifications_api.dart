import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';

class NotificationsApi {
  static Future<List<Map<String, dynamic>>> list({
    String? role,
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/notifications',
      queryParameters: {
        if (role != null) 'role': role,
        if (unreadOnly) 'unreadOnly': 'true',
        'limit': limit,
      },
    );
    final list = response.data['notifications'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<int> unreadCount({String? role}) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/notifications/unread-count',
      queryParameters: {if (role != null) 'role': role},
    );
    return (response.data['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> markRead(int notificationId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/notifications/$notificationId/mark-read');
  }

  static Future<void> markAllRead({String? role}) async {
    final dio = await ApiClient.getInstance();
    await dio.post(
      '/notifications/mark-all-read',
      data: {if (role != null) 'role': role},
    );
  }
}
