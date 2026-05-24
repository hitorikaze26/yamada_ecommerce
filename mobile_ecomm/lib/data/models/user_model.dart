import 'address_model.dart';

enum UserRole { buyer, seller, rider, admin }

/// User model matching backend response format
/// Matches Next.js client User type
class User {
  final String id;
  final String email;
  final String? name;
  final String? username;
  final String? givenName;
  final String? surname;
  final String? avatar;
  final String? avatarUrl;
  final UserRole role;
  final String? contactNumber;
  final String? address;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final AddressData? fullAddress;

  User({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.givenName,
    this.surname,
    this.avatar,
    this.avatarUrl,
    required this.role,
    this.contactNumber,
    this.address,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.fullAddress,
  });

  /// Get full name from givenName and surname
  String get fullName {
    if (givenName != null && surname != null) {
      return '$givenName $surname'.trim();
    }
    return name ?? email.split('@').first;
  }

  /// Get display name for UI
  String get displayName => fullName;

  /// @username for profile, or null if not set
  String? get profileHandle {
    final u = username?.trim();
    if (u != null && u.isNotEmpty) return u.startsWith('@') ? u : '@$u';
    return null;
  }

  factory User.fromJson(Map<String, dynamic> json, {UserRole? defaultRole}) {
    // Try to get name from various field names
    String? fullName = json['name']?.toString();
    if (fullName == null || fullName.isEmpty) {
      final given = json['givenName']?.toString() ?? json['given_name']?.toString();
      final sur = json['surname']?.toString() ?? json['surname']?.toString();
      if (given != null || sur != null) {
        fullName = '${given ?? ''} ${sur ?? ''}'.trim();
      }
    }

    final id = json['id']?.toString() ??
        json['userId']?.toString() ??
        json['user_id']?.toString() ??
        '';

    return User(
      id: id,
      email: json['email']?.toString() ?? json['User email']?.toString() ?? '',
      name: fullName,
      username: json['username']?.toString() ?? json['user_name']?.toString(),
      givenName: json['givenName']?.toString() ?? json['given_name']?.toString(),
      surname: json['surname']?.toString(),
      avatar: json['avatar']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      role: _parseRole(json['role']?.toString() ?? json['user_role']?.toString()) ?? defaultRole ?? UserRole.buyer,
      contactNumber: json['contactNumber']?.toString() ?? json['contact_number']?.toString(),
      address: json['address']?.toString(),
      isVerified: json['isVerified'] ?? json['is_verified'] ?? json['User verified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      fullAddress: json['address'] != null && json['address'] is Map
          ? AddressData.fromJson(json['address'])
          : null,
    );
  }

  /// Create from backend profile response
  factory User.fromProfileJson(Map<String, dynamic> json, UserRole role) {
    return User.fromJson(json, defaultRole: role);
  }

  static UserRole? _parseRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'seller':
        return UserRole.seller;
      case 'rider':
        return UserRole.rider;
      case 'admin':
        return UserRole.admin;
      case 'buyer':
        return UserRole.buyer;
      default:
        return null;
    }
  }

  String get roleDisplay {
    switch (role) {
      case UserRole.buyer:
        return 'Buyer';
      case UserRole.seller:
        return 'Seller';
      case UserRole.rider:
        return 'Rider';
      case UserRole.admin:
        return 'Admin';
    }
  }

  /// Convert to JSON for secure storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'givenName': givenName,
      'surname': surname,
      'avatar': avatar,
      'avatarUrl': avatarUrl,
      'role': role.name,
      'contactNumber': contactNumber,
      'address': address,
      'isVerified': isVerified,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
