import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Square chat launcher used on buyer/seller order screens (matches seller orders UI).
class OrderChatIconButton extends StatelessWidget {
  final bool isDark;
  final String tooltip;
  final VoidCallback? onPressed;

  const OrderChatIconButton({
    super.key,
    required this.isDark,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? AppColors.blush : AppColors.rosewood;
    final bg = isDark ? const Color(0xFF252D3A) : AppColors.offWhite;
    final border = isDark ? AppColors.darkBorder : AppColors.warmGray;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: border.withValues(alpha: isDark ? 0.9 : 0.55),
              ),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 22,
              color: onPressed == null ? iconColor.withValues(alpha: 0.4) : iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
