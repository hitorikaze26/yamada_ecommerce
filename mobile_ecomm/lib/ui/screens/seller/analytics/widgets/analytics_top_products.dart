import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../data/models/seller_analytics_model.dart';
import 'analytics_shared.dart';

class AnalyticsTopProductsList extends StatelessWidget {
  final List<SellerTopProduct> products;

  const AnalyticsTopProductsList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AnalyticsEmptyState(
        message: 'No sales data available for this period',
      );
    }

    return Column(
      children: products.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;
        final isLast = index == products.length - 1;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.mutedForeground.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${FormatUtils.pesoWhole(product.revenue)} revenue • ${product.quantitySold} sold',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ProductGrowthLabel(growth: product.growth),
              ],
            ),
            if (!isLast)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _ProductGrowthLabel extends StatelessWidget {
  final double growth;

  const _ProductGrowthLabel({required this.growth});

  @override
  Widget build(BuildContext context) {
    if (growth == 0) {
      return const Text(
        '-',
        style: TextStyle(
          color: AppColors.mutedForeground,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    final color = growth >= 0 ? Colors.green.shade600 : Colors.red.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          growth >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: color,
        ),
        Text(
          '${growth.abs().toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
