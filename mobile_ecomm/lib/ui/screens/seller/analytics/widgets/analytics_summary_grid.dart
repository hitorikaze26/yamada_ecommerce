import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../data/models/seller_analytics_model.dart';
import 'analytics_shared.dart';

class AnalyticsSummaryGrid extends StatelessWidget {
  final SellerAnalyticsSummary summary;
  final bool isLoading;
  final bool isDark;

  const AnalyticsSummaryGrid({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.28,
      children: [
        _AnalyticsStatCard(
          icon: Icons.payments_outlined,
          label: 'Total Revenue',
          value: isLoading ? null : FormatUtils.pesoWhole(summary.totalRevenue),
          growth: summary.revenueGrowth,
          color: Colors.green,
          isDark: isDark,
        ),
        _AnalyticsStatCard(
          icon: Icons.shopping_bag_outlined,
          label: 'Total Orders',
          value: isLoading ? null : '${summary.totalOrders}',
          growth: summary.ordersGrowth,
          color: Colors.blue,
          isDark: isDark,
        ),
        _AnalyticsStatCard(
          icon: Icons.people_outline,
          label: 'Customers',
          value: isLoading ? null : '${summary.totalCustomers}',
          growth: null,
          color: Colors.purple,
          isDark: isDark,
        ),
        _AnalyticsStatCard(
          icon: Icons.trending_up,
          label: 'Avg. Order Value',
          value: isLoading ? null : FormatUtils.pesoWhole(summary.avgOrderValue),
          growth: null,
          color: Colors.amber,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _AnalyticsStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final double? growth;
  final Color color;
  final bool isDark;

  const _AnalyticsStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.growth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (growth != null)
                AnalyticsGrowthBadge(growth: growth!, showWhenZero: true),
            ],
          ),
          const Spacer(),
          if (value == null)
            Container(
              height: 22,
              width: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
            )
          else
            Text(
              value!,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.charcoal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
