import 'package:flutter/material.dart';

/// Shared styling for seller analytics (aligned with web `/seller/analytics`).
abstract final class SellerAnalyticsConstants {
  static const Color accent = Color(0xFF10B981);
  static const double chartHeight = 220;

  static const List<Color> categoryColors = [
    Color(0xFFF5A3B5),
    Color(0xFF1B365D),
    Color(0xFFE8D5B7),
    Color(0xFF8B4D62),
    Color(0xFF6B7280),
  ];

  static const timeRanges = <({String key, String label})>[
    (key: '7d', label: '7 Days'),
    (key: '30d', label: '30 Days'),
    (key: '90d', label: '90 Days'),
    (key: '1y', label: '1 Year'),
  ];

  static String labelForRange(String key) {
    for (final r in timeRanges) {
      if (r.key == key) return r.label;
    }
    return '30 Days';
  }
}
