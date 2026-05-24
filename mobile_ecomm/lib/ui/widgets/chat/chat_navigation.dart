import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/alert_service.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/models/pending_order_share.dart';
import '../../../data/providers/chat_notifier.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/seller_orders_notifier.dart';

Future<void> openChatInbox(BuildContext context) async {
  context.push('/chat');
}

PendingOrderShare pendingOrderShareFromBuyerOrder(Order order) {
  final first = order.items.isNotEmpty ? order.items.first : null;
  final name = first?.productName.trim() ?? '';
  final orderId = int.tryParse(order.id) ?? 0;
  return PendingOrderShare(
    orderId: orderId,
    productName: name.isNotEmpty ? name : order.orderNumber,
    productImageUrl: first?.productImage,
    status: order.status,
    totalAmount: order.total,
    displayId: order.orderNumber,
  );
}

/// Buyer order list/detail → chat with order card queued above composer (not auto-sent).
Future<void> openBuyerOrderChat(
  BuildContext context,
  WidgetRef ref, {
  required Order order,
}) async {
  final storeId = int.tryParse(order.store?.id ?? '') ??
      int.tryParse(order.items.isNotEmpty ? order.items.first.sellerId : '');
  if (storeId == null) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Store not available for chat',
        variant: AlertVariant.warning,
      );
    }
    return;
  }
  if (!ref.read(authProvider).isAuthenticated) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Sign in to message this boutique',
        variant: AlertVariant.warning,
      );
      context.push('/login?role=buyer');
    }
    return;
  }
  final orderId = int.tryParse(order.id);
  try {
    final conv = await ref.read(chatProvider.notifier).openBuyerSeller(
          storeId: storeId,
          orderId: orderId,
        );
    ref.read(chatProvider.notifier).setPendingOrderShare(
          conv.id,
          pendingOrderShareFromBuyerOrder(order),
        );
    if (context.mounted) context.push('/chat/${conv.id}');
  } catch (e) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Could not open chat',
        variant: AlertVariant.error,
      );
    }
  }
}

Future<void> openBuyerStoreChat(
  BuildContext context,
  WidgetRef ref, {
  required int storeId,
  int? orderId,
}) async {
  if (!ref.read(authProvider).isAuthenticated) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Sign in to message this boutique',
        variant: AlertVariant.warning,
      );
      context.push('/login?role=buyer');
    }
    return;
  }
  try {
    final conv = await ref.read(chatProvider.notifier).openBuyerSeller(
          storeId: storeId,
          orderId: orderId,
        );
    if (context.mounted) context.push('/chat/${conv.id}');
  } catch (e) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Could not open chat',
        variant: AlertVariant.error,
      );
    }
  }
}

Future<void> openSupportChat(BuildContext context, WidgetRef ref) async {
  if (!ref.read(authProvider).isAuthenticated) {
    if (context.mounted) context.push('/login?role=buyer');
    return;
  }
  try {
    final conv = await ref.read(chatProvider.notifier).openSupport();
    if (context.mounted) context.push('/chat/${conv.id}');
  } catch (e) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Support chat unavailable',
        variant: AlertVariant.error,
      );
    }
  }
}

PendingOrderShare pendingOrderShareFromSellerOrder(SellerOrder order) {
  final first = order.items.isNotEmpty ? order.items.first : null;
  final name = first?.productName.trim() ?? '';
  return PendingOrderShare(
    orderId: order.backendId,
    productName: name.isNotEmpty ? name : order.displayId,
    productImageUrl: first?.productImageUrl,
    status: order.status,
    totalAmount: order.total,
    displayId: order.displayId,
  );
}

/// Seller order detail → chat with order card queued above composer (not auto-sent).
Future<void> openSellerOrderChat(
  BuildContext context,
  WidgetRef ref, {
  required SellerOrder order,
}) async {
  if (order.buyer == null) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Buyer info unavailable for this order',
        variant: AlertVariant.warning,
      );
    }
    return;
  }
  try {
    final conv = await ref
        .read(chatProvider.notifier)
        .openOrderChatAsSeller(order.backendId);
    ref.read(chatProvider.notifier).setPendingOrderShare(
          conv.id,
          pendingOrderShareFromSellerOrder(order),
        );
    if (context.mounted) {
      Navigator.of(context).pop();
      context.push('/chat/${conv.id}');
    }
  } catch (e) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Could not open chat',
        variant: AlertVariant.error,
      );
    }
  }
}

Future<void> openRiderSellerChat(
  BuildContext context,
  WidgetRef ref, {
  required int storeId,
  int? orderId,
}) async {
  try {
    final conv = await ref.read(chatProvider.notifier).openRiderSeller(
          storeId: storeId,
          orderId: orderId,
        );
    if (context.mounted) context.push('/chat/${conv.id}');
  } catch (e) {
    if (context.mounted) {
      AlertService.showSnackBar(
        context: context,
        message: 'Could not open chat',
        variant: AlertVariant.error,
      );
    }
  }
}
