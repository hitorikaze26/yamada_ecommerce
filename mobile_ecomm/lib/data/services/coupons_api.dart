import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';

class CouponModel {
  final int id;
  final String code;
  final String title;
  final String description;
  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final String? expiresAt;
  final String scope;
  final int? storeId;

  CouponModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    this.expiresAt,
    required this.scope,
    this.storeId,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discountType: json['discountType']?.toString() ??
          json['discount_type']?.toString() ??
          'percent',
      discountValue: (json['discountValue'] ?? json['discount_value'] ?? 0)
          .toDouble(),
      minOrderAmount: (json['minOrderAmount'] ?? json['min_order_amount'] ?? 0)
          .toDouble(),
      expiresAt: json['expiresAt']?.toString() ?? json['expires_at']?.toString(),
      scope: json['scope']?.toString() ?? 'platform',
      storeId: json['storeId'] as int? ?? json['store_id'] as int?,
    );
  }

  String get discountLabel {
    if (discountType == 'percent') {
      return '${discountValue.toStringAsFixed(0)}% off';
    }
    return '₱${discountValue.toStringAsFixed(0)} off';
  }
}

class CouponValidationResult {
  final bool valid;
  final double discount;
  final String message;
  final CouponModel? coupon;

  CouponValidationResult({
    required this.valid,
    required this.discount,
    required this.message,
    this.coupon,
  });
}

class CouponsApi {
  static Future<List<CouponModel>> getCoupons({int? storeId}) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get(
        '/accounts/buyer/coupons',
        queryParameters: storeId != null ? {'storeId': storeId} : null,
      );
      final list = response.data['coupons'] as List<dynamic>? ?? [];
      return list
          .map((e) => CouponModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to load coupons');
    }
  }

  static Future<CouponValidationResult> validateCoupon({
    required String code,
    required double subtotal,
    int? storeId,
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.post(
        '/accounts/buyer/coupons/validate',
        data: {
          'code': code,
          'subtotal': subtotal,
          if (storeId != null) 'storeId': storeId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return CouponValidationResult(
        valid: data['valid'] == true,
        discount: (data['discount'] ?? 0).toDouble(),
        message: data['message']?.toString() ?? '',
        coupon: data['coupon'] != null
            ? CouponModel.fromJson(data['coupon'] as Map<String, dynamic>)
            : null,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to validate coupon');
    }
  }
}
