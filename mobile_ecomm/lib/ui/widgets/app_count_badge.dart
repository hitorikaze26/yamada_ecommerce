import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppBadgeSize { small, medium }

/// Unified count badge (chat, notifications, cart) — rosewood with high-contrast label.
class AppCountBadge extends StatelessWidget {
  final int count;
  final AppBadgeSize size;
  final bool isDark;

  const AppCountBadge({
    super.key,
    required this.count,
    this.size = AppBadgeSize.medium,
    this.isDark = false,
  });

  static Color backgroundColor = AppColors.rosewood;

  static Color borderColor(bool isDark) =>
      isDark ? AppColors.darkCard : Colors.white;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final label = count > 99 ? '99+' : '$count';
    final height = size == AppBadgeSize.small ? 18.0 : 20.0;
    final fontSize = size == AppBadgeSize.small ? 10.0 : 11.0;
    final isSingleDigit = label.length == 1;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: height,
        minHeight: height,
      ),
      child: SizedBox(
        height: height,
        width: isSingleDigit ? height : null,
        child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: isSingleDigit ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              isSingleDigit ? null : BorderRadius.circular(height / 2),
          border: Border.all(color: borderColor(isDark), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isSingleDigit ? 0 : 5),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.3,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 1,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
