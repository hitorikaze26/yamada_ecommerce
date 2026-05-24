import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/providers/notifications_notifier.dart';
import '../app_count_badge.dart';
import 'notification_navigation.dart';
import 'notification_utils.dart';

class NotificationsPanel extends ConsumerStatefulWidget {
  const NotificationsPanel({super.key});

  @override
  ConsumerState<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<NotificationsPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(notificationsProvider);
    final height = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context, state, isDark),
          const Divider(height: 1),
          Expanded(child: _buildBody(context, state, isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    NotificationsState state,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkForeground : AppColors.foreground,
            ),
          ),
          if (state.unreadCount > 0) ...[
            const SizedBox(width: 8),
            AppCountBadge(
              count: state.unreadCount,
              size: AppBadgeSize.medium,
              isDark: isDark,
            ),
          ],
          const Spacer(),
          if (state.unreadCount > 0)
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationsState state,
    bool isDark,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(notificationsProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updates about your orders and account will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final groups = _groupByDate(state.items);

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final entry in groups.entries) ...[
            _sectionHeader(entry.key, isDark),
            const SizedBox(height: 8),
            ...entry.value.map(
              (n) => _NotificationTile(
                notification: n,
                isDark: isDark,
                onTap: () => _onTap(context, n),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _onTap(BuildContext context, AppNotification n) async {
    if (!n.read) {
      await ref.read(notificationsProvider.notifier).markRead(n.id);
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    navigateFromNotification(context, n);
  }

  Map<String, List<AppNotification>> _groupByDate(List<AppNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayList = <AppNotification>[];
    final yesterdayList = <AppNotification>[];
    final earlierList = <AppNotification>[];

    for (final n in items) {
      final d = n.createdAt;
      if (d == null) {
        earlierList.add(n);
        continue;
      }
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) {
        todayList.add(n);
      } else if (day == yesterday) {
        yesterdayList.add(n);
      } else {
        earlierList.add(n);
      }
    }

    final result = <String, List<AppNotification>>{};
    if (todayList.isNotEmpty) result['Today'] = todayList;
    if (yesterdayList.isNotEmpty) result['Yesterday'] = yesterdayList;
    if (earlierList.isNotEmpty) result['Earlier'] = earlierList;
    return result;
  }

  Widget _sectionHeader(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pres = notificationPresentation(notification, isDark);
    final time = FormatUtils.relativeTime(notification.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pres.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(pres.icon, color: pres.iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notification.read
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkForeground
                                    : AppColors.foreground,
                              ),
                            ),
                          ),
                          if (!notification.read)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
