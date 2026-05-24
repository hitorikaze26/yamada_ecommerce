class ChatMessageModel {
  final int id;
  final int conversationId;
  final int? senderUserId;
  final String senderRole;
  final String body;
  final String messageType;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final bool isMine;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    this.senderUserId,
    required this.senderRole,
    this.body = '',
    this.messageType = 'text',
    this.metadata = const {},
    this.createdAt,
    this.isMine = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      conversationId: json['conversationId'] as int,
      senderUserId: json['senderUserId'] as int?,
      senderRole: json['senderRole']?.toString() ?? 'user',
      body: json['body']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      isMine: json['isMine'] as bool? ?? false,
    );
  }

  int? get replyToMessageId {
    final v = metadata['replyToMessageId'];
    if (v is int) return v;
    if (v != null) return int.tryParse(v.toString());
    return null;
  }
}

class ShareProductItem {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;

  const ShareProductItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  factory ShareProductItem.fromJson(Map<String, dynamic> json) {
    return ShareProductItem(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

class ShareOrderItem {
  final int orderId;
  final String orderNumber;
  final String status;
  final String productName;
  final String? productImageUrl;
  final double totalAmount;

  const ShareOrderItem({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    this.productName = '',
    this.productImageUrl,
    this.totalAmount = 0,
  });

  factory ShareOrderItem.fromJson(Map<String, dynamic> json) {
    return ShareOrderItem(
      orderId: json['orderId'] as int? ?? 0,
      orderNumber: json['orderNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      productImageUrl: json['productImageUrl']?.toString(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
