import '../../data/models/chat_message_model.dart';

/// User-friendly last-message preview for list tiles and local updates.
String chatPreviewFromMessage(ChatMessageModel msg) {
  switch (msg.messageType) {
    case 'image':
      return 'Photo';
    case 'file':
      return 'Attachment';
    case 'product':
      final name = msg.metadata['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return 'Product · $name';
      return 'Shared a product';
    case 'order':
      final name = msg.metadata['productName']?.toString().trim();
      if (name != null && name.isNotEmpty) return 'Order · $name';
      return 'Shared an order';
    default:
      final body = msg.body.trim();
      return body.isNotEmpty ? body : 'Message';
  }
}
