import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../data/models/conversation_model.dart';
import 'chat_actions_sheet.dart';
import 'chat_avatar.dart';
import 'chat_role_badge.dart';
import '../app_count_badge.dart';
import 'chat_theme.dart';

class ChatConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const ChatConversationTile({
    super.key,
    required this.conversation,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
    required this.onArchive,
    required this.onDelete,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('h:mm a').format(local);
    }
    if (now.difference(local).inDays < 7) {
      return DateFormat('EEE').format(local);
    }
    return DateFormat('MMM d').format(local);
  }

  void _openMenu(BuildContext context) {
    ChatConversationListMenuSheet.show(
      context,
      isDark: isDark,
      isArchived: conversation.isArchived,
      onArchive: onArchive,
      onDelete: onDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final c = conversation;
    final time = _formatTime(c.lastMessageAt);
    final preview = c.lastMessagePreview.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(ChatTheme.cardRadius),
          child: Ink(
            decoration: p.cardDecoration(radius: ChatTheme.cardRadius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatAvatar(
                    name: c.title,
                    imageUrl: c.peer.avatarUrl,
                    isOnline: c.peer.isOnline,
                    isDark: isDark,
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
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: p.titleMedium(context).copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (c.isPinned)
                              Icon(
                                Icons.push_pin_rounded,
                                size: 14,
                                color: p.accent.withValues(alpha: 0.85),
                              ),
                            if (c.peer.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: p.accent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        ChatRoleBadge(role: c.peer.role, isDark: isDark),
                        const SizedBox(height: 6),
                        Text(
                          preview.isNotEmpty ? preview : 'No messages yet',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: p.caption(context).copyWith(
                                fontSize: 13,
                                height: 1.35,
                                color: preview.isNotEmpty
                                    ? p.textSecondary
                                    : p.textHint,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          time,
                          style: p.caption(context).copyWith(fontSize: 11),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: p.textSecondary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () => _openMenu(context),
                        ),
                        if (c.unreadCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: AppCountBadge(
                              count: c.unreadCount,
                              size: AppBadgeSize.small,
                              isDark: isDark,
                            )
                                .animate(
                                  onPlay: (ctrl) => ctrl.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.05, 1.05),
                                  duration: 800.ms,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
