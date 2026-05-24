class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String description;
  final DateTime? createdAt;
  final bool read;
  final String? role;
  final String? page;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.createdAt,
    this.read = false,
    this.role,
    this.page,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final raw = json['createdAt'];
    if (raw is String && raw.isNotEmpty) {
      createdAt = DateTime.tryParse(raw)?.toLocal();
    }

    return AppNotification(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      userId: json['userId'] is int
          ? json['userId']
          : int.parse('${json['userId'] ?? 0}'),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: createdAt,
      read: json['read'] == true,
      role: json['role']?.toString(),
      page: json['page']?.toString(),
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      description: description,
      createdAt: createdAt,
      read: read ?? this.read,
      role: role,
      page: page,
    );
  }
}
