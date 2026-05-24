import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/orders_notifier.dart';
import '../../../data/services/orders_api.dart';
import 'dart:async';
import 'dart:convert';

import '../../widgets/chat/chat_navigation.dart';
import '../../widgets/chat/order_chat_icon_button.dart';
import '../../widgets/report_problem_sheet.dart';
import '../../../core/report/report_navigation.dart';
import '../../widgets/store_name_link.dart';
import 'order_ui_widgets.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailPage({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  Order? _order;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _schedulePolling() {
    _pollTimer?.cancel();
    final order = _order;
    if (order == null) return;
    final rd = order.riderDelivery;
    if (!shouldPollOrderStatus(
      order.status,
      riderDeliveryStatus: rd?.status,
      riderProofPhotoUrl: rd?.proofPhotoUrl,
      riderHasProofPhoto: rd?.hasProofPhoto,
    )) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _loadOrder(silent: true);
    });
  }

  bool _shouldShowDeliverySection(Order order) {
    final s = normalizeOrderStatus(order.status);
    final rd = order.riderDelivery;
    if (rd != null) {
      final hasProof = rd.hasProofPhoto ||
          (rd.proofPhotoUrl != null && rd.proofPhotoUrl!.trim().isNotEmpty);
      final hasProofNote = rd.proofNote != null && rd.proofNote!.trim().isNotEmpty;
      if (rd.rider != null || hasProof || hasProofNote) return true;
    }
    return s == 'shipped' || s == 'out_for_delivery' || s == 'delivered';
  }

  Future<void> _loadOrder({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final order = await OrdersApi.getOrderById(widget.orderId);

      if (!mounted) return;
      setState(() {
        _order = order;
        if (!silent) _isLoading = false;
      });
      _schedulePolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _error = 'Failed to load order: $e';
          _isLoading = false;
        }
      });
    }
  }

  String _formatPrice(double price) => FormatUtils.peso(price);

  bool _canReportRider(String status) {
    final s = status.toLowerCase();
    return s == 'out_for_delivery' || s == 'delivered' || s == 'completed';
  }

  String _formatVariation(OrderItem item) {
    final parts = <String>[];
    if (item.color != null && item.color!.isNotEmpty) parts.add(item.color!);
    if (item.size != null && item.size!.isNotEmpty) parts.add(item.size!);
    if (parts.isEmpty) return '';
    return parts.join(' / ');
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'confirmed':
        return Icons.mark_email_read_outlined;
      case 'processing':
        return Icons.inventory_2_outlined;
      case 'packed':
        return Icons.all_inbox_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'out_for_delivery':
        return Icons.delivery_dining_outlined;
      case 'delivered':
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: orderDetailBackButton(context, isDark),
        title: Text(
          'Order details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            onPressed: _loadOrder,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadOrder,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_order == null) {
      return const Center(child: Text('Order not found'));
    }

    final order = _order!;

    return RefreshIndicator(
      onRefresh: _loadOrder,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order status + timeline
          _buildStatusCard(order, isDark),

          if (normalizeOrderStatus(order.status) == 'out_for_delivery') ...[
            const SizedBox(height: 12),
            _buildOutForDeliveryBanner(isDark),
          ],

          if (_canReportRider(order.status)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final oid = int.tryParse(order.id);
                showReportProblemSheet(
                  context,
                  category: ReportCategory.rider,
                  orderId: oid,
                );
              },
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report delivery issue'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],

          if (order.status.toLowerCase() == 'cancelled') ...[
            const SizedBox(height: 14),
            _buildCancellationCard(order, isDark),
          ],

          if (order.store != null &&
              (order.store!.name?.isNotEmpty == true ||
                  order.store!.email?.isNotEmpty == true)) ...[
            const SizedBox(height: 14),
            _buildSellerCard(order, isDark),
          ],

          const SizedBox(height: 14),
          
          // Order Items Card
          _buildItemsCard(order, isDark),
          
          const SizedBox(height: 16),
          
          // Order Summary Card
          _buildSummaryCard(order, isDark),
          
          const SizedBox(height: 16),
          
          // Shipping Address Card
          _buildAddressCard(order, isDark),
          
          const SizedBox(height: 16),
          
          // Payment Method Card
          _buildPaymentCard(order, isDark),
          
          const SizedBox(height: 16),
          
          // Rider / proof / in-transit delivery card
          if (_shouldShowDeliverySection(order)) _buildRiderCard(order, isDark),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          _buildActionButtons(order, isDark),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Order order, bool isDark) {
    final (_, fg, _) = orderStatusStyle(order.status);
    final titleColor = isDark ? AppColors.darkForeground : AppColors.charcoal;

    return Container(
      decoration: orderSoftSectionDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: fg,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      orderStatusPill(order.status, isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Order date', order.formattedDate),
                _buildInfoColumn('Items', '${order.items.length}'),
                _buildInfoColumn('Total', _formatPrice(order.total)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            Text(
              'Progress',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                    letterSpacing: 0.4,
                  ),
            ),
            const SizedBox(height: 10),
            OrderTrackingTimeline(
              status: effectiveOrderStatus(
                order.status,
                riderDeliveryStatus: order.riderDelivery?.status,
                riderProofPhotoUrl: order.riderDelivery?.proofPhotoUrl,
                riderHasProofPhoto: order.riderDelivery?.hasProofPhoto,
              ),
              isDark: isDark,
            ),
            if (canBuyerConfirmReceipt(
              order.status,
              riderDeliveryStatus: order.riderDelivery?.status,
              riderProofPhotoUrl: order.riderDelivery?.proofPhotoUrl,
              riderHasProofPhoto: order.riderDelivery?.hasProofPhoto,
            )) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.deliveredBg.withValues(alpha: isDark ? 0.35 : 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.delivered.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your package has been delivered. Please confirm when you have received all items in good condition.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkMutedForeground
                                : AppColors.mutedForeground,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          _isLoading ? null : () => _confirmReceived(order),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Confirm Received'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.delivered,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0.0),
    );
  }

  Widget _buildConfirmDeliveryBanner(Order order, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deliveredBg.withValues(alpha: isDark ? 0.35 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.delivered.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: AppColors.delivered, size: 22),
              const SizedBox(width: 8),
              Text(
                'Confirm received',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.delivered,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Received your package? Confirm received to finish this order and share feedback.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _confirmReceived(order),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Confirm Received'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.delivered,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveReviewBanner(Order order, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: orderSoftSectionDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate your order',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about the products and delivery.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(AppRouter.orderReviewPath(order.id)),
            icon: const Icon(Icons.star_rounded),
            label: const Text('Write Review'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ],
      ),
    );
  }

  Widget _buildOutForDeliveryBanner(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.shippedBg.withValues(alpha: isDark ? 0.2 : 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.shipped.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.delivery_dining_outlined,
            color: AppColors.shipped,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your order is on the way. A rider may contact you before delivery. '
              'This screen refreshes automatically for status updates.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: isDark ? AppColors.shippedTextDark : AppColors.shipped,
                  ),
            ),
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeIn(delay: 0.02));
  }

  Widget _buildCancellationCard(Order order, bool isDark) {
    return Container(
      decoration: orderSoftSectionDecoration(isDark).copyWith(
        border: Border.all(
          color: AppColors.cancelled.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.cancelled.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This order was cancelled. If you were charged, refunds follow your payment provider\'s timeline.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                    ),
              ),
            ),
          ],
        ),
      ),
    ).animate(effects: AppAnimations.fadeIn(delay: 0.02));
  }

  Widget _buildSellerCard(Order order, bool isDark) {
    final store = order.store!;
    final fg = isDark ? AppColors.darkForeground : AppColors.charcoal;

    return Container(
      decoration: orderSoftSectionDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Seller',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (store.name?.isNotEmpty == true)
              StoreNameLink(
                name: store.name!,
                storeId: store.id,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: fg,
                ),
              ),
            if (store.email?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                store.email!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                openReportSubmit(
                  context,
                  targetRole: 'seller',
                  storeId: int.tryParse(store.id ?? ''),
                  orderId: int.tryParse(order.id),
                  label: store.name,
                );
              },
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: const Text('Report store'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    ).animate(effects: AppAnimations.fadeIn(delay: 0.05));
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsCard(Order order, bool isDark) {
    return Container(
      decoration: orderSoftSectionDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            Divider(
              height: 28,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            ...order.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildItemRow(item, isDark, index);
            }),
          ],
        ),
      ),
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0.1),
    );
  }

  Widget _buildItemRow(OrderItem item, bool isDark, int index) {
    final resolved = item.productImage != null
        ? ApiClient.resolveImageUrl(item.productImage)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
              child: resolved != null && resolved.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: resolved,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.mutedForeground,
                        size: 24,
                      ),
                    )
                  : Icon(
                      Icons.image_outlined,
                      color: AppColors.mutedForeground,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                StoreNameLink(
                  name: item.sellerName,
                  storeId: _order?.store?.id ?? item.sellerId,
                  leadingIcon: Icons.storefront_outlined,
                  iconSize: 13,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_formatVariation(item).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatVariation(item),
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Qty ${item.quantity}',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(item.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              if (item.salePrice != null && item.salePrice! < item.price)
                Text(
                  _formatPrice(item.price * item.quantity),
                  style: TextStyle(
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.mutedForeground,
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate(
      effects: AppAnimations.staggeredItem(index: index),
    );
  }

  Widget _buildSummaryCard(Order order, bool isDark) {
    return Container(
      decoration: orderSoftSectionDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Order summary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            Divider(
              height: 28,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            _buildSummaryRow('Subtotal', _formatPrice(order.subtotal)),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Shipping',
              order.shipping == 0 ? 'Free' : _formatPrice(order.shipping),
              valueColor: order.shipping == 0 ? AppColors.delivered : null,
            ),
            Divider(
              height: 28,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            _buildSummaryRow(
              'Total',
              _formatPrice(order.total),
              isBold: true,
              valueColor: AppColors.primary,
            ),
          ],
        ),
      ),
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0.2),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: isBold ? AppColors.mutedForeground : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(Order order, bool isDark) {
    // Check if we have structured address parts first
    if (order.shippingAddressParts != null) {
      final addressParts = order.shippingAddressParts!;
      final formattedAddress = addressParts.fullAddress;
      
      if (formattedAddress.isNotEmpty) {
        return _buildAddressCardContent(formattedAddress, isDark);
      }
    }
    
    // Fallback to parsing the raw shipping address
    if (order.shippingAddress == null || order.shippingAddress!.isEmpty) {
      return const SizedBox.shrink();
    }

    String displayAddress = _formatShippingAddress(order.shippingAddress!);
    
    if (displayAddress.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildAddressCardContent(displayAddress, isDark);
  }

  String _formatShippingAddress(String rawAddress) {
    print('_formatShippingAddress - Raw address: $rawAddress');
    
    // Try to parse JSON-like address
    try {
      // Handle proper JSON strings first
      if (rawAddress.trim().startsWith('{') && rawAddress.trim().endsWith('}')) {
        print('Detected JSON-like address, parsing...');
        
        // Try to parse as proper JSON first
        try {
          Map<String, dynamic> addressJson = jsonDecode(rawAddress);
          print('Parsed as JSON: $addressJson');
          
          List<String> addressParts = [];
          
          // Add parts in logical order
          if (addressJson['streetAddress']?.toString().isNotEmpty == true) {
            addressParts.add(addressJson['streetAddress'].toString());
          }
          if (addressJson['barangayName']?.toString().isNotEmpty == true) {
            addressParts.add(addressJson['barangayName'].toString());
          }
          if (addressJson['municipalityName']?.toString().isNotEmpty == true) {
            addressParts.add(addressJson['municipalityName'].toString());
          }
          if (addressJson['provinceName']?.toString().isNotEmpty == true) {
            addressParts.add(addressJson['provinceName'].toString());
          }
          if (addressJson['regionName']?.toString().isNotEmpty == true) {
            addressParts.add(addressJson['regionName'].toString());
          }
          if (addressJson['postalCode']?.toString().isNotEmpty == true) {
            addressParts.add(addressJson['postalCode'].toString());
          }
          
          String formatted = addressParts.join(', ');
          print('Formatted address from JSON: $formatted');
          return formatted;
        } catch (jsonError) {
          print('Failed to parse as JSON, trying manual parsing: $jsonError');
          
          // Fallback to manual parsing for malformed JSON
          String cleaned = rawAddress.trim();
          cleaned = cleaned.substring(1, cleaned.length - 1); // Remove { }
          
          Map<String, String> addressMap = {};
          
          // Split by comma and parse key-value pairs
          List<String> pairs = cleaned.split(',');
          for (String pair in pairs) {
            List<String> keyValue = pair.split(':');
            if (keyValue.length == 2) {
              String key = keyValue[0].trim().replaceAll('"', '').replaceAll("'", "");
              String value = keyValue[1].trim().replaceAll('"', '').replaceAll("'", "");
              addressMap[key] = value;
            }
          }
          
          print('Parsed address map (manual): $addressMap');
          
          // Build formatted address from parsed data
          List<String> addressParts = [];
          
          // Add parts in logical order
          if (addressMap['streetAddress']?.isNotEmpty == true) {
            addressParts.add(addressMap['streetAddress']!);
          }
          if (addressMap['barangayName']?.isNotEmpty == true) {
            addressParts.add(addressMap['barangayName']!);
          }
          if (addressMap['municipalityName']?.isNotEmpty == true) {
            addressParts.add(addressMap['municipalityName']!);
          }
          if (addressMap['provinceName']?.isNotEmpty == true) {
            addressParts.add(addressMap['provinceName']!);
          }
          if (addressMap['regionName']?.isNotEmpty == true) {
            addressParts.add(addressMap['regionName']!);
          }
          if (addressMap['postalCode']?.isNotEmpty == true) {
            addressParts.add(addressMap['postalCode']!);
          }
          
          String formatted = addressParts.join(', ');
          print('Formatted address (manual): $formatted');
          return formatted;
        }
      }
      
      // If it's already a formatted string, return as-is
      print('Using address as-is (not JSON)');
      return rawAddress;
    } catch (e) {
      // If parsing fails, return the original string
      print('Error parsing address: $e');
      return rawAddress;
    }
  }

  Widget _buildAddressCardContent(String address, bool isDark) {
    return Container(
      decoration: orderSoftSectionDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Shipping address',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            Divider(
              height: 28,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            Text(
              address,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? AppColors.darkForeground : AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0.3),
    );
  }

  Widget _buildPaymentCard(Order order, bool isDark) {
    if (order.paymentMethod == null || order.paymentMethod!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: orderSoftSectionDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            Divider(
              height: 28,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            Row(
              children: [
                Icon(
                  Icons.credit_card_rounded,
                  color: AppColors.delivered,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.paymentMethod!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0.4),
    );
  }

  Widget _buildRiderCard(Order order, bool isDark) {
    final riderDelivery = order.riderDelivery;
    final rider = riderDelivery?.rider;
    final orderStatus = normalizeOrderStatus(order.status);

    final hasProof = riderDelivery?.hasProofPhoto == true ||
        (riderDelivery?.proofPhotoUrl?.trim().isNotEmpty ?? false);
    final riderMarkedDelivered =
        normalizeOrderStatus(riderDelivery?.status ?? '') == 'delivered';
    final showProofSection = hasProof || riderMarkedDelivered;
    final hasProofNote =
        riderDelivery?.proofNote?.trim().isNotEmpty ?? false;

    final showPlaceholder = rider == null &&
        !hasProof &&
        !hasProofNote &&
        (orderStatus == 'shipped' || orderStatus == 'out_for_delivery');

    if (riderDelivery == null && !showPlaceholder) {
      return const SizedBox.shrink();
    }
    if (rider == null && !showProofSection && !hasProofNote && !showPlaceholder) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: orderSoftSectionDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Icon(Icons.delivery_dining_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Rider',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            Divider(
              height: 28,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),

            if (showPlaceholder) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      orderStatus == 'out_for_delivery'
                          ? 'Your package is out for delivery. Rider details will appear here when assigned.'
                          : 'Preparing for delivery. Rider details will appear once assigned.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.45,
                            color: isDark
                                ? AppColors.darkMutedForeground
                                : AppColors.mutedForeground,
                          ),
                    ),
                  ),
                ],
              ),
            ] else if (rider != null) ...[
              // ── Rider identity ──
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name ?? rider.email ?? 'Rider',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        if (rider.email != null) ...[
                          const SizedBox(height: 2),
                          Text(rider.email!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground)),
                        ],
                      ],
                    ),
                  ),
                  orderStatusPill(riderDelivery!.status, isDark),
                ],
              ),

              // ── Rider details ──
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildRiderDetailGrid(riderDelivery, isDark),
            ] else if (showProofSection || hasProofNote) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delivery',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  orderStatusPill(riderDelivery!.status, isDark),
                ],
              ),
            ],

            // ── Proof of delivery ──
            if (!showPlaceholder && (showProofSection || hasProofNote)) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'Proof of Delivery',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (hasProof && riderDelivery!.proofPhotoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: riderDelivery!.proofPhotoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: AppColors.mutedForeground, size: 32),
                            SizedBox(height: 6),
                            Text('Photo unavailable',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              else if (showProofSection)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Rider marked this delivery complete.',
                    style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                  ),
                ),
              if (hasProofNote) ...[
                const SizedBox(height: 8),
                Text(
                  riderDelivery!.proofNote!,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.mutedForeground),
                ),
              ],
            ],

          ],
        ),
      ),
    ).animate(effects: AppAnimations.fadeIn(delay: 0.45));
  }

  Widget _buildRiderDetailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderDetailGrid(RiderDeliveryInfo delivery, bool isDark) {
    final rider = delivery.rider;
    if (rider == null) return const SizedBox.shrink();

    final rows = <Widget>[];

    if (rider.contactNumber != null && rider.contactNumber!.isNotEmpty) {
      rows.add(_buildRiderDetailRow(
          Icons.phone_outlined, 'Contact', rider.contactNumber!));
    }
    if (rider.vehicleType != null && rider.vehicleType!.isNotEmpty) {
      rows.add(_buildRiderDetailRow(
          Icons.two_wheeler_outlined, 'Vehicle', rider.vehicleType!));
    }
    if (rider.licenseNumber != null && rider.licenseNumber!.isNotEmpty) {
      rows.add(_buildRiderDetailRow(
          Icons.badge_outlined, 'License', rider.licenseNumber!));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  String _getRiderStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Pickup';
      case 'pickup':
        return 'Picked Up';
      case 'transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Widget _buildActionButtons(Order order, bool isDark) {
    final rd = order.riderDelivery;
    final status = effectiveOrderStatus(
      order.status,
      riderDeliveryStatus: rd?.status,
      riderProofPhotoUrl: rd?.proofPhotoUrl,
    );
    final chips = <Widget>[];
    final canMessage = status != 'cancelled' &&
        (int.tryParse(order.store?.id ?? '') != null ||
            (order.items.isNotEmpty &&
                int.tryParse(order.items.first.sellerId) != null));

    void add(Widget w) => chips.add(w);

    OutlinedButton pill({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool danger = false,
    }) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(
            color: danger ? AppColors.destructive.withValues(alpha: 0.45) : AppColors.border,
          ),
          foregroundColor:
              danger ? AppColors.destructive : AppColors.primary,
        ),
      );
    }

    if (status != 'cancelled' && status != 'pending') {
      add(pill(
        icon: Icons.near_me_outlined,
        label: 'Track',
        onTap: () => AlertService.showSnackBar(
          context: context,
          message: 'Tracking for order #${order.orderNumber}',
          variant: AlertVariant.info,
        ),
      ));
    }

    if (status == 'completed') {
      add(pill(
        icon: Icons.star_border_rounded,
        label: 'Review',
        onTap: () => context.push(AppRouter.orderReviewPath(order.id)),
      ));
      add(pill(
        icon: Icons.replay_rounded,
        label: 'Reorder',
        onTap: () {
          final slug =
              order.items.isNotEmpty ? order.items.first.productSlug : null;
          if (slug != null && slug.isNotEmpty) {
            context.push('${AppRouter.product}/$slug');
          } else {
            AlertService.showSnackBar(
              context: context,
              message: 'Product link unavailable for reorder.',
              variant: AlertVariant.info,
            );
          }
        },
      ));
    }

    if (status == 'delivered' || status == 'completed') {
      add(pill(
        icon: Icons.undo_rounded,
        label: 'Refund',
        danger: true,
        onTap: () => _requestRefund(order),
      ));
    }

    if (status == 'pending' ||
        status == 'processing' ||
        status == 'confirmed') {
      add(pill(
        icon: Icons.cancel_outlined,
        label: 'Cancel',
        danger: true,
        onTap: () => _cancelOrder(order),
      ));
    }

    if (!canMessage && chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: orderSoftSectionDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canMessage) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OrderChatIconButton(
                  isDark: isDark,
                  tooltip: 'Message seller',
                  onPressed: () => openBuyerOrderChat(context, ref, order: order),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Message the seller about this order',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty) const SizedBox(height: 12),
          ],
          if (chips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: chips,
            ),
        ],
      ),
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0.5),
    );
  }

  Future<void> _confirmReceived(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Confirm Received?'),
          ],
        ),
        content: Text(
          'Are you sure you have received order #${order.orderNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Yes, Received'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      await OrdersApi.confirmReceived(order.id);
      await _loadOrder();
      if (mounted) {
        context.push(
          '${AppRouter.orderReviewPath(order.id)}?fromConfirm=1',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _requestRefund(Order order) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.undo, color: Colors.orange),
            SizedBox(width: 8),
            Text('Request Refund'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: #${order.orderNumber}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why are you requesting a refund?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      await OrdersApi.requestRefund(order.id, reason: reasonController.text);
      await _loadOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund request submitted successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request refund: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Cancel Order'),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel order #${order.orderNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      await OrdersApi.cancelOrder(order.id);
      await ref.read(ordersProvider.notifier).fetchOrders();
      await _loadOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully.'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }
}
