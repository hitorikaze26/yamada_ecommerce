import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/conversation_model.dart';
import 'chat_avatar.dart';
import 'chat_role_badge.dart';
import 'chat_theme.dart';

class ChatThreadHeader extends StatelessWidget {
  final bool isDark;
  final String title;
  final ChatPeer? peer;
  final bool isArchived;
  final VoidCallback onMenu;

  const ChatThreadHeader({
    super.key,
    required this.isDark,
    required this.title,
    this.peer,
    required this.isArchived,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final online = peer?.isOnline == true;
    final role = peer?.role ?? 'user';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.borderSubtle)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: p.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
          ChatAvatar(
            name: title,
            imageUrl: peer?.avatarUrl,
            isOnline: online,
            radius: 20,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.titleMedium(context),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ChatRoleBadge(role: role, isDark: isDark),
                    if (isArchived) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.archive_outlined,
                        size: 14,
                        color: p.textSecondary,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: online ? p.online : p.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      online ? 'Online' : 'Offline',
                      style: p.caption(context).copyWith(
                            fontSize: 11,
                            color: online ? p.online : p.textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: p.textPrimary),
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }
}
