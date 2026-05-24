import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/seller_analytics_model.dart';
import '../seller_analytics_constants.dart';
import 'analytics_shared.dart';

class AnalyticsCategorySection extends StatelessWidget {
  final List<SellerCategoryDatum> categories;
  final bool isDark;

  const AnalyticsCategorySection({
    super.key,
    required this.categories,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const AnalyticsEmptyState(
        icon: Icons.pie_chart_outline,
        message: 'No category data for this period',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _DonutChartPainter(
              values: categories.map((c) => c.value).toList(),
              colors: SellerAnalyticsConstants.categoryColors,
            ),
            child: const Center(
              child: Icon(
                Icons.pie_chart,
                size: 32,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...categories.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final color =
              SellerAnalyticsConstants.categoryColors[i % SellerAnalyticsConstants.categoryColors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : AppColors.charcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${c.value.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const stroke = 22.0;

    var startAngle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
