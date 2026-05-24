import 'package:flutter/material.dart';

import 'chat_theme.dart';

class ChatRoleBadge extends StatelessWidget {
  final String role;
  final bool isDark;

  const ChatRoleBadge({super.key, required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ChatTheme.roleBadgeBg(role, isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ChatTheme.roleBadgeColor(role, isDark).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        ChatTheme.roleLabel(role),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: ChatTheme.roleBadgeText(role, isDark),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
