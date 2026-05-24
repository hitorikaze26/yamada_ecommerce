class StoreProfile {
  final String id;
  final String storeName;
  final String tagline;
  final String description;
  final String? logoUrl;
  final String? bannerUrl;
  final double rating;
  final int reviewCount;
  final int followersCount;
  final double responseRate;
  final String responseTime;
  final String? joinedAt;
  final bool isVerified;
  final bool isOpen;
  final bool isOnline;
  final String businessHours;
  final String lastActive;
  final int productCount;
  final int completedOrders;
  final double cancellationRate;
  final String shippingSummary;
  final List<String> categories;
  final String? announcement;
  final List<String> trustBadges;
  final StorePolicies policies;
  final bool isLiveSelling;
  final String? liveTitle;

  const StoreProfile({
    required this.id,
    required this.storeName,
    this.tagline = '',
    this.description = '',
    this.logoUrl,
    this.bannerUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.followersCount = 0,
    this.responseRate = 0,
    this.responseTime = '',
    this.joinedAt,
    this.isVerified = false,
    this.isOpen = true,
    this.isOnline = false,
    this.businessHours = '',
    this.lastActive = '',
    this.productCount = 0,
    this.completedOrders = 0,
    this.cancellationRate = 0,
    this.shippingSummary = '',
    this.categories = const [],
    this.announcement,
    this.trustBadges = const [],
    required this.policies,
    this.isLiveSelling = false,
    this.liveTitle,
  });

  factory StoreProfile.fromJson(Map<String, dynamic> json) {
    final policiesJson = json['policies'] as Map<String, dynamic>? ?? {};
    final live = json['live_selling'] as Map<String, dynamic>? ?? {};
    return StoreProfile(
      id: (json['id'] ?? json['store_id'] ?? '').toString(),
      storeName: (json['store_name'] ?? json['name'] ?? 'Boutique').toString(),
      tagline: json['tagline']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      followersCount: json['followers_count'] as int? ?? 0,
      responseRate: (json['response_rate'] as num?)?.toDouble() ?? 0,
      responseTime: json['response_time']?.toString() ?? '',
      joinedAt: json['joined_at']?.toString(),
      isVerified: json['is_verified'] == true,
      isOpen: json['is_open'] != false,
      isOnline: json['is_online'] == true,
      businessHours: json['business_hours']?.toString() ?? '',
      lastActive: json['last_active']?.toString() ?? '',
      productCount: json['product_count'] as int? ?? 0,
      completedOrders: json['completed_orders'] as int? ?? 0,
      cancellationRate: (json['cancellation_rate'] as num?)?.toDouble() ?? 0,
      shippingSummary: json['shipping_summary']?.toString() ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      announcement: json['announcement']?.toString(),
      trustBadges: List<String>.from(json['trust_badges'] ?? []),
      policies: StorePolicies.fromJson(policiesJson),
      isLiveSelling: live['is_live'] == true,
      liveTitle: live['title']?.toString(),
    );
  }
}

class StorePolicies {
  final bool allowCancellation;
  final int maxCancellationHours;
  final bool allowReturns;
  final int returnPeriodDays;

  const StorePolicies({
    this.allowCancellation = true,
    this.maxCancellationHours = 24,
    this.allowReturns = true,
    this.returnPeriodDays = 7,
  });

  factory StorePolicies.fromJson(Map<String, dynamic> json) {
    return StorePolicies(
      allowCancellation: json['allow_cancellation'] != false,
      maxCancellationHours: json['max_cancellation_hours'] as int? ?? 24,
      allowReturns: json['allow_returns'] != false,
      returnPeriodDays: json['return_period_days'] as int? ?? 7,
    );
  }
}

class StoreReview {
  final String id;
  final int rating;
  final String? comment;
  final String? createdAt;
  final String productName;
  final String? productImage;
  final String buyerName;
  final bool verifiedPurchase;
  final List<String> images;
  final String? sellerReply;

  const StoreReview({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
    required this.productName,
    this.productImage,
    required this.buyerName,
    this.verifiedPurchase = true,
    this.images = const [],
    this.sellerReply,
  });

  factory StoreReview.fromJson(Map<String, dynamic> json) {
    return StoreReview(
      id: json['id']?.toString() ?? '',
      rating: json['rating'] as int? ?? 5,
      comment: json['comment']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      productName: json['productName']?.toString() ?? json['product_name']?.toString() ?? '',
      productImage: json['productImage']?.toString() ?? json['product_image']?.toString(),
      buyerName: json['buyerName']?.toString() ?? json['buyer_name']?.toString() ?? 'Shopper',
      verifiedPurchase: json['verifiedPurchase'] == true || json['verified_purchase'] == true,
      images: List<String>.from(json['images'] ?? []),
      sellerReply: json['sellerReply']?.toString() ?? json['seller_reply']?.toString(),
    );
  }
}
