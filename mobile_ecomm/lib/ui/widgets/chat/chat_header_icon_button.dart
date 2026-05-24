import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/chat_notifier.dart';
import '../app_count_badge.dart';

/// Header chat icon with unread badge — use on buyer, seller, and rider home screens.
class ChatHeaderIconButton extends ConsumerStatefulWidget {
  final bool isDark;
  final bool compact;

  const ChatHeaderIconButton({
    super.key,
    required this.isDark,
    this.compact = false,
  });

  @override
  ConsumerState<ChatHeaderIconButton> createState() =>
      _ChatHeaderIconButtonState();
}

class _ChatHeaderIconButtonState extends ConsumerState<ChatHeaderIconButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBadge());
  }

  @override
  void didUpdateWidget(ChatHeaderIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBadge());
  }

  void _refreshBadge() {
    if (!ref.read(authProvider).isAuthenticated) return;
    ref.read(chatProvider.notifier).refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(chatUnreadCountProvider);
    final isDark = widget.isDark;
    final size = widget.compact ? 36.0 : 40.0;
    final iconColor = isDark ? AppColors.blush : AppColors.rosewood;

    return GestureDetector(
      onTap: () => context.push('/chat'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.charcoal
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppColors.warmGray.withValues(alpha: 0.3)
                    : AppColors.warmGray,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: widget.compact ? 20 : 22,
              color: iconColor,
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
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
