import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';

/// Result of fetching rider deliveries.
class RiderDeliveriesResult {
  final List<dynamic> deliveries;
  final bool notVerified;
  final String? errorMessage;

  const RiderDeliveriesResult({
    this.deliveries = const [],
    this.notVerified = false,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null && !notVerified;
}

/// Rider API Service — maps to Flask endpoints under /api/rider
class RiderApi {
  static String _messageFrom(DioException e, String fallback) {
    final msg = e.response?.data;
    if (msg is Map && msg['msg'] != null) {
      return msg['msg'].toString();
    }
    return fallback;
  }

  /// GET /api/rider/dashboard
  static Future<Map<String, dynamic>> getDashboard() async {
    final dio = await ApiClient.getInstance();

    try {
      final response = await dio.get('/rider/dashboard');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageFrom(e, 'Failed to load dashboard'));
    }
  }

  /// GET /api/rider/deliveries
  static Future<RiderDeliveriesResult> getDeliveries() async {
    final dio = await ApiClient.getInstance();

    try {
      final response = await dio.get('/rider/deliveries');
      final data = response.data;
      final list = data is Map ? (data['deliveries'] ?? []) : [];
      return RiderDeliveriesResult(
        deliveries: List<dynamic>.from(list),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final msg = _messageFrom(e, '');
        if (msg.toLowerCase().contains('not yet verified') ||
            msg.toLowerCase().contains('not yet approved')) {
          return const RiderDeliveriesResult(notVerified: true);
        }
      }
      return RiderDeliveriesResult(
        errorMessage: _messageFrom(e, 'Failed to load deliveries'),
      );
    }
  }

  /// PUT /api/rider/deliveries/{id}/status
  static Future<void> updateDeliveryStatus(int deliveryId, String status) async {
    final dio = await ApiClient.getInstance();

    try {
      await dio.put(
        '/rider/deliveries/$deliveryId/status',
        data: {'status': status},
      );
    } on DioException catch (e) {
      throw Exception(_messageFrom(e, 'Failed to update status'));
    }
  }

  /// POST /api/rider/orders/{orderId}/accept
  static Future<void> acceptDelivery(int orderId) async {
    final dio = await ApiClient.getInstance();

    try {
      await dio.post('/rider/orders/$orderId/accept');
    } on DioException catch (e) {
      final msg = _messageFrom(e, 'Failed to accept delivery');
      if (e.response?.statusCode == 400 &&
          msg.toLowerCase().contains('already assigned')) {
        throw Exception(
          'This delivery was already accepted by another rider.',
        );
      }
      throw Exception(msg);
    }
  }

  /// POST /api/rider/deliveries/{id}/proof
  static Future<void> uploadDeliveryProof(
    int deliveryId, {
    String? note,
    File? photo,
  }) async {
    final dio = await ApiClient.getInstance();

    try {
      final formData = FormData.fromMap({
        if (note != null && note.isNotEmpty) 'note': note,
        if (photo != null)
          'photo': await MultipartFile.fromFile(
            photo.path,
            filename: photo.path.split(Platform.pathSeparator).last,
          ),
      });

      await dio.post(
        '/rider/deliveries/$deliveryId/proof',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw Exception(_messageFrom(e, 'Failed to upload proof'));
    }
  }
}
