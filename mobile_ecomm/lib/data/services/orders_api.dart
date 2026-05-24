import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../models/order_model.dart';
import '../models/address_model.dart';
import '../models/product_review_model.dart';

/// Orders API Service
/// Maps to Flask backend endpoints under /api/orders
class OrdersApi {
  /// Get buyer's orders
  /// GET /api/orders
  static Future<List<Order>> getBuyerOrders() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/orders');

      if (response.statusCode == 200) {
        final List<dynamic> ordersData = response.data['orders'] ?? [];
        return ordersData.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching buyer orders: $e', name: 'OrdersApi');
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Get order by ID
  /// GET /api/orders/{orderId}
  static Future<Order> getOrderById(String orderId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/orders/$orderId');

      if (response.statusCode == 200) {
        // Backend returns { order: {...} }
        final orderData = response.data['order'] ?? response.data;
        return Order.fromJson(orderData);
      } else {
        throw Exception('Failed to fetch order: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching order: $e', name: 'OrdersApi');
      throw Exception('Failed to fetch order: $e');
    }
  }

  /// Create new order (checkout)
  /// POST /api/orders
  static Future<Order> createOrder({
    required List<Map<String, dynamic>> items,
    required AddressData shippingAddress,
    required String paymentMethod,
    String? notes,
    String? couponCode,
    double? shippingFee,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      
      // Build the order data matching the backend structure
      final orderData = {
        'items': items,
        'shippingAddress': shippingAddress.toJson(),
        'paymentMethod': paymentMethod,
        if (notes != null) 'notes': notes,
        if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
        if (shippingFee != null) 'shippingFee': shippingFee,
      };

      final response = await dio.post(
        '/orders/checkout',
        data: orderData,
      );

      if (response.statusCode == 201) {
        // Return the created order
        return Order.fromJson(response.data['order']);
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      developer.log(
        'Error creating order: ${e.response?.statusCode} - ${e.response?.data}',
        name: 'OrdersApi',
      );
      // Extract detailed error message from server response
      final responseData = e.response?.data;
      String errorMsg = 'Failed to create order';
      if (responseData is Map) {
        errorMsg = responseData['msg'] ?? 
                   responseData['message'] ?? 
                   responseData['error'] ??
                   'Server error: ${e.response?.statusCode}';
      } else if (responseData is String) {
        errorMsg = responseData;
      }
      throw Exception(errorMsg);
    } catch (e) {
      developer.log('Error creating order: $e', name: 'OrdersApi');
      throw Exception('Failed to create order: $e');
    }
  }

  /// Cancel order
  /// PUT /api/orders/{orderId}/cancel
  static Future<void> cancelOrder(String orderId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.put('/orders/$orderId/cancel');

      if (response.statusCode != 200) {
        throw Exception('Failed to cancel order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      developer.log('Error canceling order: $e', name: 'OrdersApi');
      final data = e.response?.data;
      final msg = data is Map ? (data['msg'] ?? data['message'])?.toString() : null;
      throw Exception(msg ?? 'Failed to cancel order');
    } catch (e) {
      developer.log('Error canceling order: $e', name: 'OrdersApi');
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Get order tracking status
  /// GET /api/orders/{orderId}/tracking
  static Future<Map<String, dynamic>> getOrderTracking(String orderId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/orders/$orderId/tracking');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch tracking: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching order tracking: $e', name: 'OrdersApi');
      throw Exception('Failed to fetch tracking: $e');
    }
  }

  /// Confirm order received
  /// POST /api/orders/{orderId}/confirm-received
  static Future<Order> confirmReceived(String orderId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post('/orders/$orderId/confirm-received');

      if (response.statusCode == 200) {
        return Order.fromJson(response.data['order']);
      } else {
        throw Exception('Failed to confirm order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      developer.log(
        'Error confirming order: ${e.response?.statusCode} - ${e.response?.data}',
        name: 'OrdersApi',
      );
      final responseData = e.response?.data;
      String errorMsg = 'Failed to confirm order received';
      if (responseData is Map) {
        errorMsg = responseData['msg'] ?? responseData['message'] ?? 'Server error';
      }
      throw Exception(errorMsg);
    } catch (e) {
      developer.log('Error confirming order: $e', name: 'OrdersApi');
      throw Exception('Failed to confirm order: $e');
    }
  }

  /// Request refund for order
  /// POST /api/orders/{orderId}/refund-request
  static Future<void> requestRefund(String orderId, {String? reason}) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post(
        '/orders/$orderId/refund-request',
        data: {'reason': reason ?? ''},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to request refund: ${response.statusCode}');
      }
    } on DioException catch (e) {
      developer.log(
        'Error requesting refund: ${e.response?.statusCode} - ${e.response?.data}',
        name: 'OrdersApi',
      );
      final responseData = e.response?.data;
      String errorMsg = 'Failed to request refund';
      if (responseData is Map) {
        errorMsg = responseData['msg'] ?? responseData['message'] ?? 'Server error';
      }
      throw Exception(errorMsg);
    } catch (e) {
      developer.log('Error requesting refund: $e', name: 'OrdersApi');
      throw Exception('Failed to request refund: $e');
    }
  }

  /// GET /api/orders/{orderId}/reviews
  static Future<OrderReviewsData> getOrderReviews(String orderId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/orders/$orderId/reviews');
    return OrderReviewsData.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// POST /api/orders/{orderId}/reviews
  static Future<void> addReview(
    String orderId, {
    required int orderItemId,
    required String reviewFormat,
    int? overallRating,
    required Map<String, int> ratings,
    String? customerReview,
    required int deliverySatisfaction,
    required List<String> deliveryPills,
  }) async {
    final dio = await ApiClient.getInstance();
    await dio.post(
      '/orders/$orderId/reviews',
      data: {
        'orderItemId': orderItemId,
        'reviewFormat': reviewFormat,
        if (overallRating != null) 'overallRating': overallRating,
        'ratings': ratings,
        if (customerReview != null && customerReview.isNotEmpty)
          'customerReview': customerReview,
        'deliverySatisfaction': deliverySatisfaction,
        'deliveryPills': deliveryPills,
      },
    );
  }
}
