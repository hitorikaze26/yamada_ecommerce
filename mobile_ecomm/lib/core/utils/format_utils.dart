import 'package:intl/intl.dart';

/// Shared formatting utilities for the Yamada app.
class FormatUtils {
  FormatUtils._();

  static final _pesoFmt = NumberFormat('#,##0.00', 'en_PH');
  static final _pesoFmtNoDecimal = NumberFormat('#,##0', 'en_PH');

  /// Formats [price] as Philippine Peso with comma separators and 2 decimal
  /// places, e.g. ₱1,000.00
  static String peso(double price) => '₱${_pesoFmt.format(price)}';

  /// Formats [price] as Philippine Peso with no decimal places,
  /// e.g. ₱1,000  — used for display-only whole-number prices.
  static String pesoWhole(double price) =>
      '₱${_pesoFmtNoDecimal.format(price)}';

  /// Sold count for product cards (e.g. "120 sold", "1.2K sold").
  static String soldCount(int count) {
    if (count <= 0) return 'New';
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M sold';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K sold';
    }
    return '$count sold';
  }

  /// Relative time for notifications, e.g. "5m ago", "Yesterday 3:42 PM".
  static String relativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && now.day == dateTime.day) {
      return '${diff.inHours}h ago';
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (day == yesterday) {
      return 'Yesterday ${DateFormat.jm().format(dateTime)}';
    }
    if (diff.inDays < 7) {
      return DateFormat.E().add_jm().format(dateTime);
    }
    return DateFormat.MMMd().add_jm().format(dateTime);
  }

  /// Compact peso for charts and dense UI (e.g. ₱3.7K, ₱1.2M).
  static String pesoCompact(double price) {
    if (price >= 1000000) {
      return '₱${(price / 1000000).toStringAsFixed(1)}M';
    }
    if (price >= 1000) {
      return '₱${(price / 1000).toStringAsFixed(1)}K';
    }
    return pesoWhole(price);
  }
}
