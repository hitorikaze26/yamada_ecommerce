import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/chat_socket_service.dart';
import '../../core/services/secure_storage.dart';
import '../../core/utils/chat_preview_text.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/pending_order_share.dart';
import '../services/chat_api.dart';
import 'auth_notifier.dart';

class ChatState {
  final List<ConversationModel> conversations;
  final int unreadTotal;
  final bool isLoadingList;
  final String? listError;
  final int threadTick;

  const ChatState({
    this.conversations = const [],
    this.unreadTotal = 0,
    this.isLoadingList = false,
    this.listError,
    this.threadTick = 0,
  });

  ChatState copyWith({
    List<ConversationModel>? conversations,
    int? unreadTotal,
    bool? isLoadingList,
    String? listError,
    int? threadTick,
    bool clearError = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      unreadTotal: unreadTotal ?? this.unreadTotal,
      isLoadingList: isLoadingList ?? this.isLoadingList,
      listError: clearError ? null : (listError ?? this.listError),
      threadTick: threadTick ?? this.threadTick,
    );
  }
}

class ThreadState {
  final List<ChatMessageModel> messages;
  final ConversationModel? conversation;
  final ChatPeer? peer;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final int? nextCursor;
  final String? error;
  final ChatMessageModel? replyTo;
  final PendingOrderShare? pendingOrderShare;

  const ThreadState({
    this.messages = const [],
    this.conversation,
    this.peer,
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
    this.replyTo,
    this.pendingOrderShare,
  });

  ThreadState copyWith({
    List<ChatMessageModel>? messages,
    ConversationModel? conversation,
    ChatPeer? peer,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    int? nextCursor,
    String? error,
    ChatMessageModel? replyTo,
    PendingOrderShare? pendingOrderShare,
    bool clearReply = false,
    bool clearPendingOrderShare = false,
    bool clearError = false,
  }) {
    return ThreadState(
      messages: messages ?? this.messages,
      conversation: conversation ?? this.conversation,
      peer: peer ?? this.peer,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
      replyTo: clearReply ? null : (replyTo ?? this.replyTo),
      pendingOrderShare: clearPendingOrderShare
          ? null
          : (pendingOrderShare ?? this.pendingOrderShare),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this.ref) : super(const ChatState());

  final Ref ref;
  final ChatSocketService _socket = ChatSocketService();
  final Map<int, ThreadState> _threads = {};

  void _tickThreads() {
    state = state.copyWith(threadTick: state.threadTick + 1);
  }

  ThreadState threadState(int conversationId) =>
      _threads[conversationId] ?? const ThreadState();

  Future<void> connectIfAuthenticated() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      disconnect();
      return;
    }
    final token = auth.token ?? await SecureStorage.getToken();
    if (token == null || token.isEmpty) return;

    _socket.connect(
      token: token,
      onMessage: _onSocketMessage,
      onRead: _onSocketRead,
      onPresence: _onSocketPresence,
    );
    await refreshUnread();
    await loadConversations();
  }

  void disconnect() {
    _socket.disconnect();
    state = const ChatState();
    _threads.clear();
  }

  void _onSocketMessage(Map<String, dynamic> payload) {
    try {
      final msg = ChatMessageModel.fromJson(payload);
      final convId = msg.conversationId;
      final thread = _threads[convId];
      if (thread != null) {
        final exists = thread.messages.any((m) => m.id == msg.id);
        if (!exists) {
          _threads[convId] = thread.copyWith(
            messages: [...thread.messages, msg],
          );
          _tickThreads();
        }
      }
      _bumpConversationPreview(convId, msg);
      if (!msg.isMine) {
        state = state.copyWith(unreadTotal: state.unreadTotal + 1);
      }
    } catch (e) {
      developer.log('chat socket message error: $e', name: 'ChatNotifier');
    }
  }

  void _onSocketRead(Map<String, dynamic> payload) {
    // peer read receipts — UI can use last_read from conversation refresh
  }

  void _onSocketPresence(Map<String, dynamic> payload) {
    final userId = payload['userId'] as int?;
    final online = payload['isOnline'] as bool? ?? false;
    if (userId == null) return;
    final updated = state.conversations.map((c) {
      if (c.peer.userId == userId) {
        return c.copyWith(
          peer: ChatPeer(
            userId: c.peer.userId,
            name: c.peer.name,
            role: c.peer.role,
            isVerified: c.peer.isVerified,
            avatarUrl: c.peer.avatarUrl,
            isOnline: online,
          ),
        );
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: updated);
    for (final entry in _threads.entries) {
      if (entry.value.peer?.userId == userId) {
        _threads[entry.key] = entry.value.copyWith(
          peer: ChatPeer(
            userId: entry.value.peer!.userId,
            name: entry.value.peer!.name,
            role: entry.value.peer!.role,
            isVerified: entry.value.peer!.isVerified,
            avatarUrl: entry.value.peer!.avatarUrl,
            isOnline: online,
          ),
        );
      }
    }
    _tickThreads();
  }

  void _bumpConversationPreview(int convId, ChatMessageModel msg) {
    final preview = chatPreviewFromMessage(msg);

    final list = state.conversations.map((c) {
      if (c.id == convId) {
        return c.copyWith(
          lastMessagePreview: preview,
          lastMessageAt: msg.createdAt ?? DateTime.now(),
          unreadCount: msg.isMine ? c.unreadCount : c.unreadCount + 1,
        );
      }
      return c;
    }).toList();
    if (list.any((c) => c.id == convId)) {
      state = state.copyWith(conversations: list);
    }
  }

  Future<void> refreshUnread() async {
    try {
      final total = await ChatApi.fetchUnreadTotal();
      state = state.copyWith(unreadTotal: total);
    } catch (e) {
      developer.log('unread error: $e', name: 'ChatNotifier');
      if (state.conversations.isNotEmpty) {
        final total =
            state.conversations.fold<int>(0, (s, c) => s + c.unreadCount);
        state = state.copyWith(unreadTotal: total);
      }
    }
  }

  Future<void> loadConversations({bool archived = false}) async {
    state = state.copyWith(isLoadingList: true, clearError: true);
    try {
      final list = await ChatApi.listConversations(archived: archived);
      final total = list.fold<int>(0, (s, c) => s + c.unreadCount);
      state = state.copyWith(
        conversations: list,
        unreadTotal: total,
        isLoadingList: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingList: false,
        listError: e.toString(),
      );
    }
  }

  Future<ConversationModel> openSupport() => ChatApi.getSupportConversation();

  Future<ConversationModel> openBuyerSeller({
    required int storeId,
    int? orderId,
  }) =>
      ChatApi.createConversation(
        kind: 'buyer_seller',
        storeId: storeId,
        orderId: orderId,
      );

  Future<ConversationModel> openOrderChatAsSeller(int orderId) =>
      ChatApi.openOrderChatAsSeller(orderId);

  void setPendingOrderShare(int conversationId, PendingOrderShare share) {
    final t = _threads[conversationId] ?? const ThreadState();
    _threads[conversationId] = t.copyWith(pendingOrderShare: share);
    _tickThreads();
  }

  void clearPendingOrderShare(int conversationId) {
    final t = _threads[conversationId];
    if (t == null || t.pendingOrderShare == null) return;
    _threads[conversationId] = t.copyWith(clearPendingOrderShare: true);
    _tickThreads();
  }

  Future<void> sendPendingOrderShare(int conversationId) async {
    final thread = _threads[conversationId];
    final pending = thread?.pendingOrderShare;
    if (pending == null) return;
    await sendRich(
      conversationId,
      messageType: 'order',
      metadata: {'orderId': pending.orderId},
    );
    _threads[conversationId] =
        (_threads[conversationId] ?? const ThreadState()).copyWith(
      clearPendingOrderShare: true,
    );
    _tickThreads();
  }

  Future<ConversationModel> openRiderSeller({
    required int storeId,
    int? orderId,
  }) =>
      ChatApi.createConversation(
        kind: 'rider_seller',
        storeId: storeId,
        orderId: orderId,
      );

  Future<void> loadThread(int conversationId) async {
    _socket.joinConversation(conversationId);
    _threads[conversationId] =
        (_threads[conversationId] ?? const ThreadState()).copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await ChatApi.fetchMessages(conversationId);
      final prevPending = _threads[conversationId]?.pendingOrderShare;
      _threads[conversationId] = ThreadState(
        messages: result.messages,
        conversation: result.conversation,
        peer: result.peer ?? result.conversation?.peer,
        hasMore: result.nextCursor != null,
        nextCursor: result.nextCursor,
        isLoading: false,
        pendingOrderShare: prevPending,
      );
      _tickThreads();
      await ChatApi.markRead(conversationId);
      _clearUnread(convId: conversationId);
      await refreshUnread();
    } catch (e) {
      _threads[conversationId] =
          (_threads[conversationId] ?? const ThreadState()).copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _tickThreads();
    }
  }

  Future<void> loadMoreMessages(int conversationId) async {
    final thread = _threads[conversationId];
    if (thread == null || !thread.hasMore || thread.nextCursor == null) return;
    try {
      final result = await ChatApi.fetchMessages(
        conversationId,
        cursor: thread.nextCursor,
      );
      _threads[conversationId] = thread.copyWith(
        messages: [...result.messages, ...thread.messages],
        hasMore: result.nextCursor != null,
        nextCursor: result.nextCursor,
      );
      _tickThreads();
    } catch (_) {}
  }

  void setReplyTo(int conversationId, ChatMessageModel? msg) {
    final t = _threads[conversationId] ?? const ThreadState();
    _threads[conversationId] =
        msg == null ? t.copyWith(clearReply: true) : t.copyWith(replyTo: msg);
    _tickThreads();
  }

  Future<ChatMessageModel?> sendText(int conversationId, String text) async {
    if (text.trim().isEmpty) return null;
    final thread = _threads[conversationId] ?? const ThreadState();
    _threads[conversationId] = thread.copyWith(isSending: true);
    _tickThreads();
    try {
      final meta = <String, dynamic>{};
      if (thread.replyTo != null) {
        meta['replyToMessageId'] = thread.replyTo!.id;
      }
      final msg = await ChatApi.sendMessage(
        conversationId,
        body: text.trim(),
        messageType: 'text',
        metadata: meta.isEmpty ? null : meta,
      );
      _appendMessage(conversationId, msg);
      _threads[conversationId] =
          (_threads[conversationId] ?? const ThreadState()).copyWith(
        isSending: false,
        clearReply: true,
      );
      _tickThreads();
      return msg;
    } catch (e) {
      _threads[conversationId] =
          (_threads[conversationId] ?? const ThreadState()).copyWith(
        isSending: false,
        error: e.toString(),
      );
      _tickThreads();
      return null;
    }
  }

  Future<ChatMessageModel?> sendRich(
    int conversationId, {
    required String messageType,
    String body = '',
    Map<String, dynamic>? metadata,
  }) async {
    final thread = _threads[conversationId] ?? const ThreadState();
    _threads[conversationId] = thread.copyWith(isSending: true);
    _tickThreads();
    try {
      final meta = Map<String, dynamic>.from(metadata ?? {});
      if (thread.replyTo != null) {
        meta['replyToMessageId'] = thread.replyTo!.id;
      }
      final msg = await ChatApi.sendMessage(
        conversationId,
        body: body,
        messageType: messageType,
        metadata: meta.isEmpty ? null : meta,
      );
      _appendMessage(conversationId, msg);
      _threads[conversationId] =
          (_threads[conversationId] ?? const ThreadState()).copyWith(
        isSending: false,
        clearReply: true,
      );
      _tickThreads();
      return msg;
    } catch (e) {
      _threads[conversationId] =
          (_threads[conversationId] ?? const ThreadState()).copyWith(
        isSending: false,
        error: e.toString(),
      );
      _tickThreads();
      return null;
    }
  }

  Future<void> uploadAndSend(int conversationId, File file) async {
    final uploaded = await ChatApi.uploadFile(file);
    final base = dotenvBaseUrl();
    final url = uploaded.url.startsWith('http')
        ? uploaded.url
        : '$base${uploaded.url}';
    await sendRich(
      conversationId,
      messageType: uploaded.messageType,
      body: uploaded.fileName,
      metadata: {
        'fileUrl': url,
        'fileName': uploaded.fileName,
      },
    );
  }

  static String dotenvBaseUrl() {
    // ApiClient uses /api suffix; static files are at host root
    return ChatSocketService.socketBaseUrl();
  }

  void _appendMessage(int conversationId, ChatMessageModel msg) {
    final thread = _threads[conversationId] ?? const ThreadState();
    if (thread.messages.any((m) => m.id == msg.id)) return;
    _threads[conversationId] = thread.copyWith(
      messages: [...thread.messages, msg],
    );
    _tickThreads();
    _bumpConversationPreview(conversationId, msg);
  }

  void _clearUnread({required int convId}) {
    final list = state.conversations.map((c) {
      if (c.id == convId) return c.copyWith(unreadCount: 0);
      return c;
    }).toList();
    state = state.copyWith(conversations: list);
  }

  Future<void> togglePin(ConversationModel conv) async {
    final pinned = await ChatApi.togglePin(conv.id, isPinned: !conv.isPinned);
    final list = state.conversations.map((c) {
      if (c.id == conv.id) return c.copyWith(isPinned: pinned);
      return c;
    }).toList();
    state = state.copyWith(conversations: list);
  }

  Future<bool> archiveConversation(int conversationId, {required bool archive}) async {
    final archived = await ChatApi.setArchived(
      conversationId,
      isArchived: archive,
    );
    final list = state.conversations.where((c) => c.id != conversationId).toList();
    state = state.copyWith(conversations: list);
    await refreshUnread();
    return archived;
  }

  Future<void> deleteConversation(int conversationId) async {
    await ChatApi.deleteConversation(conversationId);
    final list = state.conversations.where((c) => c.id != conversationId).toList();
    state = state.copyWith(conversations: list);
    _threads.remove(conversationId);
    _tickThreads();
    await refreshUnread();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));

final chatUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(chatProvider).unreadTotal;
});

final chatThreadProvider =
    Provider.family<ThreadState, int>((ref, conversationId) {
  ref.watch(chatProvider.select((s) => s.threadTick));
  return ref.read(chatProvider.notifier).threadState(conversationId);
});
