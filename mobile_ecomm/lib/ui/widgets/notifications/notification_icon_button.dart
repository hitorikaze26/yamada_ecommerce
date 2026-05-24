import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/notifications_notifier.dart';
import '../app_count_badge.dart';
import 'show_notifications_panel.dart';

/// Shared notification bell with unread badge — use on buyer, seller, rider headers.
class NotificationIconButton extends ConsumerWidget {
  final bool isDark;
  final Color? accentColor;
  final bool compact;

  const NotificationIconButton({
    super.key,
    required this.isDark,
    this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);
    final accent = accentColor ?? AppColors.primary;

    return GestureDetector(
      onTap: () => showNotificationsPanel(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: compact ? 40 : 44,
            height: compact ? 40 : 44,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCard
                  : accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : accent.withValues(alpha: 0.25),
              ),
              boxShadow: compact
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: compact ? 20 : 22,
              color: isDark ? Colors.white : accent,
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: AppCountBadge(
                count: unread,
                size: AppBadgeSize.medium,
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }
}
