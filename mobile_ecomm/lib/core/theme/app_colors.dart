import 'package:flutter/material.dart';

/// Yamada E-Commerce Color Palette
/// Based on the web client's feminine modern theme
class AppColors {
  // Primary Feminine Colors
  static const Color blush = Color(0xFFF4C9D6);
  static const Color rosewood = Color(0xFFC97A8C);

  // Neutrals
  static const Color offWhite = Color(0xFFFAF7F9);
  static const Color warmGray = Color(0xFFE5E1E6);
  static const Color warmBeige = Color(0xFFF3E7DD);

  // Contrasts
  static const Color navy = Color(0xFF1E2A3A);
  static const Color charcoal = Color(0xFF2E2E2E);

  // Optional Accents
  static const Color lilac = Color(0xFFD7C8F2);
  static const Color peach = Color(0xFFF9D9C4);

  // Semantic Colors (Light Mode)
  static const Color background = offWhite;
  static const Color foreground = charcoal;
  static const Color card = Colors.white;
  static const Color cardForeground = charcoal;
  static const Color primary = rosewood;
  static const Color primaryForeground = Colors.white;
  static const Color secondary = blush;
  static const Color secondaryForeground = charcoal;
  static const Color muted = warmBeige;
  static const Color mutedForeground = Color(0xFF6B6B6B);
  static const Color accent = lilac;
  static const Color accentForeground = charcoal;
  static const Color destructive = Color(0xFFE53E3E);
  static const Color destructiveForeground = Colors.white;
  static const Color border = warmGray;
  static const Color input = warmGray;
  static const Color ring = rosewood;

  // Status Colors
  static const Color pending = Color(0xFFF59E0B);
  static const Color processing = Color(0xFF3B82F6);
  static const Color shipped = Color(0xFF8B5CF6);
  static const Color delivered = Color(0xFF22C55E);
  static const Color cancelled = Color(0xFFEF4444);

  // Status Background Colors
  static const Color pendingBg = Color(0xFFFEF3C7);
  static const Color processingBg = Color(0xFFDBEAFE);
  static const Color shippedBg = Color(0xFFE9D5FF);
  static const Color deliveredBg = Color(0xFFDCFCE7);
  static const Color cancelledBg = Color(0xFFFEE2E2);

  // Status Text Colors (Dark Mode)
  static const Color pendingTextDark = Color(0xFFFCD34D);
  static const Color processingTextDark = Color(0xFF60A5FA);
  static const Color shippedTextDark = Color(0xFFA78BFA);
  static const Color deliveredTextDark = Color(0xFF4ADE80);
  static const Color cancelledTextDark = Color(0xFFF87171);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF1E2A3A);
  static const Color darkForeground = offWhite;
  static const Color darkCard = Color(0xFF2E2E2E);
  static const Color darkCardForeground = offWhite;
  static const Color darkPrimary = blush;
  static const Color darkPrimaryForeground = navy;
  static const Color darkSecondary = rosewood;
  static const Color darkSecondaryForeground = offWhite;
  static const Color darkMuted = Color(0xFF374151);
  static const Color darkMutedForeground = Color(0xFF9CA3AF);
  static const Color darkAccent = lilac;
  static const Color darkAccentForeground = navy;
  static const Color darkDestructive = Color(0xFFF87171);
  static const Color darkDestructiveForeground = navy;
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkInput = Color(0xFF374151);
  static const Color darkRing = blush;

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [rosewood, blush],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0x00FFFFFF), Color(0x33000000)],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  // Chart Colors
  static const List<Color> chartColors = [
    rosewood,
    blush,
    lilac,
    peach,
    navy,
  ];
}
