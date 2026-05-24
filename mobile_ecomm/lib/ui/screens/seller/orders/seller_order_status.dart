import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Order status tabs shown on the seller orders screen.
const sellerOrderTabs = [
  'all',
  'pending',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
];

const sellerOrderAccent = Color(0xFF10B981);

/// Whether [orderStatus] belongs on the seller orders tab [tab].
bool sellerOrderMatchesTab(String orderStatus, String tab) {
  final s = orderStatus.toLowerCase();
  final t = tab.toLowerCase();
  if (t == 'all') return true;
  if (t == 'delivered') {
    return s == 'delivered' || s == 'completed';
  }
  if (t == 'shipped') {
    return s == 'shipped' || s == 'out_for_delivery';
  }
  return s == t;
}

Color sellerOrderStatusColor(String status, bool isDark) {
  switch (status) {
    case 'pending':
      return isDark ? AppColors.pendingTextDark : AppColors.pending;
    case 'processing':
      return isDark ? AppColors.processingTextDark : AppColors.processing;
    case 'shipped':
      return isDark ? AppColors.shippedTextDark : AppColors.shipped;
    case 'delivered':
    case 'completed':
      return isDark ? AppColors.deliveredTextDark : AppColors.delivered;
    case 'cancelled':
      return isDark ? AppColors.cancelledTextDark : AppColors.cancelled;
    default:
      return AppColors.mutedForeground;
  }
}

Color sellerOrderStatusBg(String status) {
  switch (status) {
    case 'pending':
      return AppColors.pendingBg;
    case 'processing':
      return AppColors.processingBg;
    case 'shipped':
      return AppColors.shippedBg;
    case 'delivered':
    case 'completed':
      return AppColors.deliveredBg;
    case 'cancelled':
      return AppColors.cancelledBg;
    default:
      return AppColors.warmBeige;
  }
}

String sellerOrderStatusLabel(String status) {
  switch (status) {
    case 'all':
      return 'All';
    case 'shipped':
      return 'Ready for Pickup';
    case 'out_for_delivery':
      return 'Out for Delivery';
    case 'completed':
      return 'Completed';
    default:
      if (status.isEmpty) return status;
      return status[0].toUpperCase() + status.substring(1);
  }
}

IconData sellerOrderStatusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.schedule_rounded;
    case 'processing':
      return Icons.sync_rounded;
    case 'shipped':
      return Icons.local_shipping_outlined;
    case 'delivered':
    case 'completed':
      return Icons.check_circle_outline_rounded;
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

String sellerOrderStatShortLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'processing':
      return 'Processing';
    case 'shipped':
      return 'Pickup';
    case 'delivered':
      return 'Delivered';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return sellerOrderStatusLabel(status);
  }
}

String? sellerOrderNextStatus(String status) {
  switch (status) {
    case 'pending':
      return 'processing';
    case 'processing':
      return 'shipped';
    default:
      return null;
  }
}

String sellerOrderActionLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Accept';
    case 'processing':
      return 'Ready';
    default:
      return 'Update';
  }
}

String formatSellerOrderDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatSellerOrderDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m';
}
