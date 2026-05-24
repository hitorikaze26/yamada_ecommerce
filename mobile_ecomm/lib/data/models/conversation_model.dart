class ChatPeer {
  final int userId;
  final String name;
  final String role;
  final bool isVerified;
  final String? avatarUrl;
  final bool isOnline;

  const ChatPeer({
    required this.userId,
    required this.name,
    required this.role,
    this.isVerified = false,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory ChatPeer.fromJson(Map<String, dynamic> json) {
    return ChatPeer(
      userId: json['userId'] as int? ?? 0,
      name: json['name']?.toString() ?? 'User',
      role: json['role']?.toString() ?? 'user',
      isVerified: json['isVerified'] as bool? ?? false,
      avatarUrl: json['avatarUrl']?.toString(),
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}

class ConversationModel {
  final int id;
  final String kind;
  final int? storeId;
  final int? orderId;
  final String title;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final ChatPeer peer;

  const ConversationModel({
    required this.id,
    required this.kind,
    this.storeId,
    this.orderId,
    required this.title,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    required this.peer,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      kind: json['kind']?.toString() ?? '',
      storeId: json['storeId'] as int?,
      orderId: json['orderId'] as int?,
      title: json['title']?.toString() ?? '',
      lastMessagePreview: json['lastMessagePreview']?.toString() ?? '',
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      peer: ChatPeer.fromJson(
        Map<String, dynamic>.from(json['peer'] as Map? ?? {}),
      ),
    );
  }

  ConversationModel copyWith({
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    ChatPeer? peer,
  }) {
    return ConversationModel(
      id: id,
      kind: kind,
      storeId: storeId,
      orderId: orderId,
      title: title,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      peer: peer ?? this.peer,
    );
  }
}
