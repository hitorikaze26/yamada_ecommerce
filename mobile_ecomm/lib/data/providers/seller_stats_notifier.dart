import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_api.dart';
import '../../core/services/api_client.dart';
import 'dart:developer' as developer;

/// Holds the real dashboard stats for the seller.
class SellerStats {
  final double totalSales;
  final int totalOrders;
  final int totalProducts;
  final double rating;
  final String shopName;
  final bool isLoading;
  final String? error;

  const SellerStats({
    this.totalSales = 0,
    this.totalOrders = 0,
    this.totalProducts = 0,
    this.rating = 0,
    this.shopName = '',
    this.isLoading = false,
    this.error,
  });

  SellerStats copyWith({
    double? totalSales,
    int? totalOrders,
    int? totalProducts,
    double? rating,
    String? shopName,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SellerStats(
      totalSales: totalSales ?? this.totalSales,
      totalOrders: totalOrders ?? this.totalOrders,
      totalProducts: totalProducts ?? this.totalProducts,
      rating: rating ?? this.rating,
      shopName: shopName ?? this.shopName,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SellerStatsNotifier extends StateNotifier<SellerStats> {
  SellerStatsNotifier() : super(const SellerStats());

  Future<void> fetchStats() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Fetch profile (has totalSales, rating, shopName)
      final profile = await AuthApi.getSellerProfile();

      // Fetch products count
      int productCount = 0;
      try {
        final dio = await ApiClient.getInstance();
        final productsRes = await dio.get('/seller/products');
        final products = productsRes.data['products'] as List? ?? [];
        productCount = products.length;
      } catch (e) {
        developer.log('Failed to fetch seller products count: $e',
            name: 'SellerStatsNotifier');
      }

      // Fetch orders count
      int orderCount = 0;
      try {
        final dio = await ApiClient.getInstance();
        final ordersRes = await dio.get('/seller/orders');
        final orders = ordersRes.data['orders'] as List? ?? [];
        orderCount = orders.length;
      } catch (e) {
        developer.log('Failed to fetch seller orders count: $e',
            name: 'SellerStatsNotifier');
      }

      state = state.copyWith(
        totalSales: (profile['totalSales'] as num?)?.toDouble() ?? 0,
        rating: (profile['rating'] as num?)?.toDouble() ?? 0,
        shopName: profile['shopName']?.toString() ?? '',
        totalProducts: productCount,
        totalOrders: orderCount,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      developer.log('SellerStatsNotifier.fetchStats error: $e',
          name: 'SellerStatsNotifier');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void refresh() => fetchStats();
}

final sellerStatsProvider =
    StateNotifierProvider<SellerStatsNotifier, SellerStats>((ref) {
  final notifier = SellerStatsNotifier();
  notifier.fetchStats();
  return notifier;
});
