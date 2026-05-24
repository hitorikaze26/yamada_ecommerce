import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/alert_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/open_local_file.dart';
import '../../../../data/models/seller_analytics_model.dart';
import '../../../../data/providers/seller_analytics_notifier.dart';
import 'seller_analytics_constants.dart';
import 'widgets/analytics_category_section.dart';
import 'widgets/analytics_charts.dart';
import 'widgets/analytics_shared.dart';
import 'widgets/analytics_summary_grid.dart';
import 'widgets/analytics_time_range_bar.dart';
import 'widgets/analytics_top_products.dart';

/// Seller analytics screen — uses live data from `GET /seller/analytics`.
class SellerAnalyticsPage extends ConsumerWidget {
  const SellerAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerAnalyticsProvider);
    final notifier = ref.read(sellerAnalyticsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isInitialLoading) {
      return AnalyticsPageSkeleton(isDark: isDark);
    }

    final data = state.data;
    final summary = data?.summary ?? const SellerAnalyticsSummary();
    final salesChart = data?.salesChart ?? const [];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: notifier.fetchAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(
                  periodLabel:
                      SellerAnalyticsConstants.labelForRange(state.timeRange),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                AnalyticsTimeRangeBar(
                  timeRange: state.timeRange,
                  isLoading: state.isLoading,
                  isDownloading: state.isDownloading,
                  onRangeSelected: notifier.setTimeRange,
                  onDownload: () => _onDownload(context, ref),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  AnalyticsErrorBanner(
                    message: state.error!,
                    onRetry: notifier.fetchAnalytics,
                  ),
                ],
                const SizedBox(height: 16),
                AnalyticsSummaryGrid(
                  summary: summary,
                  isLoading: state.isRefreshing,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                AnalyticsSectionCard(
                  title: 'Sales Overview',
                  trailing: data != null
                      ? FormatUtils.pesoCompact(data.chartSalesTotal)
                      : null,
                  isDark: isDark,
                  minHeight: SellerAnalyticsConstants.chartHeight,
                  child: state.isRefreshing
                      ? AnalyticsChartSkeleton(isDark: isDark)
                      : AnalyticsSalesChart(
                          points: salesChart,
                          isDark: isDark,
                        ),
                ),
                const SizedBox(height: 16),
                AnalyticsSectionCard(
                  title: 'Orders Trend',
                  trailing:
                      data != null ? '${data.chartOrdersTotal} orders' : null,
                  isDark: isDark,
                  minHeight: SellerAnalyticsConstants.chartHeight,
                  child: state.isRefreshing
                      ? AnalyticsChartSkeleton(isDark: isDark)
                      : AnalyticsOrdersChart(
                          points: salesChart,
                          isDark: isDark,
                        ),
                ),
                const SizedBox(height: 16),
                AnalyticsSectionCard(
                  title: 'Sales by Category',
                  isDark: isDark,
                  child: state.isRefreshing
                      ? AnalyticsChartSkeleton(isDark: isDark)
                      : AnalyticsCategorySection(
                          categories: data?.categoryData ?? const [],
                          isDark: isDark,
                        ),
                ),
                const SizedBox(height: 16),
                AnalyticsSectionCard(
                  title: 'Top Performing Products',
                  isDark: isDark,
                  child: state.isRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : AnalyticsTopProductsList(
                          products: data?.topProducts ?? const [],
                        ),
                ),
              ],
            ),
          ),
        ),
        if (state.isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _onDownload(BuildContext context, WidgetRef ref) async {
    final path =
        await ref.read(sellerAnalyticsProvider.notifier).downloadReport();
    if (!context.mounted) return;

    if (path != null) {
      developer.log('Analytics download result path: $path',
          name: 'SellerAnalyticsPage');

      if (kIsWeb) {
        if (context.mounted) {
          AlertService.showSnackBar(
            context: context,
            message:
                'Download started — check your browser’s downloads folder',
            variant: AlertVariant.success,
          );
        }
        return;
      }

      // Phone/tablet: a copy already exists in app storage; open the system
      // share sheet so the user can put the PDF in Downloads, Files, Drive, etc.
      final isMobile = defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;

      if (isMobile) {
        try {
          await Share.shareXFiles(
            [
              XFile(
                path,
                mimeType: 'application/pdf',
                name:
                    'yamada-analytics-${DateTime.now().millisecondsSinceEpoch}.pdf',
              ),
            ],
            subject: 'Yamada — sales report',
            text:
                'Choose Save to Files, Downloads, Drive, or another app from the share menu.',
          );
        } catch (e, st) {
          developer.log(
            'Share.shareXFiles failed: $e',
            name: 'SellerAnalyticsPage',
            error: e,
            stackTrace: st,
          );
          await _tryOpenPdfFallback(context, path);
        }
        if (context.mounted) {
          AlertService.showSnackBar(
            context: context,
            message:
                'A copy is in app storage. Use the share menu to save to Downloads or Files.',
            variant: AlertVariant.success,
          );
        }
        return;
      }

      final opened = await _tryOpenPdfFallback(context, path);
      if (context.mounted && opened) {
        AlertService.showSnackBar(
          context: context,
          message: 'Report saved and opened',
          variant: AlertVariant.success,
        );
      }
    } else {
      final err = ref.read(sellerAnalyticsProvider).error;
      AlertService.showSnackBar(
        context: context,
        message: err ?? 'Failed to download report',
        variant: AlertVariant.error,
      );
    }
  }

  /// Desktop / fallback: open with the default PDF app. Returns true if opened OK.
  Future<bool> _tryOpenPdfFallback(BuildContext context, String path) async {
    try {
      final outcome = await openLocalFile(path);
      if (!outcome.ok) {
        if (context.mounted) {
          AlertService.showSnackBar(
            context: context,
            message:
                'PDF saved. Could not open viewer: ${outcome.message}',
            variant: AlertVariant.warning,
          );
        }
        return false;
      }
      return true;
    } catch (e, st) {
      developer.log(
        'openLocalFile failed: $e',
        name: 'SellerAnalyticsPage',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'PDF saved to:\n$path',
          variant: AlertVariant.success,
        );
      }
      return false;
    }
  }
}

class _PageHeader extends StatelessWidget {
  final String periodLabel;
  final bool isDark;

  const _PageHeader({
    required this.periodLabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Track your shop performance and insights.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.grey[400] : AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SellerAnalyticsConstants.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            periodLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SellerAnalyticsConstants.accent,
            ),
          ),
        ),
      ],
    );
  }
}
