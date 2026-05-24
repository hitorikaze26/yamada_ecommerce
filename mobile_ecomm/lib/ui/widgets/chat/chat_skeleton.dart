import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import 'chat_theme.dart';

class ChatListSkeleton extends StatelessWidget {
  final bool isDark;

  const ChatListSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A3444) : AppColors.warmBeige,
      highlightColor: isDark ? const Color(0xFF3D4A5C) : Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class ChatThreadSkeleton extends StatelessWidget {
  final bool isDark;

  const ChatThreadSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A3444) : AppColors.warmBeige,
      highlightColor: isDark ? const Color(0xFF3D4A5C) : Colors.white,
      child: ListView(
        padding: ChatTheme.listPadding,
        children: [
          _bar(isDark, 0.55, align: Alignment.centerLeft),
          const SizedBox(height: 12),
          _bar(isDark, 0.4, align: Alignment.centerRight),
          const SizedBox(height: 12),
          _bar(isDark, 0.65, align: Alignment.centerLeft),
        ],
      ),
    );
  }

  Widget _bar(bool isDark, double width, {required Alignment align}) {
    final surface = ChatPalette(isDark).surface;
    return Align(
      alignment: align,
      child: FractionallySizedBox(
        widthFactor: width,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(ChatTheme.bubbleRadius),
          ),
        ),
      ),
    );
  }
}
