import '../../core/services/api_client.dart';

class SellerCoupon {
  final int id;
  final String code;
  final String title;
  final String? description;
  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final int? maxUses;
  final int usedCount;
  final bool isActive;
  final String? expiresAt;

  const SellerCoupon({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    this.maxUses,
    this.usedCount = 0,
    this.isActive = true,
    this.expiresAt,
  });

  factory SellerCoupon.fromJson(Map<String, dynamic> json) {
    return SellerCoupon(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType:
          json['discountType']?.toString() ?? json['discount_type']?.toString() ?? 'percent',
      discountValue: (json['discountValue'] as num?)?.toDouble() ??
          (json['discount_value'] as num?)?.toDouble() ??
          0,
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ??
          (json['min_order_amount'] as num?)?.toDouble() ??
          0,
      maxUses: (json['maxUses'] as num?)?.toInt() ?? (json['max_uses'] as num?)?.toInt(),
      usedCount: (json['usedCount'] as num?)?.toInt() ??
          (json['used_count'] as num?)?.toInt() ??
          0,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      expiresAt: json['expiresAt']?.toString() ?? json['expires_at']?.toString(),
    );
  }
}

class SellerCouponsApi {
  static Future<List<SellerCoupon>> listCoupons() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/seller/coupons');
    final list = res.data['coupons'] as List? ?? [];
    return list
        .map((e) => SellerCoupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<SellerCoupon> createCoupon(Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.post('/seller/coupons', data: data);
    return SellerCoupon.fromJson(res.data['coupon'] as Map<String, dynamic>);
  }

  static Future<SellerCoupon> updateCoupon(int id, Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    final res = await dio.put('/seller/coupons/$id', data: data);
    return SellerCoupon.fromJson(res.data['coupon'] as Map<String, dynamic>);
  }

  static Future<void> deleteCoupon(int id) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('/seller/coupons/$id');
  }
}
