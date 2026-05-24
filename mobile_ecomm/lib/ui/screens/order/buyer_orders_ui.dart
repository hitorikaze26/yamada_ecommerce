import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/orders_notifier.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/orders_api.dart';
import '../../widgets/chat/chat_navigation.dart';
import '../../widgets/chat/order_chat_icon_button.dart';
import '../../widgets/store_name_link.dart';
import '../../widgets/buyer_verification_banner.dart';
import '../../../core/report/report_navigation.dart';
import 'order_ui_widgets.dart';

/// Filter tabs for buyer order lists (dashboard + full-screen).
const buyerOrderFilters = <({String label, String value, IconData icon})>[
  (label: 'All', value: 'all', icon: Icons.receipt_long_outlined),
  (label: 'To pay', value: 'to_pay', icon: Icons.payments_outlined),
  (label: 'Processing', value: 'processing', icon: Icons.hourglass_top_outlined),
  (label: 'Packed', value: 'packed', icon: Icons.inventory_2_outlined),
  (label: 'Shipped', value: 'shipped', icon: Icons.local_shipping_outlined),
  (label: 'Delivered', value: 'delivered', icon: Icons.check_circle_outline),
  (label: 'Cancelled', value: 'cancelled', icon: Icons.cancel_outlined),
];

/// Semantic colors for buyer orders screens (light + dark).
class BuyerOrdersTheme {
  final bool isDark;

  const BuyerOrdersTheme(this.isDark);

  Color get background =>
      isDark ? AppColors.darkBackground : AppColors.background;
  Color get foreground =>
      isDark ? AppColors.darkForeground : AppColors.charcoal;
  Color get muted =>
      isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
  Color get card => isDark ? AppColors.darkCard : AppColors.card;
  Color get border => isDark ? AppColors.darkBorder : AppColors.border;
  Color get surfaceMuted =>
      isDark ? AppColors.darkMuted.withValues(alpha: 0.55) : AppColors.muted.withValues(alpha: 0.45);
}

Map<String, int> buyerOrderFilterCounts(List<Order> orders) {
  bool match(Order o, List<String> statuses) =>
      statuses.contains(o.status.toLowerCase());

  return {
    'all': orders.length,
    'to_pay': orders.where((o) => match(o, ['pending'])).length,
    'processing': orders.where((o) => match(o, ['confirmed', 'processing'])).length,
    'packed': orders.where((o) => match(o, ['packed'])).length,
    'shipped': orders.where((o) => match(o, ['shipped', 'out_for_delivery', 'out for delivery'])).length,
    'delivered': orders.where((o) => match(o, ['delivered', 'completed'])).length,
    'cancelled': orders.where((o) => match(o, ['cancelled'])).length,
  };
}

/// Main orders list used in buyer dashboard tab and `/orders` route.
class BuyerOrdersListView extends ConsumerStatefulWidget {
  final String? initialFilter;
  final bool showInlineHeader;

  const BuyerOrdersListView({
    super.key,
    this.initialFilter,
    this.showInlineHeader = true,
  });

  @override
  ConsumerState<BuyerOrdersListView> createState() => _BuyerOrdersListViewState();
}

class _BuyerOrdersListViewState extends ConsumerState<BuyerOrdersListView> {
  String? _busyOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filter = widget.initialFilter;
      if (filter != null && filter.isNotEmpty) {
        ref.read(ordersProvider.notifier).setFilter(filter);
      }
      ref.read(ordersProvider.notifier).fetchOrders();
    });
  }

  void _openDetail(String orderId) {
    context.push(AppRouter.buyerOrderPath(orderId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = BuyerOrdersTheme(
      Theme.of(context).brightness == Brightness.dark,
    );
    final ordersState = ref.watch(ordersProvider);
    final authState = ref.watch(authProvider);
    final buyerUnverified = authState.isAuthenticated &&
        !authState.isVerified &&
        authState.user?.role == UserRole.buyer;
    final filtered = ordersState.filteredOrders;
    final counts = buyerOrderFilterCounts(ordersState.orders);

    return ColoredBox(
      color: theme.background,
      child: ordersState.isLoading && ordersState.orders.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : ordersState.error != null && ordersState.orders.isEmpty
              ? BuyerOrdersErrorState(
                  theme: theme,
                  message: ordersState.error!,
                  onRetry: () => ref.read(ordersProvider.notifier).refresh(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (buyerUnverified)
                      BuyerVerificationBanner(
                        isDark: theme.isDark,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      ),
                    if (widget.showInlineHeader)
                      BuyerOrdersInlineHeader(
                        theme: theme,
                        totalOrders: ordersState.orders.length,
                        filteredCount: filtered.length,
                        activeFilter: ordersState.filterStatus,
                      ),
                    BuyerOrdersFilterBar(
                      theme: theme,
                      selected: ordersState.filterStatus,
                      counts: counts,
                      onSelected: (v) =>
                          ref.read(ordersProvider.notifier).setFilter(v),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: theme.card,
                        onRefresh: () async =>
                            ref.read(ordersProvider.notifier).refresh(),
                        child: filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.sizeOf(context).height * 0.28,
                                  ),
                                  BuyerOrdersEmptyState(
                                    theme: theme,
                                    filter: ordersState.filterStatus,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final order = filtered[index];
                                  return BuyerOrderListCard(
                                    order: order,
                                    theme: theme,
                                    index: index,
                                    isBusy: _busyOrderId == order.id,
                                    onOpenDetail: () => _openDetail(order.id),
                                    onCancel: () => _cancelOrder(order),
                                    onConfirmReceived: () =>
                                        _confirmReceived(order),
                                    onRequestRefund: () =>
                                        _requestRefund(order),
                                    onTrack: () => _trackOrder(order),
                                    onMessageSeller: () => _messageSeller(order),
                                    canMessage: _canMessageSeller(order),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _messageSeller(Order order) async {
    await openBuyerOrderChat(context, ref, order: order);
  }

  bool _canMessageSeller(Order order) {
    if (order.status.toLowerCase() == 'cancelled') return false;
    final storeId = int.tryParse(order.store?.id ?? '') ??
        int.tryParse(order.items.isNotEmpty ? order.items.first.sellerId : '');
    return storeId != null;
  }

  void _trackOrder(Order order) {
    AlertService.showSnackBar(
      context: context,
      message: 'Tracking for order #${order.orderNumber}',
      variant: AlertVariant.info,
    );
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: Text(
          'Cancel order #${order.orderNumber}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyOrderId = order.id);
    try {
      await OrdersApi.cancelOrder(order.id);
      await ref.read(ordersProvider.notifier).fetchOrders();
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Order cancelled',
          variant: AlertVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  Future<void> _confirmReceived(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm received?'),
        content: Text(
          'Mark order #${order.orderNumber} as received?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, received'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyOrderId = order.id);
    try {
      await OrdersApi.confirmReceived(order.id);
      await ref.read(ordersProvider.notifier).fetchOrders();
      if (mounted) {
        context.push(
          '${AppRouter.orderReviewPath(order.id)}?fromConfirm=1',
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  Future<void> _requestRefund(Order order) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.orderNumber}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Tell us what went wrong',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    setState(() => _busyOrderId = order.id);
    try {
      await OrdersApi.requestRefund(order.id, reason: reasonController.text);
      await ref.read(ordersProvider.notifier).fetchOrders();
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Refund request submitted',
          variant: AlertVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _busyOrderId = null);
    }
  }
}

class BuyerOrdersInlineHeader extends StatelessWidget {
  final BuyerOrdersTheme theme;
  final int totalOrders;
  final int filteredCount;
  final String activeFilter;

  const BuyerOrdersInlineHeader({
    super.key,
    required this.theme,
    required this.totalOrders,
    required this.filteredCount,
    required this.activeFilter,
  });

  String get _subtitle {
    if (activeFilter == 'all') {
      return totalOrders == 0
          ? 'Your purchases will appear here'
          : '$totalOrders order${totalOrders == 1 ? '' : 's'} in your history';
    }
    return '$filteredCount shown · $totalOrders total';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: theme.isDark ? 0.35 : 0.2),
                  AppColors.blush.withValues(alpha: theme.isDark ? 0.25 : 0.35),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: theme.isDark ? AppColors.blush : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My orders',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.foreground,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: theme.muted,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BuyerOrdersFilterBar extends StatelessWidget {
  final BuyerOrdersTheme theme;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  const BuyerOrdersFilterBar({
    super.key,
    required this.theme,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < buyerOrderFilters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _BuyerOrderFilterChip(
              theme: theme,
              filter: buyerOrderFilters[i],
              isSelected: selected == buyerOrderFilters[i].value,
              count: counts[buyerOrderFilters[i].value] ?? 0,
              onTap: () => onSelected(buyerOrderFilters[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _BuyerOrderFilterChip extends StatelessWidget {
  final BuyerOrdersTheme theme;
  final ({String label, String value, IconData icon}) filter;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _BuyerOrderFilterChip({
    required this.theme,
    required this.filter,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 0 ? '${filter.label} ($count)' : filter.label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: theme.isDark ? 0.32 : 0.14)
                : theme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : theme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                filter.icon,
                size: 16,
                color: isSelected
                    ? (theme.isDark ? AppColors.blush : AppColors.primary)
                    : theme.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (theme.isDark ? AppColors.blush : AppColors.primary)
                      : theme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyerOrderListCard extends StatelessWidget {
  final Order order;
  final BuyerOrdersTheme theme;
  final int index;
  final bool isBusy;
  final VoidCallback onOpenDetail;
  final VoidCallback onCancel;
  final VoidCallback onConfirmReceived;
  final VoidCallback onRequestRefund;
  final bool canMessage;
  final VoidCallback onTrack;
  final VoidCallback onMessageSeller;

  const BuyerOrderListCard({
    super.key,
    required this.order,
    required this.theme,
    required this.index,
    required this.isBusy,
    required this.canMessage,
    required this.onOpenDetail,
    required this.onCancel,
    required this.onConfirmReceived,
    required this.onRequestRefund,
    required this.onTrack,
    required this.onMessageSeller,
  });

  String _formatPlacedDate(DateTime d) =>
      DateFormat('MMM d, yyyy').format(d);

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final mainItem = order.items.isNotEmpty ? order.items.first : null;
    final rd = order.riderDelivery;
    final status = effectiveOrderStatus(
      order.status,
      riderDeliveryStatus: rd?.status,
      riderProofPhotoUrl: rd?.proofPhotoUrl,
    );
    final canCancel = status == 'pending' || status == 'processing';
    final canConfirm = canBuyerConfirmReceipt(
      order.status,
      riderDeliveryStatus: rd?.status,
      riderProofPhotoUrl: rd?.proofPhotoUrl,
    );
    final canRefund = status == 'delivered' || status == 'completed';
    final showTrack = status != 'cancelled' && status != 'pending';

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: orderSoftSectionDecoration(theme.isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              onTap: onOpenDetail,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.foreground,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatPlacedDate(order.createdAt)} · ${_relativeTime(order.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: theme.muted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    orderStatusPill(status, theme.isDark),
                  ],
                ),
                if (order.paymentMethod != null &&
                    order.paymentMethod!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _MetaChip(
                    theme: theme,
                    icon: Icons.account_balance_wallet_outlined,
                    label: order.paymentMethod!,
                  ),
                ],
                if (mainItem != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.border.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StoreNameLink(
                          name: order.store?.name ?? mainItem.sellerName,
                          storeId: order.store?.id ?? mainItem.sellerId,
                          leadingIcon: Icons.storefront_outlined,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.foreground,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 68,
                                height: 68,
                                color: theme.isDark
                                    ? AppColors.darkMuted
                                    : AppColors.muted,
                                child: mainItem.productImage != null
                                    ? CachedNetworkImage(
                                        imageUrl: ApiClient.resolveImageUrl(
                                              mainItem.productImage,
                                            ) ??
                                            '',
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Icon(
                                          Icons.image_not_supported_outlined,
                                          color: theme.muted,
                                          size: 26,
                                        ),
                                      )
                                    : Icon(
                                        Icons.image_not_supported_outlined,
                                        color: theme.muted,
                                        size: 26,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mainItem.productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.foreground,
                                          height: 1.25,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (mainItem.size != null ||
                                      mainItem.color != null)
                                    Text(
                                      [
                                        if (mainItem.color?.isNotEmpty ?? false)
                                          mainItem.color!,
                                        if (mainItem.size?.isNotEmpty ?? false)
                                          mainItem.size!,
                                      ].join(' · '),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: theme.muted),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quantity: ${mainItem.quantity}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: theme.muted),
                                  ),
                                  if (order.items.length > 1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '+${order.items.length - 1} more item${order.items.length > 2 ? 's' : ''}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _OrderAmountSummary(order: order, theme: theme),
                if (status != 'cancelled' && status != 'pending') ...[
                  const SizedBox(height: 12),
                  _CompactOrderProgress(status: order.status, theme: theme),
                ],
                const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            _OrderActionsBar(
              theme: theme,
              order: order,
              isBusy: isBusy,
              canCancel: canCancel,
              canConfirm: canConfirm,
              canRefund: canRefund,
              showTrack: showTrack,
              onCancel: onCancel,
              onConfirmReceived: onConfirmReceived,
              onRequestRefund: onRequestRefund,
              canMessage: canMessage,
              onTrack: onTrack,
              onMessageSeller: onMessageSeller,
              onOpenDetail: onOpenDetail,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms, delay: Duration(milliseconds: 40 + index * 45))
        .slideY(begin: 0.05, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

/// Action row separated from the tappable card body so CTAs are obvious.
class _OrderActionsBar extends StatelessWidget {
  final BuyerOrdersTheme theme;
  final Order order;
  final bool isBusy;
  final bool canCancel;
  final bool canConfirm;
  final bool canRefund;
  final bool showTrack;
  final VoidCallback onCancel;
  final VoidCallback onConfirmReceived;
  final VoidCallback onRequestRefund;
  final bool canMessage;
  final VoidCallback onTrack;
  final VoidCallback onMessageSeller;
  final VoidCallback onOpenDetail;

  const _OrderActionsBar({
    required this.theme,
    required this.order,
    required this.isBusy,
    required this.canCancel,
    required this.canConfirm,
    required this.canRefund,
    required this.showTrack,
    required this.canMessage,
    required this.onCancel,
    required this.onConfirmReceived,
    required this.onRequestRefund,
    required this.onTrack,
    required this.onMessageSeller,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: theme.border),
          const SizedBox(height: 12),
          if (canConfirm) ...[
            Text(
              'Received your package? Confirm received to complete the order and leave a review.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: theme.muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isBusy ? null : onConfirmReceived,
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Confirm Received'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.delivered,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ] else if (canCancel) ...[
            FilledButton.icon(
              onPressed: isBusy ? null : onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: const Text('Cancel order'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ] else if (canRefund) ...[
            FilledButton.icon(
              onPressed: isBusy ? null : onRequestRefund,
              icon: const Icon(Icons.undo_rounded, size: 20),
              label: const Text('Request refund'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pending,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_storeIdForReport(order) != null)
                OutlinedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () {
                          openReportSubmit(
                            context,
                            targetRole: 'seller',
                            storeId: _storeIdForReport(order),
                            orderId: int.tryParse(order.id),
                            label: order.store?.name ??
                                (order.items.isNotEmpty
                                    ? order.items.first.sellerName
                                    : null),
                          );
                        },
                  icon: const Icon(Icons.storefront_outlined, size: 16),
                  label: const Text('Report store'),
                ),
              if (order.riderDelivery?.rider != null)
                OutlinedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () {
                          final rider = order.riderDelivery!.rider!;
                          openReportSubmit(
                            context,
                            targetRole: 'rider',
                            orderId: int.tryParse(order.id),
                            targetUserId: int.tryParse(rider.id ?? ''),
                            label: rider.name,
                          );
                        },
                  icon: const Icon(Icons.delivery_dining_outlined, size: 16),
                  label: const Text('Report rider'),
                ),
            ],
          ),
          if (_storeIdForReport(order) != null ||
              order.riderDelivery?.rider != null)
            const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canMessage) ...[
                OrderChatIconButton(
                  isDark: theme.isDark,
                  tooltip: 'Message seller',
                  onPressed: isBusy ? null : onMessageSeller,
                ),
                const SizedBox(width: 10),
              ],
              if (showTrack && !canConfirm)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onTrack,
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('Track'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          theme.isDark ? AppColors.blush : AppColors.primary,
                      side: BorderSide(
                        color: theme.isDark
                            ? AppColors.darkBorder
                            : AppColors.border,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (showTrack && !canConfirm) const SizedBox(width: 8),
              TextButton(
                onPressed: isBusy ? null : onOpenDetail,
                style: TextButton.styleFrom(
                  foregroundColor: theme.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Details'),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int? _storeIdForReport(Order order) {
    return int.tryParse(order.store?.id ?? '') ??
        (order.items.isNotEmpty
            ? int.tryParse(order.items.first.sellerId)
            : null);
  }
}

class _OrderAmountSummary extends StatelessWidget {
  final Order order;
  final BuyerOrdersTheme theme;

  const _OrderAmountSummary({required this.order, required this.theme});

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value, bool emphasize})>[
      (
        label: 'Items',
        value: '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
        emphasize: false,
      ),
      if (order.subtotal > 0 && order.subtotal != order.total)
        (label: 'Subtotal', value: FormatUtils.peso(order.subtotal), emphasize: false),
      if (order.shipping > 0)
        (label: 'Shipping', value: FormatUtils.peso(order.shipping), emphasize: false),
      (label: 'Total', value: FormatUtils.peso(order.total), emphasize: true),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rows[i].label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: rows[i].emphasize ? theme.foreground : theme.muted,
                        fontWeight:
                            rows[i].emphasize ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
                Text(
                  rows[i].value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            rows[i].emphasize ? FontWeight.w800 : FontWeight.w600,
                        color: rows[i].emphasize
                            ? AppColors.primary
                            : theme.foreground,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactOrderProgress extends StatelessWidget {
  final String status;
  final BuyerOrdersTheme theme;

  const _CompactOrderProgress({required this.status, required this.theme});

  static const _labels = [
    'Confirmed',
    'Packed',
    'Shipped',
    'Out for delivery',
    'Delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final timelineIndex = orderTimelineActiveIndex(status);
    if (timelineIndex < 0) return const SizedBox.shrink();
    final active = timelineIndex.clamp(0, _labels.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery progress',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(_labels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIndex = i ~/ 2;
              final done = stepIndex < active;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: done
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : theme.border,
                ),
              );
            }
            final stepIndex = i ~/ 2;
            final done = stepIndex <= active;
            return Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.primary
                        : theme.border,
                    border: Border.all(
                      color: done
                          ? AppColors.primary
                          : theme.muted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[stepIndex],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: done ? theme.foreground : theme.muted,
                        fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final BuyerOrdersTheme theme;
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.theme,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class BuyerOrdersEmptyState extends StatelessWidget {
  final BuyerOrdersTheme theme;
  final String filter;

  const BuyerOrdersEmptyState({
    super.key,
    required this.theme,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      'all' => 'No orders yet',
      'to_pay' || 'pending' => 'Nothing waiting for payment',
      'processing' || 'to_ship' => 'No orders in processing',
      'packed' => 'No packed orders',
      'shipped' => 'No orders on the way',
      'delivered' || 'completed' => 'No completed deliveries yet',
      'cancelled' => 'No cancelled orders',
      _ => 'No orders in this view',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.surfaceMuted,
              border: Border.all(color: theme.border),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 40,
              color: theme.muted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.foreground,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you shop with Yamada, your order history will show up here with status updates and receipts.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.muted,
                  height: 1.45,
                ),
          ),
          if (filter == 'all') ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go(AppRouter.home),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Browse products'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BuyerOrdersErrorState extends StatelessWidget {
  final BuyerOrdersTheme theme;
  final String message;
  final VoidCallback onRetry;

  const BuyerOrdersErrorState({
    super.key,
    required this.theme,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: theme.muted),
            const SizedBox(height: 16),
            Text(
              'Could not load orders',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.foreground,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
