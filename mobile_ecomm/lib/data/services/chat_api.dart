import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

class ChatApi {
  static Future<List<ConversationModel>> listConversations({
    bool archived = false,
  }) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get(
      '/chat/conversations',
      queryParameters: archived ? {'archived': 'true'} : null,
    );
    final list = res.data['conversations'] as List? ?? [];
    return list
        .map((e) => ConversationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<int> fetchUnreadTotal() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/chat/unread-count');
    return res.data['unreadTotal'] as int? ?? 0;
  }

  static Future<ConversationModel> getSupportConversation() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/chat/conversations/support');
    return ConversationModel.fromJson(
      Map<String, dynamic>.from(res.data['conversation']),
    );
  }

  static Future<ConversationModel> openOrderChatAsSeller(int orderId) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.post(
      '/chat/conversations/from-order',
      data: {'orderId': orderId},
    );
    return ConversationModel.fromJson(
      Map<String, dynamic>.from(res.data['conversation'] as Map),
    );
  }

  static Future<ConversationModel> createConversation({
    required String kind,
    int? storeId,
    int? orderId,
  }) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.post('/chat/conversations', data: {
      'kind': kind,
      if (storeId != null) 'storeId': storeId,
      if (orderId != null) 'orderId': orderId,
    });
    return ConversationModel.fromJson(
      Map<String, dynamic>.from(res.data['conversation']),
    );
  }

  static Future<({
    List<ChatMessageModel> messages,
    int? nextCursor,
    ConversationModel? conversation,
    ChatPeer? peer,
  })> fetchMessages(
    int conversationId, {
    int? cursor,
    int limit = 50,
  }) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get(
      '/chat/conversations/$conversationId/messages',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final list = res.data['messages'] as List? ?? [];
    final messages = list
        .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    ConversationModel? conv;
    if (res.data['conversation'] != null) {
      conv = ConversationModel.fromJson(
        Map<String, dynamic>.from(res.data['conversation']),
      );
    }
    ChatPeer? peer;
    if (res.data['peer'] != null) {
      peer = ChatPeer.fromJson(Map<String, dynamic>.from(res.data['peer']));
    }
    return (
      messages: messages,
      nextCursor: res.data['nextCursor'] as int?,
      conversation: conv,
      peer: peer,
    );
  }

  static Future<ChatMessageModel> sendMessage(
    int conversationId, {
    String body = '',
    required String messageType,
    Map<String, dynamic>? metadata,
  }) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.post(
      '/chat/conversations/$conversationId/messages',
      data: {
        'body': body,
        'messageType': messageType,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return ChatMessageModel.fromJson(
      Map<String, dynamic>.from(res.data['message']),
    );
  }

  static Future<void> markRead(int conversationId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/chat/conversations/$conversationId/read');
  }

  static Future<bool> setArchived(
    int conversationId, {
    required bool isArchived,
  }) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.patch(
      '/chat/conversations/$conversationId/archive',
      data: {'isArchived': isArchived},
    );
    return res.data['isArchived'] as bool? ?? isArchived;
  }

  static Future<void> deleteConversation(int conversationId) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('/chat/conversations/$conversationId');
  }

  static Future<bool> togglePin(int conversationId, {bool? isPinned}) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.patch(
      '/chat/conversations/$conversationId/pin',
      data: isPinned != null ? {'isPinned': isPinned} : <String, dynamic>{},
    );
    return res.data['isPinned'] as bool? ?? false;
  }

  static Future<({String url, String fileName, String messageType})> uploadFile(
    File file,
  ) async {
    final dio = await ApiClient.getInstance();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split(RegExp(r'[/\\]')).last),
    });
    final res = await dio.post('/chat/upload', data: formData);
    return (
      url: res.data['url']?.toString() ?? '',
      fileName: res.data['fileName']?.toString() ?? '',
      messageType: res.data['messageType']?.toString() ?? 'file',
    );
  }

  static Future<List<ShareProductItem>> shareProducts({int? storeId}) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get(
      '/chat/share/products',
      queryParameters:
          storeId != null ? <String, dynamic>{'storeId': storeId} : null,
    );
    final list = res.data['products'] as List? ?? [];
    return list
        .map((e) => ShareProductItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<ShareOrderItem>> shareOrders() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/chat/share/orders');
    final list = res.data['orders'] as List? ?? [];
    return list
        .map((e) => ShareOrderItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
