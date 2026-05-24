import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../core/theme/app_colors.dart';
import '../seller_analytics_constants.dart';

/// Card wrapper used for each analytics section.
class AnalyticsSectionCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;
  final double? minHeight;
  final bool isDark;

  const AnalyticsSectionCard({
    super.key,
    required this.title,
    required this.child,
    required this.isDark,
    this.trailing,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                ),
              ),
              if (trailing != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SellerAnalyticsConstants.accent
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SellerAnalyticsConstants.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (minHeight != null)
            SizedBox(height: minHeight, child: child)
          else
            child,
        ],
      ),
    );
  }
}

class AnalyticsGrowthBadge extends StatelessWidget {
  final double growth;
  final bool showWhenZero;

  const AnalyticsGrowthBadge({
    super.key,
    required this.growth,
    this.showWhenZero = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showWhenZero && growth == 0) {
      return const SizedBox.shrink();
    }
    final color = growth >= 0 ? Colors.green.shade600 : Colors.red.shade600;
    return Text(
      '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class AnalyticsEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const AnalyticsEmptyState({
    super.key,
    this.icon = Icons.insights_outlined,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AnalyticsErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-page skeleton while the first analytics payload loads.
class AnalyticsPageSkeleton extends StatelessWidget {
  final bool isDark;

  const AnalyticsPageSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _box(height: 40),
            const SizedBox(height: 12),
            _box(height: 44),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _box(height: 100)),
                const SizedBox(width: 12),
                Expanded(child: _box(height: 100)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _box(height: 100)),
                const SizedBox(width: 12),
                Expanded(child: _box(height: 100)),
              ],
            ),
            const SizedBox(height: 20),
            _box(height: SellerAnalyticsConstants.chartHeight + 48),
            const SizedBox(height: 16),
            _box(height: SellerAnalyticsConstants.chartHeight + 48),
          ],
        ),
      ),
    );
  }

  Widget _box({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class AnalyticsChartSkeleton extends StatelessWidget {
  final bool isDark;

  const AnalyticsChartSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: SellerAnalyticsConstants.chartHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Formats API date keys (`2026-05-06`) for chart axis labels.
String formatChartDateLabel(String raw) {
  if (raw.length >= 10 && raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 3) {
      return '${parts[1]}/${parts[2]}';
    }
  }
  return raw.length > 8 ? raw.substring(0, 8) : raw;
}
