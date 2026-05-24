import 'package:flutter/material.dart';

import 'chat_theme.dart';

class ChatSectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const ChatSectionLabel({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: p.sectionLabel(context),
      ),
    );
  }
}
