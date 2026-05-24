import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../models/product_model.dart';

/// Buyer wishlist API — maps to /api/accounts/buyer/wishlist
class WishlistApi {
  static Future<List<Product>> getWishlist() async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get('/accounts/buyer/wishlist');
      if (response.statusCode == 200) {
        final data = response.data['products'] as List? ?? [];
        return data
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load wishlist: ${response.statusCode}');
    } on DioException catch (e) {
      developer.log('WishlistApi.getWishlist: $e', name: 'WishlistApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to load wishlist');
    }
  }

  static Future<void> addToWishlist(int productId) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.post(
        '/accounts/buyer/wishlist',
        data: {'productId': productId},
      );
    } on DioException catch (e) {
      developer.log('WishlistApi.addToWishlist: $e', name: 'WishlistApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to add to wishlist');
    }
  }

  static Future<void> clearWishlist() async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.delete('/accounts/buyer/wishlist');
    } on DioException catch (e) {
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to clear wishlist');
    }
  }

  static Future<void> removeFromWishlist(int productId) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.delete('/accounts/buyer/wishlist/$productId');
    } on DioException catch (e) {
      developer.log('WishlistApi.removeFromWishlist: $e', name: 'WishlistApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to remove from wishlist');
    }
  }
}
