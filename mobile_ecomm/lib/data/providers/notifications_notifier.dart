import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/notification_socket_service.dart';
import '../../core/services/secure_storage.dart';
import '../models/notification_model.dart';
import '../services/notifications_api.dart';
import 'auth_notifier.dart';

class NotificationsState {
  final List<AppNotification> items;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this.ref) : super(const NotificationsState());

  final Ref ref;
  final NotificationSocketService _socket = NotificationSocketService();
  String? _connectedRole;

  Future<void> connectIfAuthenticated() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.user == null) {
      disconnect();
      return;
    }

    final token = auth.token ?? await SecureStorage.getToken();
    if (token == null || token.isEmpty) return;

    final role = auth.role?.name;
    _connectedRole = role;

    _socket.connect(
      token: token,
      onNotification: _onSocketNotification,
      onNotificationsRead: (_) => refreshUnreadCount(),
    );

    await refreshUnreadCount();
  }

  void disconnect() {
    _socket.disconnect();
    _connectedRole = null;
    state = const NotificationsState();
  }

  void _onSocketNotification(Map<String, dynamic> payload) {
    try {
      final notification = AppNotification.fromJson(payload);
      final role = _connectedRole;
      if (role != null &&
          notification.role != null &&
          notification.role!.toLowerCase() != role) {
        return;
      }

      final existing = state.items.any((n) => n.id == notification.id);
      final items = existing
          ? state.items
          : [notification, ...state.items];

      final unread = notification.read
          ? state.unreadCount
          : state.unreadCount + (existing ? 0 : 1);

      state = state.copyWith(
        items: items,
        unreadCount: unread,
        clearError: true,
      );
    } catch (e) {
      developer.log('Socket notification parse error: $e',
          name: 'NotificationsNotifier');
      refreshUnreadCount();
    }
  }

  Future<void> load() async {
    final role = ref.read(authProvider).role?.name;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final rows = await NotificationsApi.list(role: role);
      final items = rows.map(AppNotification.fromJson).toList();
      state = state.copyWith(items: items, isLoading: false, clearError: true);
      await refreshUnreadCount();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> refreshUnreadCount() async {
    final role = ref.read(authProvider).role?.name;
    try {
      final count = await NotificationsApi.unreadCount(role: role);
      state = state.copyWith(unreadCount: count, clearError: true);
    } catch (e) {
      developer.log('unread count error: $e', name: 'NotificationsNotifier');
    }
  }

  Future<void> markRead(int notificationId) async {
    try {
      await NotificationsApi.markRead(notificationId);
      final items = state.items.map((n) {
        if (n.id == notificationId && !n.read) {
          return n.copyWith(read: true);
        }
        return n;
      }).toList();
      final wasUnread =
          state.items.any((n) => n.id == notificationId && !n.read);
      state = state.copyWith(
        items: items,
        unreadCount: wasUnread && state.unreadCount > 0
            ? state.unreadCount - 1
            : state.unreadCount,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> markAllRead() async {
    final role = ref.read(authProvider).role?.name;
    try {
      await NotificationsApi.markAllRead(role: role);
      final items =
          state.items.map((n) => n.copyWith(read: true)).toList();
      state = state.copyWith(items: items, unreadCount: 0, clearError: true);
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
