import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../models/product_model.dart';

class RecentlyViewedItem {
  final Product product;
  final DateTime viewedAt;

  const RecentlyViewedItem({
    required this.product,
    required this.viewedAt,
  });
}

class RecentlyViewedApi {
  static Future<List<RecentlyViewedItem>> getRecentlyViewed() async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get('/accounts/buyer/recently-viewed');
      if (response.statusCode == 200) {
        final data = response.data['products'] as List? ?? [];
        return data.map((json) {
          final map = json as Map<String, dynamic>;
          final viewedRaw = map['viewedAt'] ?? map['viewed_at'];
          return RecentlyViewedItem(
            product: Product.fromJson(map),
            viewedAt: DateTime.tryParse(viewedRaw?.toString() ?? '') ??
                DateTime.now(),
          );
        }).toList();
      }
      throw Exception('Failed to load recently viewed: ${response.statusCode}');
    } on DioException catch (e) {
      developer.log('RecentlyViewedApi.getRecentlyViewed: $e', name: 'RecentlyViewedApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to load recently viewed');
    }
  }

  static Future<void> clearAll() async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.delete('/accounts/buyer/recently-viewed');
    } on DioException catch (e) {
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to clear recently viewed');
    }
  }

  static Future<void> recordView(int productId) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.post(
        '/accounts/buyer/recently-viewed',
        data: {'productId': productId},
      );
    } on DioException catch (e) {
      developer.log('RecentlyViewedApi.recordView: $e', name: 'RecentlyViewedApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to record view');
    }
  }
}
