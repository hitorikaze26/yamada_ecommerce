import 'dart:developer' as developer;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env_config.dart';

typedef ChatMessageCallback = void Function(Map<String, dynamic> payload);
typedef ChatReadCallback = void Function(Map<String, dynamic> payload);
typedef ChatPresenceCallback = void Function(Map<String, dynamic> payload);

class ChatSocketService {
  io.Socket? _socket;
  ChatMessageCallback? _onMessage;
  ChatReadCallback? _onRead;
  ChatPresenceCallback? _onPresence;
  String? _token;

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
    ChatMessageCallback? onMessage,
    ChatReadCallback? onRead,
    ChatPresenceCallback? onPresence,
  }) {
    if (_socket?.connected == true && _token == token) {
      _onMessage = onMessage;
      _onRead = onRead;
      _onPresence = onPresence;
      return;
    }
    disconnect();
    _token = token;
    _onMessage = onMessage;
    _onRead = onRead;
    _onPresence = onPresence;

    final url = socketBaseUrl();
    developer.log('ChatSocket connecting to $url', name: 'ChatSocket');

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
      developer.log('ChatSocket connected', name: 'ChatSocket');
    });

    _socket!.on('chat_message', (data) {
      if (data is Map) {
        _onMessage?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('chat_read', (data) {
      if (data is Map) {
        _onRead?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('chat_presence', (data) {
      if (data is Map) {
        _onPresence?.call(Map<String, dynamic>.from(data));
      }
    });
  }

  void joinConversation(int conversationId) {
    _socket?.emit('join_conversation', {'conversationId': conversationId});
  }

  void pingPresence() {
    _socket?.emit('chat_presence_ping');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _token = null;
    _onMessage = null;
    _onRead = null;
    _onPresence = null;
  }
}
