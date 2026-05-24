import 'dart:developer' as developer;
import '../../core/services/api_client.dart';

/// Shipping calculation result
class ShippingCalculation {
  final double shippingFee;
  final bool freeShipping;
  final String? error;
  final String? note;

  ShippingCalculation({
    required this.shippingFee,
    required this.freeShipping,
    this.error,
    this.note,
  });

  factory ShippingCalculation.fromJson(Map<String, dynamic> json) {
    return ShippingCalculation(
      shippingFee: (json['shipping_fee'] as num?)?.toDouble() ?? 0.0,
      freeShipping: json['free_shipping'] as bool? ?? false,
      error: json['error']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

/// Shipping API Service
/// Handles shipping fee calculations from the backend
class ShippingApi {
  /// Calculate shipping fee for a shop based on buyer address
  static Future<ShippingCalculation> calculateShipping({
    required int shopId,
    required double orderTotal,
    String? buyerRegion,
    String? buyerProvince,
    String? buyerMunicipality,
    String? buyerRegionCode,
    String? buyerProvinceCode,
    String? buyerMunicipalityCode,
  }) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post('/shipping/calculate', data: {
        'shop_id': shopId,
        'order_total': orderTotal,
        if (buyerRegion != null) 'buyer_region': buyerRegion,
        if (buyerProvince != null) 'buyer_province': buyerProvince,
        if (buyerMunicipality != null) 'buyer_municipality': buyerMunicipality,
        if (buyerRegionCode != null) 'buyer_region_code': buyerRegionCode,
        if (buyerProvinceCode != null) 'buyer_province_code': buyerProvinceCode,
        if (buyerMunicipalityCode != null) 'buyer_municipality_code': buyerMunicipalityCode,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        developer.log('Shipping calculated: ₱${data['shipping_fee']} - ${data['note']}', name: 'ShippingApi');
        return ShippingCalculation.fromJson(data);
      } else {
        throw Exception('Failed to calculate shipping: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error calculating shipping: $e', name: 'ShippingApi');
      // Return fallback calculation on error
      return ShippingCalculation(
        shippingFee: orderTotal >= 10000 ? 0.0 : 100.0,
        freeShipping: orderTotal >= 10000,
        error: 'Failed to calculate: $e',
        note: 'Using fallback rates',
      );
    }
  }

  /// Calculate shipping for multiple shops
  static Future<Map<int, ShippingCalculation>> calculateShippingForShops({
    required Map<int, double> shopTotals,
    String? buyerRegion,
    String? buyerProvince,
    String? buyerMunicipality,
    String? buyerRegionCode,
    String? buyerProvinceCode,
    String? buyerMunicipalityCode,
  }) async {
    final results = <int, ShippingCalculation>{};

    for (final entry in shopTotals.entries) {
      final calculation = await calculateShipping(
        shopId: entry.key,
        orderTotal: entry.value,
        buyerRegion: buyerRegion,
        buyerProvince: buyerProvince,
        buyerMunicipality: buyerMunicipality,
        buyerRegionCode: buyerRegionCode,
        buyerProvinceCode: buyerProvinceCode,
        buyerMunicipalityCode: buyerMunicipalityCode,
      );
      results[entry.key] = calculation;
    }

    return results;
  }
}
