import '../../core/services/api_client.dart';

class SellerInsights {
  final int? storeId;
  final double rating;
  final int reviewCount;
  final int followersCount;
  final int wishlistBuyerCount;
  final Map<String, int> ratingBreakdown;
  final List<WishlistProductInsight> wishlistProductBreakdown;

  const SellerInsights({
    this.storeId,
    this.rating = 0,
    this.reviewCount = 0,
    this.followersCount = 0,
    this.wishlistBuyerCount = 0,
    this.ratingBreakdown = const {},
    this.wishlistProductBreakdown = const [],
  });

  factory SellerInsights.fromJson(Map<String, dynamic> json) {
    final breakdown = <String, int>{};
    final rb = json['ratingBreakdown'];
    if (rb is Map) {
      rb.forEach((k, v) => breakdown[k.toString()] = (v as num?)?.toInt() ?? 0);
    }
    final products = (json['wishlistProductBreakdown'] as List?)
            ?.map((e) => WishlistProductInsight.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    return SellerInsights(
      storeId: (json['storeId'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      wishlistBuyerCount: (json['wishlistBuyerCount'] as num?)?.toInt() ?? 0,
      ratingBreakdown: breakdown,
      wishlistProductBreakdown: products,
    );
  }
}

class WishlistProductInsight {
  final int productId;
  final String productName;
  final int wishlistCount;

  const WishlistProductInsight({
    required this.productId,
    required this.productName,
    required this.wishlistCount,
  });

  factory WishlistProductInsight.fromJson(Map<String, dynamic> json) {
    return WishlistProductInsight(
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      productName: json['productName']?.toString() ?? 'Product',
      wishlistCount: (json['wishlistCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoreFollower {
  final int userId;
  final String name;
  final String email;
  final String? followedAt;

  const StoreFollower({
    required this.userId,
    required this.name,
    required this.email,
    this.followedAt,
  });

  factory StoreFollower.fromJson(Map<String, dynamic> json) {
    return StoreFollower(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'User',
      email: json['email']?.toString() ?? '',
      followedAt: json['followedAt']?.toString(),
    );
  }
}

class SellerReviewItem {
  final int id;
  final int rating;
  final String reviewFormat;
  final Map<String, int> ratings;
  final String? comment;
  final int? deliverySatisfaction;
  final List<String> deliveryPills;
  final String? createdAt;
  final int? productId;
  final String? productName;
  final String? productImage;
  final String? buyerName;
  final String? variant;
  final String? sellerReply;
  final String? sellerReplyAt;
  final String visibility;

  const SellerReviewItem({
    required this.id,
    required this.rating,
    this.reviewFormat = 'default',
    this.ratings = const {},
    this.comment,
    this.deliverySatisfaction,
    this.deliveryPills = const [],
    this.createdAt,
    this.productId,
    this.productName,
    this.productImage,
    this.buyerName,
    this.variant,
    this.sellerReply,
    this.sellerReplyAt,
    this.visibility = 'visible',
  });

  factory SellerReviewItem.fromJson(Map<String, dynamic> json) {
    final ratingsRaw = json['ratings'];
    final ratings = <String, int>{};
    if (ratingsRaw is Map) {
      ratingsRaw.forEach((k, v) {
        if (v is num) ratings[k.toString()] = v.toInt();
      });
    }
    final pillsRaw = json['deliveryPills'];
    final pills = <String>[];
    if (pillsRaw is List) {
      for (final p in pillsRaw) {
        if (p != null) pills.add(p.toString());
      }
    }
    return SellerReviewItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      reviewFormat: json['reviewFormat']?.toString() ?? 'default',
      ratings: ratings,
      comment: json['comment']?.toString(),
      deliverySatisfaction: (json['deliverySatisfaction'] as num?)?.toInt(),
      deliveryPills: pills,
      createdAt: json['createdAt']?.toString(),
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName']?.toString(),
      productImage: ApiClient.resolveImageUrl(json['productImage']?.toString()),
      buyerName: json['buyerName']?.toString(),
      variant: json['variant']?.toString(),
      sellerReply: json['sellerReply']?.toString(),
      sellerReplyAt: json['sellerReplyAt']?.toString(),
      visibility: json['visibility']?.toString() ?? 'visible',
    );
  }
}

class SellerInsightsApi {
  static Future<SellerInsights> getInsights() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/seller/insights');
    return SellerInsights.fromJson(Map<String, dynamic>.from(res.data));
  }

  static Future<List<StoreFollower>> getFollowers({int page = 1}) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/seller/followers', queryParameters: {'page': page});
    final list = res.data['followers'] as List? ?? [];
    return list
        .map((e) => StoreFollower.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<SellerReviewItem>> getReviews({
    String sort = 'newest',
    String status = 'all',
    int page = 1,
  }) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get(
      '/seller/reviews',
      queryParameters: {'sort': sort, 'status': status, 'page': page},
    );
    final list = res.data['reviews'] as List? ?? [];
    return list
        .map((e) => SellerReviewItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<SellerReviewItem> replyToReview(int reviewId, String reply) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.post(
      '/seller/reviews/$reviewId/reply',
      data: {'reply': reply},
    );
    final data = res.data;
    if (data is Map && data['review'] is Map) {
      return SellerReviewItem.fromJson(
        Map<String, dynamic>.from(data['review'] as Map),
      );
    }
    throw Exception('Invalid reply response');
  }

  static Future<SellerReviewItem> deleteReviewReply(int reviewId) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.delete('/seller/reviews/$reviewId/reply');
    final data = res.data;
    if (data is Map && data['review'] is Map) {
      return SellerReviewItem.fromJson(
        Map<String, dynamic>.from(data['review'] as Map),
      );
    }
    throw Exception('Invalid delete reply response');
  }

  static Future<void> moderateReview(
    int reviewId, {
    String? visibility,
    bool delete = false,
  }) async {
    final dio = await ApiClient.getInstance();
    await dio.patch(
      '/seller/reviews/$reviewId',
      data: {
        if (visibility != null) 'visibility': visibility,
        if (delete) 'delete': true,
      },
    );
  }
}
