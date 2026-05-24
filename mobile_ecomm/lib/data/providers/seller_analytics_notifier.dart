import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/seller_analytics_ranges.dart';
import '../models/seller_analytics_model.dart';
import '../services/seller_analytics_api.dart';

class SellerAnalyticsState {
  final String timeRange;
  final SellerAnalyticsData? data;
  final bool isLoading;
  final bool isDownloading;
  final String? error;
  final String? lastDownloadPath;

  const SellerAnalyticsState({
    this.timeRange = '30d',
    this.data,
    this.isLoading = false,
    this.isDownloading = false,
    this.error,
    this.lastDownloadPath,
  });

  int get days => SellerAnalyticsRanges.daysFor(timeRange);

  /// First visit — show full-page skeleton.
  bool get isInitialLoading => isLoading && data == null;

  /// Range change / pull-to-refresh — keep prior data visible.
  bool get isRefreshing => isLoading && data != null;

  bool get hasData => data != null && !isInitialLoading;

  SellerAnalyticsState copyWith({
    String? timeRange,
    SellerAnalyticsData? data,
    bool? isLoading,
    bool? isDownloading,
    String? error,
    String? lastDownloadPath,
    bool clearError = false,
    bool clearDownloadPath = false,
  }) {
    return SellerAnalyticsState(
      timeRange: timeRange ?? this.timeRange,
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      error: clearError ? null : (error ?? this.error),
      lastDownloadPath:
          clearDownloadPath ? null : (lastDownloadPath ?? this.lastDownloadPath),
    );
  }
}

class SellerAnalyticsNotifier extends StateNotifier<SellerAnalyticsState> {
  SellerAnalyticsNotifier() : super(const SellerAnalyticsState(isLoading: true)) {
    fetchAnalytics();
  }

  Future<void> setTimeRange(String range) async {
    if (range == state.timeRange) return;
    state = state.copyWith(timeRange: range, clearError: true);
    await fetchAnalytics();
  }

  Future<void> fetchAnalytics() async {
    final hadData = state.data != null;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final raw = await SellerAnalyticsApi.getAnalytics(state.days);
      final data = SellerAnalyticsData.fromJson(raw);
      developer.log(
        'Analytics ${state.days}d: revenue=${data.summary.totalRevenue}, '
        'orders=${data.summary.totalOrders}, chartPoints=${data.salesChart.length}',
        name: 'SellerAnalyticsNotifier',
      );
      state = state.copyWith(data: data, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      // Clear stale data only on first failed load
      if (!hadData) {
        state = state.copyWith(data: null);
      }
    }
  }

  Future<String?> downloadReport() async {
    state = state.copyWith(isDownloading: true, clearError: true);
    try {
      final path = await SellerAnalyticsApi.downloadReport(state.days);
      state = state.copyWith(isDownloading: false, lastDownloadPath: path);
      return path;
    } catch (e, stackTrace) {
      developer.log(
        'downloadReport failed: $e',
        name: 'SellerAnalyticsNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isDownloading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }
}

final sellerAnalyticsProvider = StateNotifierProvider.autoDispose<
    SellerAnalyticsNotifier, SellerAnalyticsState>((ref) {
  return SellerAnalyticsNotifier();
});
