import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Semantic colors and layout tokens for chat screens (light + dark).
class ChatPalette {
  final bool isDark;

  const ChatPalette(this.isDark);

  factory ChatPalette.of(BuildContext context) {
    return ChatPalette(Theme.of(context).brightness == Brightness.dark);
  }

  // Surfaces
  Color get screenBg => isDark ? AppColors.darkBackground : AppColors.offWhite;
  Color get surface => isDark ? AppColors.darkCard : AppColors.card;
  Color get surfaceMuted =>
      isDark ? const Color(0xFF252D3A) : AppColors.warmBeige.withValues(alpha: 0.35);
  Color get threadBg =>
      isDark ? const Color(0xFF1A2433) : AppColors.offWhite;
  Color get inputBarBg => isDark ? AppColors.darkCard : AppColors.card;
  Color get inputFieldBg =>
      isDark ? const Color(0xFF252D3A) : AppColors.offWhite;

  // Text
  Color get textPrimary =>
      isDark ? AppColors.darkForeground : AppColors.charcoal;
  Color get textSecondary =>
      isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
  Color get textHint => isDark
      ? AppColors.darkMutedForeground.withValues(alpha: 0.8)
      : AppColors.mutedForeground;

  // Accent & borders
  Color get accent => isDark ? AppColors.blush : AppColors.rosewood;
  Color get accentSoft =>
      isDark ? AppColors.blush.withValues(alpha: 0.2) : AppColors.blush.withValues(alpha: 0.45);
  Color get border =>
      isDark ? AppColors.darkBorder : AppColors.warmGray;
  Color get borderSubtle => isDark
      ? AppColors.darkBorder.withValues(alpha: 0.6)
      : AppColors.warmGray.withValues(alpha: 0.55);

  // Status
  Color get online => const Color(0xFF4ADE80);
  Color get unreadBadge => isDark ? AppColors.blush : AppColors.rosewood;

  TextStyle titleLarge(BuildContext context) =>
      (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: textPrimary,
            letterSpacing: -0.3,
          );

  TextStyle titleMedium(BuildContext context) =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: textPrimary,
          );

  TextStyle bodyMedium(BuildContext context) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
            fontSize: 14,
            color: textPrimary,
            height: 1.4,
          );

  TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 12,
        color: textSecondary,
        height: 1.3,
      );

  TextStyle sectionLabel(BuildContext context) => TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      );

  BoxDecoration cardDecoration({double radius = 18}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderSubtle),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      );

  InputDecoration searchDecoration({String hint = 'Search conversations'}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: textHint, fontSize: 14),
      prefixIcon: Icon(Icons.search_rounded, color: accent, size: 22),
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _inputBorder(16),
      enabledBorder: _inputBorder(16),
      focusedBorder: _inputBorder(16).copyWith(
        borderSide: BorderSide(color: accent, width: 1),
      ),
    );
  }

  OutlineInputBorder _inputBorder(double radius) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: borderSubtle),
      );
}

class ChatTheme {
  static const double bubbleRadius = 18;
  static const double inputRadius = 24;
  static const double cardRadius = 18;
  static const EdgeInsets listPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  static Color screenBg(bool isDark) => ChatPalette(isDark).screenBg;
  static Color cardBg(bool isDark) => ChatPalette(isDark).surface;

  static BoxDecoration bubbleDecoration({
    required String senderRole,
    required bool isMine,
    required bool isDark,
  }) {
    final p = ChatPalette(isDark);
    Color bg;
    Color border = Colors.transparent;

    if (senderRole == 'admin') {
      bg = isDark
          ? AppColors.lilac.withValues(alpha: 0.22)
          : AppColors.lilac.withValues(alpha: 0.4);
      border = AppColors.lilac.withValues(alpha: isDark ? 0.35 : 0.5);
    } else if (senderRole == 'rider') {
      bg = isDark
          ? AppColors.peach.withValues(alpha: 0.18)
          : AppColors.peach.withValues(alpha: 0.5);
    } else if (isMine || senderRole == 'buyer') {
      bg = isDark
          ? AppColors.rosewood.withValues(alpha: 0.42)
          : AppColors.blush.withValues(alpha: 0.9);
    } else {
      bg = isDark ? const Color(0xFF353535) : AppColors.card;
      border = p.borderSubtle;
    }

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(bubbleRadius),
        topRight: const Radius.circular(bubbleRadius),
        bottomLeft: Radius.circular(isMine ? bubbleRadius : 8),
        bottomRight: Radius.circular(isMine ? 8 : bubbleRadius),
      ),
      border: border == Colors.transparent
          ? null
          : Border.all(color: border, width: 1),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: AppColors.charcoal.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  static Color bubbleTextColor({
    required String senderRole,
    required bool isMine,
    required bool isDark,
  }) {
    final p = ChatPalette(isDark);
    if (senderRole == 'admin' || senderRole == 'rider' || isMine || senderRole == 'buyer') {
      return isDark ? AppColors.offWhite : AppColors.charcoal;
    }
    return p.textPrimary;
  }

  static String roleLabel(String role) {
    switch (role) {
      case 'seller':
        return 'Seller';
      case 'buyer':
        return 'Buyer';
      case 'admin':
        return 'Support';
      case 'rider':
        return 'Rider';
      default:
        return role;
    }
  }

  static Color roleBadgeBg(String role, bool isDark) {
    final base = roleBadgeColor(role, isDark);
    return base.withValues(alpha: isDark ? 0.28 : 0.5);
  }

  static Color roleBadgeColor(String role, bool isDark) {
    switch (role) {
      case 'seller':
        return isDark ? AppColors.blush : AppColors.rosewood;
      case 'buyer':
        return isDark ? AppColors.peach : AppColors.blush;
      case 'admin':
        return AppColors.lilac;
      case 'rider':
        return AppColors.peach;
      default:
        return isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
    }
  }

  static Color roleBadgeText(String role, bool isDark) {
    return isDark ? AppColors.offWhite : AppColors.charcoal;
  }
}
