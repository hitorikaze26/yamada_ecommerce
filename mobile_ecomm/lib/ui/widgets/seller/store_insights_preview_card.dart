import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Accent palette for store insights (dashboard preview + full page).
abstract final class StoreInsightsTheme {
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentDeep = Color(0xFF6D28D9);
  static const Color accentSoft = Color(0xFFD8B4FE);

  static List<Color> cardGradient(bool isDark) => isDark
      ? [
          const Color(0xFF2D2640),
          const Color(0xFF1F1A2E),
        ]
      : [
          const Color(0xFFF5F3FF),
          const Color(0xFFEDE9FE),
        ];

  static Color border(bool isDark) =>
      accent.withValues(alpha: isDark ? 0.5 : 0.28);

  static Color metricSurface(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.85);

  static BoxDecoration pageCardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );
}

/// Three-column metrics strip (rating, wishlist, followers).
class StoreInsightsMetricsRow extends StatelessWidget {
  final bool isLoading;
  final double rating;
  final int wishlistBuyers;
  final int followers;
  final bool isDark;
  final double height;

  const StoreInsightsMetricsRow({
    super.key,
    required this.isLoading,
    required this.rating,
    required this.wishlistBuyers,
    required this.followers,
    required this.isDark,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: isLoading ? _buildLoading() : _buildMetrics(),
    );
  }

  Widget _buildLoading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
            child: _LoadingMetricPlaceholder(isDark: isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightMetricCell(
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFF59E0B),
          value: rating.toStringAsFixed(1),
          label: 'Rating',
          isDark: isDark,
        ),
        _metricDivider(isDark),
        _InsightMetricCell(
          icon: Icons.favorite_rounded,
          iconColor: AppColors.rosewood,
          value: '$wishlistBuyers',
          label: 'Wishlist',
          isDark: isDark,
        ),
        _metricDivider(isDark),
        _InsightMetricCell(
          icon: Icons.people_rounded,
          iconColor: StoreInsightsTheme.accent,
          value: '$followers',
          label: 'Followers',
          isDark: isDark,
        ),
      ],
    );
  }

  static Widget _metricDivider(bool isDark) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      color: StoreInsightsTheme.accent.withValues(alpha: isDark ? 0.25 : 0.15),
    );
  }
}

/// Dashboard tile: rating, wishlist, and followers with tap-through to full insights.
class StoreInsightsPreviewCard extends StatelessWidget {
  final bool isLoading;
  final double rating;
  final int wishlistBuyers;
  final int followers;
  final bool isDark;
  final VoidCallback? onTap;

  const StoreInsightsPreviewCard({
    super.key,
    required this.isLoading,
    required this.rating,
    required this.wishlistBuyers,
    required this.followers,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: StoreInsightsTheme.cardGradient(isDark),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: StoreInsightsTheme.border(isDark),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: StoreInsightsTheme.accent.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                StoreInsightsMetricsRow(
                  isLoading: isLoading,
                  rating: rating,
                  wishlistBuyers: wishlistBuyers,
                  followers: followers,
                  isDark: isDark,
                  height: 48,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titleColor = isDark ? Colors.white : AppColors.charcoal;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: StoreInsightsTheme.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: StoreInsightsTheme.accent,
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Store Insights',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: StoreInsightsTheme.accent.withValues(alpha: 0.9),
        ),
      ],
    );
  }
}

class _LoadingMetricPlaceholder extends StatelessWidget {
  final bool isDark;

  const _LoadingMetricPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? Colors.white24 : Colors.black12;
    return Container(
      decoration: BoxDecoration(
        color: StoreInsightsTheme.metricSurface(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 24,
            height: 10,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 30,
            height: 7,
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightMetricCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isDark;

  const _InsightMetricCell({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = isDark ? Colors.white : AppColors.charcoal;
    final labelColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: StoreInsightsTheme.metricSurface(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                StoreInsightsTheme.accent.withValues(alpha: isDark ? 0.12 : 0.08),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: labelColor,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
