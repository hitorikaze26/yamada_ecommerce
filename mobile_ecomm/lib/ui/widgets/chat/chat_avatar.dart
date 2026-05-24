import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'chat_image_url.dart';
import 'chat_theme.dart';

class ChatAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isOnline;
  final double radius;
  final bool isDark;

  const ChatAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.isOnline = false,
    this.radius = 26,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = chatResolveImageUrl(imageUrl);
    final hasUrl = url != null && url.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.accentSoft,
            border: Border.all(
              color: p.borderSubtle,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: hasUrl
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _initial(initial, p),
                    errorWidget: (_, __, ___) => _initial(initial, p),
                  )
                : _initial(initial, p),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: p.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: p.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _initial(String initial, ChatPalette p) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.65,
          color: p.accent,
        ),
      ),
    );
  }
}
