import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../models/order_model.dart';

/// Cart API Service for database operations
class CartApi {
  /// Get user's cart from database
  static Future<List<CartItem>> getCart() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/cart/get-cart');

      if (response.statusCode == 200 && response.data != null) {
        final cartData = response.data['cart'];
        if (cartData != null && cartData['items'] != null) {
          final items = (cartData['items'] as List)
              .map((item) => _parseCartItem(item))
              .whereType<CartItem>()
              .toList();
          return items;
        }
      }
      return [];
    } on DioException catch (e) {
      developer.log('Error fetching cart: ${e.response?.data}', name: 'CartApi');
      throw Exception(e.response?.data?['error'] ?? 'Failed to fetch cart');
    } catch (e) {
      developer.log('Error fetching cart: $e', name: 'CartApi');
      throw Exception('Failed to fetch cart: $e');
    }
  }

  /// Add item to cart in database
  static Future<void> addToCart({
    required String productId,
    required String variationId,
    required int quantity,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post(
        '/cart/add-to-cart',
        data: {
          'productId': productId,
          'variationId': variationId,
          'quantity': quantity,
        },
      );

      if (response.statusCode != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to add to cart');
      }
    } on DioException catch (e) {
      developer.log('Error adding to cart: ${e.response?.data}', name: 'CartApi');
      throw Exception(e.response?.data?['error'] ?? 'Failed to add to cart');
    } catch (e) {
      developer.log('Error adding to cart: $e', name: 'CartApi');
      throw Exception('Failed to add to cart: $e');
    }
  }

  /// Update cart item quantity
  static Future<void> updateQuantity({
    required int itemId,
    required int quantity,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.put(
        '/cart/update-cart-item/$itemId',
        data: {'quantity': quantity},
      );

      if (response.statusCode != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to update quantity');
      }
    } on DioException catch (e) {
      developer.log('Error updating quantity: ${e.response?.data}', name: 'CartApi');
      throw Exception(e.response?.data?['error'] ?? 'Failed to update quantity');
    } catch (e) {
      developer.log('Error updating quantity: $e', name: 'CartApi');
      throw Exception('Failed to update quantity: $e');
    }
  }

  /// Remove item from cart
  static Future<void> removeItem(int itemId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.delete('/cart/remove-from-cart/$itemId');

      if (response.statusCode != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to remove item');
      }
    } on DioException catch (e) {
      developer.log('Error removing item: ${e.response?.data}', name: 'CartApi');
      throw Exception(e.response?.data?['error'] ?? 'Failed to remove item');
    } catch (e) {
      developer.log('Error removing item: $e', name: 'CartApi');
      throw Exception('Failed to remove item: $e');
    }
  }

  /// Clear entire cart
  static Future<void> clearCart() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.delete('/cart/clear-cart');

      if (response.statusCode != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to clear cart');
      }
    } on DioException catch (e) {
      developer.log('Error clearing cart: ${e.response?.data}', name: 'CartApi');
      throw Exception(e.response?.data?['error'] ?? 'Failed to clear cart');
    } catch (e) {
      developer.log('Error clearing cart: $e', name: 'CartApi');
      throw Exception('Failed to clear cart: $e');
    }
  }

  /// Parse cart item from JSON
  static CartItem? _parseCartItem(dynamic item) {
    try {
      if (item == null) return null;
      
      // Handle nested product object from backend
      final product = item['product'];
      final variation = item['variation'];
      
      return CartItem(
        id: item['id']?.toString() ?? '',
        productId: item['productId']?.toString() ?? product?['id']?.toString() ?? '',
        productName: product?['name'] ?? 'Unknown Product',
        productImage: ApiClient.resolveImageUrl(product?['imageUrl']) ?? ApiClient.resolveImageUrl(product?['images']?.first),
        productPrice: (product?['price'] ?? item['priceAtAdd'] ?? 0).toDouble(),
        salePrice: product?['salePrice']?.toDouble(),
        quantity: item['quantity'] ?? 1,
        size: variation?['size'],
        color: variation?['color'],
        sku: variation?['sku']?.toString(),
        productSlug: product?['slug'] ?? product?['id']?.toString(),
        sellerId: item['sellerId']?.toString() ?? '',
        sellerName: item['sellerName'] ?? 'Unknown Seller',
      );
    } catch (e, stackTrace) {
      developer.log('Error parsing cart item: $e\n$stackTrace', name: 'CartApi');
      return null;
    }
  }
}
