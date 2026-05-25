import 'dart:developer' as developer;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env_config.dart';

typedef NotificationSocketCallback = void Function(Map<String, dynamic> payload);
typedef NotificationsReadCallback = void Function(Map<String, dynamic>? payload);

/// Manages the Socket.IO connection for realtime notifications.
class NotificationSocketService {
  io.Socket? _socket;
  NotificationSocketCallback? _onNotification;
  NotificationsReadCallback? _onNotificationsRead;

  static String socketBaseUrl() {
    final apiBase = EnvConfig.apiBaseUrl;
    final uri = Uri.parse(apiBase);
    if (uri.hasPort) {
      return '${uri.scheme}://${uri.host}:${uri.port}';
    }
    return '${uri.scheme}://${uri.host}';
  }

  bool get isConnected => _socket?.connected ?? false;

  void connect({
    required String token,
    required NotificationSocketCallback onNotification,
    NotificationsReadCallback? onNotificationsRead,
  }) {
    disconnect();
    _onNotification = onNotification;
    _onNotificationsRead = onNotificationsRead;

    final url = socketBaseUrl();
    developer.log('NotificationSocket connecting to $url', name: 'NotificationSocket');

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .disableReconnection()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      developer.log('NotificationSocket connected', name: 'NotificationSocket');
    });

    _socket!.onDisconnect((_) {
      developer.log('NotificationSocket disconnected', name: 'NotificationSocket');
    });

    _socket!.on('notification', (data) {
      if (data is Map) {
        _onNotification?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('notifications_read', (data) {
      if (data is Map) {
        _onNotificationsRead?.call(Map<String, dynamic>.from(data));
      } else {
        _onNotificationsRead?.call(null);
      }
    });

    _socket!.onConnectError((err) {
      developer.log('NotificationSocket connect error: $err',
          name: 'NotificationSocket');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _onNotification = null;
    _onNotificationsRead = null;
  }
}
