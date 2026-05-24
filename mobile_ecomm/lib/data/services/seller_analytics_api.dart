import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import 'analytics_pdf_download.dart';

/// Seller analytics API — mirrors web `sellerApi.getAnalytics` / `downloadReport`.
class SellerAnalyticsApi {
  /// GET /seller/analytics?days={days}
  static Future<Map<String, dynamic>> getAnalytics(int days) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get(
        '/seller/analytics',
        queryParameters: {'days': days},
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Unexpected analytics response');
      }
      return Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      throw Exception(_messageFromDioData(e) ?? 'Failed to load analytics');
    }
  }

  /// GET /seller/analytics/download?days={days} — server-generated PDF.
  static Future<String> downloadReport(int days) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get(
        '/seller/analytics/download',
        queryParameters: {'days': days},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      if (response.statusCode != 200) {
        throw Exception(
          _messageFromResponse(response) ??
              'Failed to download report (${response.statusCode})',
        );
      }
      final bytes = _responseBytes(response.data);
      if (bytes.isEmpty) {
        throw Exception('Empty PDF response from server');
      }
      final path = await persistAndOpenAnalyticsPdf(bytes, days);
      developer.log(
        'Analytics PDF from server: $path (${bytes.length} bytes)',
        name: 'SellerAnalyticsApi',
      );
      return path;
    } on DioException catch (e) {
      throw Exception(_messageFromDioData(e) ?? 'Failed to download report');
    }
  }

  static String? _messageFromDioData(DioException e) {
    return _messageFromResponse(e.response);
  }

  static String? _messageFromResponse(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map) {
      final msg = data['msg'];
      if (msg != null) return msg.toString();
    }
    if (data is List<int> || data is Uint8List) {
      try {
        final text = utf8.decode(
          data is Uint8List ? data : Uint8List.fromList(data),
          allowMalformed: true,
        );
        if (text.trimLeft().startsWith('{')) {
          final decoded = jsonDecode(text) as Map<String, dynamic>;
          final msg = decoded['msg'];
          if (msg != null) return msg.toString();
        }
      } catch (_) {}
    }
    return null;
  }

  static Uint8List _responseBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is List) {
      return Uint8List.fromList(data.map((e) => (e as num).toInt()).toList());
    }
    throw Exception('Invalid PDF response from server');
  }
}
