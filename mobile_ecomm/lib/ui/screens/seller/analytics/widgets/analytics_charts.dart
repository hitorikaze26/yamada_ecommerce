import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../data/models/seller_analytics_model.dart';
import '../seller_analytics_constants.dart';
import 'analytics_shared.dart';

class AnalyticsSalesChart extends StatelessWidget {
  final List<SellerSalesChartPoint> points;
  final bool isDark;

  const AnalyticsSalesChart({
    super.key,
    required this.points,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AnalyticsEmptyState(
        icon: Icons.show_chart,
        message: 'No sales data for this period',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, SellerAnalyticsConstants.chartHeight),
          painter: _SalesLineChartPainter(
            values: points.map((p) => p.sales).toList(),
            isDark: isDark,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Column(
              children: [
                const Spacer(),
                _ChartAxisLabels(
                  labels: points.map((p) => formatChartDateLabel(p.name)).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnalyticsOrdersChart extends StatelessWidget {
  final List<SellerSalesChartPoint> points;
  final bool isDark;

  const AnalyticsOrdersChart({
    super.key,
    required this.points,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AnalyticsEmptyState(
        icon: Icons.bar_chart,
        message: 'No orders data for this period',
      );
    }

    final maxOrders =
        points.map((p) => p.orders).fold(0, (a, b) => a > b ? a : b);
    final scale = maxOrders > 0 ? 160.0 / maxOrders : 0.0;

    return SizedBox(
      height: SellerAnalyticsConstants.chartHeight,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                final h = (p.orders * scale).clamp(6.0, 160.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Tooltip(
                      message: '${p.orders} orders',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (p.orders > 0)
                            Text(
                              '${p.orders}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: h,
                            decoration: BoxDecoration(
                              color: SellerAnalyticsConstants.accent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          _ChartAxisLabels(
            labels: points.map((p) => formatChartDateLabel(p.name)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChartAxisLabels extends StatelessWidget {
  final List<String> labels;

  const _ChartAxisLabels({required this.labels});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final step = labels.length > 7 ? (labels.length / 5).ceil() : 1;

    return Row(
      children: List.generate(labels.length, (i) {
        final show = i % step == 0 || i == labels.length - 1;
        return Expanded(
          child: Text(
            show ? labels[i] : '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
        );
      }),
    );
  }
}

class _SalesLineChartPainter extends CustomPainter {
  final List<double> values;
  final bool isDark;

  _SalesLineChartPainter({required this.values, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    final chartTop = 28.0;
    final chartBottom = size.height - 28;
    final chartHeight = chartBottom - chartTop;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = chartTop + chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      final val = maxVal * (1 - i / 3);
      final tp = TextPainter(
        text: TextSpan(
          text: FormatUtils.pesoCompact(val),
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final linePaint = Paint()
      ..color = SellerAnalyticsConstants.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = SellerAnalyticsConstants.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final stepX =
        values.length > 1 ? (size.width - 36) / (values.length - 1) : 0.0;
    const leftPad = 36.0;

    final path = Path();
    final fillPath = Path()..moveTo(leftPad, chartBottom);

    for (var i = 0; i < values.length; i++) {
      final x = values.length > 1 ? leftPad + i * stepX : size.width / 2;
      final y = chartBottom - (values[i] / maxVal) * chartHeight;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    final lastX = values.length > 1
        ? leftPad + (values.length - 1) * stepX
        : size.width / 2;
    fillPath
      ..lineTo(lastX, chartBottom)
      ..lineTo(leftPad, chartBottom)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = SellerAnalyticsConstants.accent;
    for (var i = 0; i < values.length; i++) {
      final x = values.length > 1 ? leftPad + i * stepX : size.width / 2;
      final y = chartBottom - (values[i] / maxVal) * chartHeight;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesLineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.isDark != isDark;
}
