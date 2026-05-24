import 'dart:io';

import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../models/problem_report_model.dart';

class ReportsApi {
  static Future<List<ReportTypeModel>> getReportTypes(String targetRole) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get(
        '/reports/types',
        queryParameters: {'targetRole': targetRole},
      );
      final data = response.data;
      final list = data is Map ? data['types'] : null;
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => ReportTypeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load report types'));
    }
  }

  static Future<ProblemReportModel> submitReport({
    required int reportTypeId,
    required String description,
    required String targetRole,
    int? storeId,
    int? orderId,
    int? targetUserId,
    List<File> evidenceFiles = const [],
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      final formData = FormData.fromMap({
        'reportTypeId': reportTypeId,
        'description': description,
        'targetRole': targetRole,
        if (storeId != null) 'storeId': storeId,
        if (orderId != null) 'orderId': orderId,
        if (targetUserId != null) 'targetUserId': targetUserId,
      });

      final files = evidenceFiles.take(5).toList();
      for (final file in files) {
        final name = file.path.split(RegExp(r'[/\\]')).last;
        formData.files.add(
          MapEntry(
            'evidence',
            await MultipartFile.fromFile(file.path, filename: name),
          ),
        );
      }

      final response = await dio.post('/reports', data: formData);
      final data = response.data;
      if (data is Map && data['report'] is Map) {
        return ProblemReportModel.fromJson(
          Map<String, dynamic>.from(data['report'] as Map),
        );
      }
      throw Exception('Unexpected response from server');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to submit report'));
    }
  }

  static Future<List<ProblemReportModel>> getMyReports() async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get('/reports');
      final data = response.data;
      final list = data is Map ? data['reports'] : null;
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => ProblemReportModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load reports'));
    }
  }

  static Future<ProblemReportModel> getMyReport(int reportId) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get('/reports/$reportId');
      final data = response.data;
      if (data is Map && data['report'] is Map) {
        return ProblemReportModel.fromJson(
          Map<String, dynamic>.from(data['report'] as Map),
        );
      }
      throw Exception('Report not found');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load report'));
    }
  }

  static String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['msg'] != null) {
      return data['msg'].toString();
    }
    return fallback;
  }
}
