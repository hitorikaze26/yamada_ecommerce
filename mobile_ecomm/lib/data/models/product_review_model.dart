class ProductReview {
  final int id;
  final int rating;
  final String reviewFormat;
  final Map<String, int> ratings;
  final String? comment;
  final int? deliverySatisfaction;
  final List<String> deliveryPills;
  final String? createdAt;
  final String? buyerName;
  final int? productId;
  final String? productName;
  final String? productImage;
  final List<String>? images;
  final String? variant;
  final String? sellerReply;
  final String? sellerReplyAt;

  const ProductReview({
    required this.id,
    required this.rating,
    this.reviewFormat = 'default',
    this.ratings = const {},
    this.comment,
    this.deliverySatisfaction,
    this.deliveryPills = const [],
    this.createdAt,
    this.buyerName,
    this.productId,
    this.productName,
    this.productImage,
    this.images,
    this.variant,
    this.sellerReply,
    this.sellerReplyAt,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
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
    return ProductReview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      reviewFormat: json['reviewFormat']?.toString() ?? 'default',
      ratings: ratings,
      comment: json['comment']?.toString(),
      deliverySatisfaction: (json['deliverySatisfaction'] as num?)?.toInt(),
      deliveryPills: pills,
      createdAt: json['createdAt']?.toString(),
      buyerName: json['buyerName']?.toString(),
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName']?.toString(),
      productImage: json['productImage']?.toString(),
      images: (json['images'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      variant: json['variant']?.toString(),
      sellerReply: json['sellerReply']?.toString(),
      sellerReplyAt: json['sellerReplyAt']?.toString(),
    );
  }
}

class ReviewableOrderItem {
  final int orderItemId;
  final int productId;
  final String? productName;
  final Map<String, dynamic>? variant;
  final double? unitPrice;
  final int? quantity;
  final String reviewFormat;

  const ReviewableOrderItem({
    required this.orderItemId,
    required this.productId,
    this.productName,
    this.variant,
    this.unitPrice,
    this.quantity,
    this.reviewFormat = 'default',
  });

  factory ReviewableOrderItem.fromJson(Map<String, dynamic> json) {
    final v = json['variant'];
    Map<String, dynamic>? variant;
    if (v is Map) {
      variant = Map<String, dynamic>.from(v);
    }
    return ReviewableOrderItem(
      orderItemId: (json['orderItemId'] as num?)?.toInt() ?? 0,
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      productName: json['productName']?.toString(),
      variant: variant,
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toInt(),
      reviewFormat: json['reviewFormat']?.toString() ?? 'default',
    );
  }

  String get variantLabel {
    if (variant == null) return '';
    final parts = <String>[];
    if (variant!['color'] != null) parts.add(variant!['color'].toString());
    if (variant!['size'] != null) parts.add(variant!['size'].toString());
    return parts.join(' / ');
  }
}

class OrderReviewsData {
  final List<ProductReview> reviews;
  final List<ReviewableOrderItem> reviewableItems;
  final List<String> deliveryPillOptions;

  const OrderReviewsData({
    this.reviews = const [],
    this.reviewableItems = const [],
    this.deliveryPillOptions = const [],
  });

  factory OrderReviewsData.fromJson(Map<String, dynamic> json) {
    final reviews = (json['reviews'] as List?)
            ?.map((e) => ProductReview.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final items = (json['reviewableItems'] as List?)
            ?.map((e) =>
                ReviewableOrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final pills = (json['deliveryPillOptions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return OrderReviewsData(
      reviews: reviews,
      reviewableItems: items,
      deliveryPillOptions: pills,
    );
  }
}

const dimensionLabelsDefault = {
  'quality': 'Quality',
  'fabricFeel': 'Fabric Feel',
  'comfort': 'Comfort',
  'fit': 'Fit',
  'appearance': 'Appearance',
  'productAccuracy': 'Product Accuracy',
  'packaging': 'Packaging',
  'deliveryExperience': 'Delivery Experience',
};

const dimensionLabelsAccessories = {
  'quality': 'Quality',
  'comfort': 'Comfort',
  'fit': 'Fit',
  'sizingAccuracy': 'Sizing Accuracy',
  'materialQuality': 'Material Quality',
  'appearance': 'Appearance',
  'durability': 'Durability',
  'packaging': 'Packaging',
  'deliveryExperience': 'Delivery Experience',
};

List<String> dimensionKeysForFormat(String format) {
  if (format == 'accessories_shoes') {
    return dimensionLabelsAccessories.keys.toList();
  }
  return dimensionLabelsDefault.keys.toList();
}

Map<String, String> dimensionLabelsForFormat(String format) {
  if (format == 'accessories_shoes') return dimensionLabelsAccessories;
  return dimensionLabelsDefault;
}
