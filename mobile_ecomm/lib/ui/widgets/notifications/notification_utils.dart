import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_model.dart';

class NotificationPresentation {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  const NotificationPresentation({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });
}

NotificationPresentation notificationPresentation(
  AppNotification n,
  bool isDark,
) {
  final title = n.title.toLowerCase();
  final page = (n.page ?? '').toLowerCase();

  if (title.contains('refund') || title.contains('return')) {
    return NotificationPresentation(
      icon: Icons.undo_rounded,
      iconColor: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
      iconBackground: isDark
          ? Colors.orange.withValues(alpha: 0.2)
          : Colors.orange.withValues(alpha: 0.12),
    );
  }
  if (title.contains('stock') ||
      title.contains('inventory') ||
      title.contains('product')) {
    return NotificationPresentation(
      icon: Icons.inventory_2_outlined,
      iconColor: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
      iconBackground: isDark
          ? Colors.amber.withValues(alpha: 0.2)
          : Colors.amber.withValues(alpha: 0.12),
    );
  }
  if (title.contains('delivery') ||
      title.contains('rider') ||
      title.contains('pickup') ||
      title.contains('transit') ||
      page.contains('rider')) {
    return NotificationPresentation(
      icon: Icons.local_shipping_outlined,
      iconColor: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
      iconBackground: isDark
          ? Colors.blue.withValues(alpha: 0.2)
          : Colors.blue.withValues(alpha: 0.12),
    );
  }
  if (title.contains('payout') ||
      title.contains('wallet') ||
      title.contains('payment') ||
      title.contains('earnings')) {
    return NotificationPresentation(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: isDark ? Colors.green.shade200 : Colors.green.shade800,
      iconBackground: isDark
          ? Colors.green.withValues(alpha: 0.2)
          : Colors.green.withValues(alpha: 0.12),
    );
  }
  if (title.contains('approved') ||
      title.contains('rejected') ||
      title.contains('verified') ||
      title.contains('account') ||
      title.contains('registration')) {
    return NotificationPresentation(
      icon: Icons.verified_user_outlined,
      iconColor: isDark ? Colors.teal.shade200 : Colors.teal.shade800,
      iconBackground: isDark
          ? Colors.teal.withValues(alpha: 0.2)
          : Colors.teal.withValues(alpha: 0.12),
    );
  }
  if (title.contains('order') || page.contains('order')) {
    return NotificationPresentation(
      icon: Icons.receipt_long_outlined,
      iconColor: AppColors.primary,
      iconBackground: isDark
          ? AppColors.primary.withValues(alpha: 0.25)
          : AppColors.primary.withValues(alpha: 0.12),
    );
  }

  return NotificationPresentation(
    icon: Icons.notifications_outlined,
    iconColor: isDark ? Colors.grey.shade300 : AppColors.charcoal,
    iconBackground: isDark
        ? Colors.grey.withValues(alpha: 0.25)
        : AppColors.warmGray.withValues(alpha: 0.5),
  );
}
