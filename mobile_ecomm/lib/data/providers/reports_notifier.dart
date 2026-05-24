import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/problem_report_model.dart';
import '../services/reports_api.dart';

class ReportsState {
  final List<ReportTypeModel> reportTypes;
  final List<ProblemReportModel> myReports;
  final bool isLoadingTypes;
  final bool isLoadingReports;
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  const ReportsState({
    this.reportTypes = const [],
    this.myReports = const [],
    this.isLoadingTypes = false,
    this.isLoadingReports = false,
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  ReportsState copyWith({
    List<ReportTypeModel>? reportTypes,
    List<ProblemReportModel>? myReports,
    bool? isLoadingTypes,
    bool? isLoadingReports,
    bool? isSubmitting,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ReportsState(
      reportTypes: reportTypes ?? this.reportTypes,
      myReports: myReports ?? this.myReports,
      isLoadingTypes: isLoadingTypes ?? this.isLoadingTypes,
      isLoadingReports: isLoadingReports ?? this.isLoadingReports,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  int get openReportCount =>
      myReports.where((r) => r.isOpen).length;
}

class ReportsNotifier extends StateNotifier<ReportsState> {
  ReportsNotifier() : super(const ReportsState());

  Future<void> fetchReportTypes(String targetRole) async {
    state = state.copyWith(isLoadingTypes: true, clearError: true);
    try {
      final types = await ReportsApi.getReportTypes(targetRole);
      state = state.copyWith(reportTypes: types, isLoadingTypes: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingTypes: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<ProblemReportModel?> submitReport({
    required int reportTypeId,
    required String description,
    required String targetRole,
    int? storeId,
    int? orderId,
    int? targetUserId,
    List<File> evidenceFiles = const [],
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true);
    try {
      final report = await ReportsApi.submitReport(
        reportTypeId: reportTypeId,
        description: description,
        targetRole: targetRole,
        storeId: storeId,
        orderId: orderId,
        targetUserId: targetUserId,
        evidenceFiles: evidenceFiles,
      );
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Report submitted successfully',
      );
      return report;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  Future<void> fetchMyReports() async {
    state = state.copyWith(isLoadingReports: true, clearError: true);
    try {
      final reports = await ReportsApi.getMyReports();
      state = state.copyWith(myReports: reports, isLoadingReports: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingReports: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final reportsProvider =
    StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  return ReportsNotifier();
});
