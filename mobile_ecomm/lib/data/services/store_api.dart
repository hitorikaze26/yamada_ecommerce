import 'dart:developer' as developer;

import '../../core/services/api_client.dart';
import '../models/product_model.dart';
import '../models/store_profile_model.dart';
import 'products_api.dart';

class StoreApi {
  static Future<StoreProfile> getStoreProfile(String storeId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/stores/$storeId');
    if (response.statusCode == 200) {
      final data = response.data['store'] as Map<String, dynamic>? ?? response.data;
      return StoreProfile.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Failed to load store: ${response.statusCode}');
  }

  static Future<List<StoreReview>> getStoreReviews(
    String storeId, {
    int limit = 30,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/stores/$storeId/reviews',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        final list = response.data['reviews'] as List? ?? [];
        return list
            .map((e) => StoreReview.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      developer.log('Store reviews error: $e', name: 'StoreApi');
    }
    return [];
  }

  static Future<Map<String, int>> getReviewBreakdown(String storeId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/stores/$storeId/reviews', queryParameters: {'limit': 1});
      if (response.statusCode == 200) {
        final raw = response.data['breakdown'] as Map<String, dynamic>? ?? {};
        return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    return {};
  }

  static Future<List<Product>> getStoreProducts(
    String storeId, {
    int limit = 100,
    String? sort,
  }) async {
    List<Product> parsed = [];
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/stores/$storeId/products',
        queryParameters: {
          'limit': limit,
          if (sort != null) 'sort': sort,
        },
      );
      if (response.statusCode == 200) {
        final list = response.data['products'] as List? ?? [];
        parsed = _parseProductList(list);
      }
    } catch (e) {
      developer.log('Store products error: $e', name: 'StoreApi');
    }

    if (parsed.isNotEmpty) return parsed;

    // Fallback: list products via /products?seller= (same store_id filter on server)
    try {
      return await ProductsApi.getProducts(
        seller: storeId,
        limit: limit,
        sort: sort,
      );
    } catch (e) {
      developer.log('Store products fallback error: $e', name: 'StoreApi');
      return [];
    }
  }

  static List<Product> _parseProductList(List<dynamic> list) {
    final products = <Product>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      try {
        products.add(Product.fromJson(Map<String, dynamic>.from(raw)));
      } catch (e) {
        developer.log('Skip invalid product json: $e', name: 'StoreApi');
      }
    }
    return products;
  }

  static Future<List<Map<String, dynamic>>> getFeaturedStores({int limit = 6}) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/stores/featured', queryParameters: {'limit': limit});
      if (response.statusCode == 200) {
        final list = response.data['stores'] as List? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      developer.log('Featured stores error: $e', name: 'StoreApi');
    }
    return [];
  }
}
