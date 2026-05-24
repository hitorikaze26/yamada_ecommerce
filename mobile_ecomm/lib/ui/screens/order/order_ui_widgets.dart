import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart' show effectiveOrderStatus;
export '../../../data/models/order_model.dart'
    show canBuyerConfirmReceiptForOrder, effectiveOrderStatusForOrder;

/// Soft layered section (glass-lite) for order screens.
BoxDecoration orderSoftSectionDecoration(bool isDark) {
  return BoxDecoration(
    color: isDark
        ? AppColors.darkCard.withValues(alpha: 0.94)
        : AppColors.card.withValues(alpha: 0.96),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark
          ? AppColors.darkBorder.withValues(alpha: 0.85)
          : AppColors.border.withValues(alpha: 0.65),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

String normalizeOrderStatus(String status) {
  return status.toLowerCase().trim().replaceAll(' ', '_');
}

bool canBuyerConfirmReceipt(
  String orderStatus, {
  String? riderDeliveryStatus,
  String? riderProofPhotoUrl,
  bool? riderHasProofPhoto,
}) {
  final raw = normalizeOrderStatus(orderStatus);
  if (const {'completed', 'cancelled', 'canceled', 'returned', 'pending'}.contains(raw)) {
    return false;
  }
  final effective = effectiveOrderStatus(
    orderStatus,
    riderDeliveryStatus: riderDeliveryStatus,
    riderProofPhotoUrl: riderProofPhotoUrl,
    riderHasProofPhoto: riderHasProofPhoto,
  );
  return effective == 'delivered' || raw == 'out_for_delivery';
}

bool shouldPollOrderStatus(
  String orderStatus, {
  String? riderDeliveryStatus,
  String? riderProofPhotoUrl,
  bool? riderHasProofPhoto,
}) {
  final s = effectiveOrderStatus(
    orderStatus,
    riderDeliveryStatus: riderDeliveryStatus,
    riderProofPhotoUrl: riderProofPhotoUrl,
    riderHasProofPhoto: riderHasProofPhoto,
  );
  return {
    'confirmed',
    'processing',
    'packed',
    'shipped',
    'out_for_delivery',
  }.contains(s);
}

/// Human-readable buyer-facing order status label.
String formatOrderStatusLabel(String status) {
  switch (normalizeOrderStatus(status)) {
    case 'pending':
      return 'Pending payment';
    case 'confirmed':
      return 'Confirmed';
    case 'processing':
      return 'Processing';
    case 'packed':
      return 'Packed';
    case 'shipped':
      return 'Shipped';
    case 'out_for_delivery':
      return 'Out for delivery';
    case 'delivered':
      return 'Delivered';
    case 'completed':
      return 'Completed';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    case 'returned':
      return 'Returned';
    case 'pickup':
      return 'Pickup';
    case 'transit':
      return 'On the way';
    default:
      if (status.isEmpty) return '—';
      return status
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
  }
}

/// Display label for buyer-facing order status (pill text).
(String label, Color fg, Color bg) orderStatusStyle(String status) {
  switch (normalizeOrderStatus(status)) {
    case 'pending':
      return ('To pay', AppColors.pending, AppColors.pendingBg);
    case 'pickup':
      return ('Pickup', AppColors.processing, AppColors.processingBg);
    case 'transit':
      return ('On the way', AppColors.shipped, AppColors.shippedBg);
    case 'confirmed':
    case 'processing':
      return ('Processing', AppColors.processing, AppColors.processingBg);
    case 'packed':
      return ('Packed', AppColors.shipped, AppColors.shippedBg);
    case 'shipped':
      return ('Shipped', AppColors.shipped, AppColors.shippedBg);
    case 'out_for_delivery':
      return ('Out for delivery', AppColors.shipped, AppColors.shippedBg);
    case 'delivered':
    case 'completed':
      return ('Delivered', AppColors.delivered, AppColors.deliveredBg);
    case 'cancelled':
    case 'canceled':
      return ('Cancelled', AppColors.cancelled, AppColors.cancelledBg);
    case 'returned':
      return ('Returned', AppColors.cancelled, AppColors.cancelledBg);
    default:
      return (
        formatOrderStatusLabel(status),
        AppColors.mutedForeground,
        AppColors.muted,
      );
  }
}

Color _orderStatusTextColor(String status, bool isDark, Color lightFg) {
  if (!isDark) return lightFg;
  switch (normalizeOrderStatus(status)) {
    case 'pending':
      return AppColors.pendingTextDark;
    case 'confirmed':
    case 'processing':
      return AppColors.processingTextDark;
    case 'packed':
    case 'shipped':
    case 'out_for_delivery':
      return AppColors.shippedTextDark;
    case 'delivered':
    case 'completed':
      return AppColors.deliveredTextDark;
    case 'cancelled':
      return AppColors.cancelledTextDark;
    default:
      return AppColors.darkForeground;
  }
}

Widget orderStatusPill(String status, bool isDark) {
  final (label, fg, bg) = orderStatusStyle(status);
  final textColor = _orderStatusTextColor(status, isDark, fg);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg.withValues(alpha: isDark ? 0.22 : 0.9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: textColor.withValues(alpha: isDark ? 0.45 : 0.35),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.25,
      ),
    ),
  );
}

/// Timeline step index: 0 confirmed, 1 packed, 2 shipped, 3 out for delivery, 4 delivered
int orderTimelineActiveIndex(String status) {
  final s = normalizeOrderStatus(status);
  if (s == 'cancelled' || s == 'canceled' || s == 'returned') return -1;
  if (s == 'pending') return -1;
  if (s == 'confirmed' || s == 'processing') return 0;
  if (s == 'packed') return 1;
  if (s == 'shipped') return 2;
  if (s == 'out_for_delivery') return 3;
  if (s == 'delivered' || s == 'completed') return 4;
  return 0;
}

class OrderTrackingTimeline extends StatelessWidget {
  final String status;
  final bool isDark;

  const OrderTrackingTimeline({
    super.key,
    required this.status,
    required this.isDark,
  });

  static const _steps = [
    ('Order confirmed', Icons.checkroom_outlined),
    ('Packed', Icons.inventory_2_outlined),
    ('Shipped', Icons.local_shipping_outlined),
    ('Out for delivery', Icons.delivery_dining_outlined),
    ('Delivered', Icons.favorite_border_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeOrderStatus(status);
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'This order was cancelled.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
                height: 1.4,
              ),
        ),
      );
    }
    if (normalized == 'pending') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Tracking updates after your order is confirmed for processing.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
                height: 1.4,
              ),
        ),
      );
    }

    final active = orderTimelineActiveIndex(status);
    if (active < 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Status: ${formatOrderStatusLabel(status)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
                height: 1.4,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_steps.length, (i) {
        final done = i <= active;
        final isLast = i == _steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : (isDark ? AppColors.darkMuted : AppColors.muted),
                    border: Border.all(
                      color: done
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    _steps[i].$2,
                    size: 14,
                    color: done ? AppColors.primary : AppColors.mutedForeground,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 28,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: done
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : (isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
                child: Text(
                  _steps[i].$1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                        color: done
                            ? (isDark
                                ? AppColors.darkForeground
                                : AppColors.charcoal)
                            : AppColors.mutedForeground,
                      ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Rounded back control for order detail header.
Widget orderDetailBackButton(BuildContext context, bool isDark) {
  return Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Material(
      color: isDark
          ? AppColors.darkCard.withValues(alpha: 0.9)
          : AppColors.card.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (context.canPop()) {
            context.pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? AppColors.darkForeground : AppColors.charcoal,
          ),
        ),
      ),
    ),
  );
}
