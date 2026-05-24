import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/address_utils.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/providers/seller_orders_notifier.dart';
import '../../widgets/chat/chat_navigation.dart';
import '../../../core/report/report_navigation.dart';
import 'orders/seller_order_status.dart';
import 'orders/widgets/seller_order_widgets.dart';

// ─── Main page ───────────────────────────────────────────────────────────────

class SellerOrdersPage extends ConsumerStatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  ConsumerState<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends ConsumerState<SellerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: sellerOrderTabs.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerOrdersProvider.notifier).fetchOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<SellerOrder> _filterOrders(List<SellerOrder> orders) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders.where((o) {
      if (o.displayId.toLowerCase().contains(q)) return true;
      if ((o.buyer?.name ?? '').toLowerCase().contains(q)) return true;
      if ((o.buyer?.email ?? '').toLowerCase().contains(q)) return true;
      for (final item in o.items) {
        if (item.productName.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerOrdersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show success snackbar
    ref.listen<SellerOrdersState>(sellerOrdersProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        AlertService.showSnackBar(
          context: context,
          message: next.successMessage!,
          variant: AlertVariant.success,
        );
        ref.read(sellerOrdersProvider.notifier).clearSuccess();
      }
      if (next.statusError != null && next.statusError != prev?.statusError) {
        AlertService.showSnackBar(
          context: context,
          message: next.statusError!,
          variant: AlertVariant.error,
        );
        ref.read(sellerOrdersProvider.notifier).clearStatusError();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSearchBar(isDark),
          ),
          const SizedBox(height: 12),
          _buildStatsRow(state, isDark),
          const SizedBox(height: 8),
          _buildTabBar(isDark, state),
          Expanded(
            child: state.isLoading && state.orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.orders.isEmpty
                    ? _buildError(state.error!, isDark)
                    : Stack(
                        children: [
                          TabBarView(
                            controller: _tabController,
                            children: sellerOrderTabs.map((tab) {
                              final base = tab == 'all'
                                  ? state.orders
                                  : state.orders
                                      .where((o) =>
                                          sellerOrderMatchesTab(o.status, tab))
                                      .toList();
                              return _buildOrderList(
                                _filterOrders(base),
                                isDark,
                                tab,
                              );
                            }).toList(),
                          ),
                          if (state.isLoading && state.orders.isNotEmpty)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      textInputAction: TextInputAction.search,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white : AppColors.charcoal,
      ),
      decoration: InputDecoration(
        hintText: 'Search by order ID, customer, or product…',
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[500] : AppColors.mutedForeground,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: isDark ? Colors.grey[400] : AppColors.mutedForeground,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: sellerOrderAccent, width: 1.5),
        ),
      ),
    );
  }

  // ─── Stats row ────────────────────────────────────────────────────────────

  Widget _buildStatsRow(SellerOrdersState state, bool isDark) {
    const statuses = ['pending', 'processing', 'shipped', 'delivered'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: statuses.map((s) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: s != statuses.last ? 8 : 0),
              child: SellerOrderStatChip(
                label: sellerOrderStatShortLabel(s),
                count: state.countByStatus(s),
                icon: sellerOrderStatusIcon(s),
                color: sellerOrderStatusColor(s, isDark),
                isDark: isDark,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBar(bool isDark, SellerOrdersState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(sellerOrderTabs.length, (index) {
          final tab = sellerOrderTabs[index];
          final isActive = _tabController.index == index;
          final count = tab == 'all'
              ? state.orders.length
              : state.countByStatus(tab);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${sellerOrderStatusLabel(tab)} ($count)'),
              selected: isActive,
              onSelected: (_) => _tabController.animateTo(index),
              selectedColor: sellerOrderAccent.withValues(alpha: 0.15),
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? sellerOrderAccent
                    : AppColors.mutedForeground,
              ),
              side: BorderSide(
                color: isActive
                    ? sellerOrderAccent
                    : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Order list ───────────────────────────────────────────────────────────

  Widget _buildOrderList(List<SellerOrder> orders, bool isDark, String tab) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No orders match your search'
                  : 'No ${tab == 'all' ? '' : '${sellerOrderStatusLabel(tab).toLowerCase()} '}orders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different order ID, customer, or product name.'
                  : 'Orders will appear here once customers place them.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(sellerOrdersProvider.notifier).fetchOrders(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: orders.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OrderCard(order: orders[i], isDark: isDark),
        ),
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────

  Widget _buildError(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.cancelled),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(sellerOrdersProvider.notifier).fetchOrders(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order card ──────────────────────────────────────────────────────────────

class _OrderCard extends ConsumerWidget {
  final SellerOrder order;
  final bool isDark;

  const _OrderCard({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final extraCount = order.items.length - 1;
    final itemCount = order.items.fold<int>(0, (s, i) => s + i.quantity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showOrderModal(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.warmBeige,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  order.displayId,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.charcoal,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              SellerOrderStatusBadge(
                                status: order.status,
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SellerOrderProductThumb(
                                imageUrl: firstItem?.productImageUrl,
                                isDark: isDark,
                                size: 56,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      firstItem?.productName ?? 'Order',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        height: 1.25,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.charcoal,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (extraCount > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '+$extraCount more item${extraCount > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 13,
                                          color: isDark
                                              ? Colors.grey[500]
                                              : AppColors.mutedForeground,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatSellerOrderDate(
                                            order.createdAt,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkBackground
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      sellerOrderAccent.withValues(alpha: 0.15),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 16,
                                    color: sellerOrderAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.buyer?.name ?? 'Customer',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.charcoal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.grey[500]
                                              : AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  FormatUtils.peso(order.total),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.charcoal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (sellerOrderNextStatus(order.status) != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SellerOrderSmallButton(
                                    label: 'View details',
                                    onTap: () =>
                                        _showOrderModal(context, ref),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SellerOrderSmallButton(
                                    label: sellerOrderActionLabel(
                                      order.status,
                                    ),
                                    onTap: () => _doStatusUpdate(
                                      context,
                                      ref,
                                      sellerOrderNextStatus(order.status)!,
                                    ),
                                    filled: true,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sellerOrderAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: sellerOrderAccent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ),
      ),
    );
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

  Future<void> _doStatusUpdate(
      BuildContext context, WidgetRef ref, String newStatus) async {
    await ref
        .read(sellerOrdersProvider.notifier)
        .updateStatus(order.backendId, newStatus);
  }

  void _showOrderModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailModal(order: order, isDark: isDark),
    );
  }
}

// ─── Order detail modal ──────────────────────────────────────────────────────

class _OrderDetailModal extends ConsumerWidget {
  final SellerOrder order;
  final bool isDark;

  const _OrderDetailModal({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch live order state so status updates reflect immediately
    final liveOrder = ref.watch(sellerOrdersProvider).orders.firstWhere(
          (o) => o.backendId == order.backendId,
          orElse: () => order,
        );

    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final statusColor = sellerOrderStatusColor(liveOrder.status, isDark);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.14),
                      statusColor.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveOrder.displayId,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatSellerOrderDateTime(liveOrder.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SellerOrderStatusBadge(
                      status: liveOrder.status,
                      isDark: isDark,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Summary hero
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : AppColors.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  FormatUtils.peso(liveOrder.total),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.charcoal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${liveOrder.items.length} line item${liveOrder.items.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : AppColors.mutedForeground,
                                ),
                              ),
                              if (liveOrder.paymentMethod != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sellerOrderAccent
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    liveOrder.paymentMethod!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: sellerOrderAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SellerOrderSectionHeader(
                      title: 'Items',
                      isDark: isDark,
                      icon: Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(height: 10),
                    ...liveOrder.items.map(
                      (item) => _ItemRow(
                        item: item,
                        isDark: isDark,
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                    ),

                    const SizedBox(height: 20),
                    SellerOrderSectionHeader(
                      title: 'Customer',
                      isDark: isDark,
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    SellerOrderInfoCard(
                      isDark: isDark,
                      children: [
                        SellerOrderInfoRow(
                          label: 'Name',
                          value: liveOrder.buyer?.name ?? 'Customer',
                          isDark: isDark,
                        ),
                        if (liveOrder.buyer?.email.isNotEmpty == true)
                          SellerOrderInfoRow(
                            label: 'Email',
                            value: liveOrder.buyer!.email,
                            isDark: isDark,
                          ),
                      ],
                    ),

                    // ── Shipping address ──
                    if (liveOrder.shippingAddress != null &&
                        liveOrder.shippingAddress!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SellerOrderSectionHeader(
                        title: 'Shipping Address',
                        isDark: isDark,
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 10),
                      _AddressCard(
                          raw: liveOrder.shippingAddress!,
                          isDark: isDark),
                    ],

                    // ── Rider info (delivered orders) ──
                    if (liveOrder.riderDelivery?.rider != null) ...[
                      const SizedBox(height: 20),
                      SellerOrderSectionHeader(
                        title: 'Delivery Rider',
                        isDark: isDark,
                        icon: Icons.delivery_dining_rounded,
                      ),
                      const SizedBox(height: 10),
                      _RiderCard(
                          delivery: liveOrder.riderDelivery!,
                          isDark: isDark),
                    ],

                    const SizedBox(height: 20),
                    SellerOrderSectionHeader(
                      title: 'Report issue',
                      isDark: isDark,
                      icon: Icons.report_problem_outlined,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (liveOrder.buyer != null)
                          OutlinedButton.icon(
                            onPressed: () {
                              final buyerId =
                                  int.tryParse(liveOrder.buyer!.id);
                              openReportSubmit(
                                context,
                                targetRole: 'buyer',
                                orderId: liveOrder.backendId,
                                targetUserId: buyerId,
                                label: liveOrder.buyer!.name,
                              );
                            },
                            icon: const Icon(Icons.person_off_outlined, size: 18),
                            label: const Text('Report buyer'),
                          ),
                        if (liveOrder.riderDelivery?.rider != null)
                          OutlinedButton.icon(
                            onPressed: () {
                              final rider = liveOrder.riderDelivery!.rider!;
                              openReportSubmit(
                                context,
                                targetRole: 'rider',
                                orderId: liveOrder.backendId,
                                targetUserId: int.tryParse(rider.id),
                                label: rider.name,
                              );
                            },
                            icon: const Icon(Icons.delivery_dining_outlined, size: 18),
                            label: const Text('Report rider'),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // ── Action buttons ──
              _ModalActions(order: liveOrder, isDark: isDark),
            ],
          ),
        );
      },
    );
  }
}

// ─── Message buyer (order detail) ─────────────────────────────────────────────

class _MessageBuyerButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPressed;

  const _MessageBuyerButton({
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? AppColors.blush : AppColors.rosewood;
    final bg = isDark ? const Color(0xFF252D3A) : AppColors.offWhite;
    final border = isDark ? AppColors.darkBorder : AppColors.warmGray;

    return Tooltip(
      message: 'Message buyer',
      child: Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border.withValues(alpha: isDark ? 0.9 : 0.55)),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    ),
    );
  }
}

// ─── Modal action buttons ────────────────────────────────────────────────────

class _ModalActions extends ConsumerWidget {
  final SellerOrder order;
  final bool isDark;

  const _ModalActions({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final bgColor = isDark ? AppColors.darkCard : Colors.white;

    String? nextStatus;
    String? actionLabel;
    switch (order.status) {
      case 'pending':
        nextStatus = 'processing';
        actionLabel = 'Accept Order';
        break;
      case 'processing':
        nextStatus = 'shipped';
        actionLabel = 'Ready for Pickup';
        break;
    }

    final showCancel = order.status == 'pending' || order.status == 'processing';
    final canMessage = order.buyer != null &&
        order.status != 'cancelled';

    if (nextStatus == null && !showCancel && !canMessage) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (canMessage) ...[
            _MessageBuyerButton(
              isDark: isDark,
              onPressed: () => openSellerOrderChat(context, ref, order: order),
            ),
            const SizedBox(width: 10),
          ],
          if (showCancel)
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref
                      .read(sellerOrdersProvider.notifier)
                      .updateStatus(order.backendId, 'cancelled');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cancelled,
                  side: const BorderSide(color: AppColors.cancelled),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel Order',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          if (showCancel && nextStatus != null) const SizedBox(width: 10),
          if (nextStatus != null)
            Expanded(
              flex: showCancel ? 2 : 1,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref
                      .read(sellerOrdersProvider.notifier)
                      .updateStatus(order.backendId, nextStatus!);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Item row ────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final SellerOrderItem item;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;

  const _ItemRow({
    required this.item,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SellerOrderProductThumb(
            imageUrl: item.productImageUrl,
            isDark: isDark,
            size: 64,
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
                    height: 1.25,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.color != null)
                      _VariantChip(label: item.color!, isDark: isDark),
                    if (item.size != null)
                      _VariantChip(label: 'Size ${item.size}', isDark: isDark),
                    _VariantChip(
                      label: 'Qty ${item.quantity}',
                      isDark: isDark,
                      accent: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${FormatUtils.peso(item.unitPrice)} each',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.grey[400]
                        : AppColors.mutedForeground,
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
                FormatUtils.peso(item.lineTotal),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool accent;

  const _VariantChip({
    required this.label,
    required this.isDark,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? sellerOrderAccent.withValues(alpha: 0.12)
            : (isDark ? AppColors.darkBackground : AppColors.background),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent
              ? sellerOrderAccent.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accent
              ? sellerOrderAccent
              : (isDark ? Colors.grey[300] : AppColors.mutedForeground),
        ),
      ),
    );
  }
}

// ─── Address card ─────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final String raw;
  final bool isDark;

  const _AddressCard({required this.raw, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final parts = AddressUtils.addressLabelRows(raw);
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return SellerOrderInfoCard(
      isDark: isDark,
      children: parts
          .map((p) => SellerOrderInfoRow(
              label: p['label']!, value: p['value']!, isDark: isDark))
          .toList(),
    );
  }
}

// ─── Rider card ───────────────────────────────────────────────────────────────

class _RiderCard extends StatelessWidget {
  final SellerOrderDelivery delivery;
  final bool isDark;

  const _RiderCard({required this.delivery, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rider = delivery.rider!;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Rider identity row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE891A0).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining,
                      size: 24, color: Color(0xFFE891A0)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      if (rider.email.isNotEmpty)
                        Text(rider.email,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedForeground)),
                    ],
                  ),
                ),
                // Delivery status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.deliveredBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _deliveryStatusLabel(delivery.status),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.delivered,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // Details grid
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (rider.contactNumber.isNotEmpty)
                  SellerOrderInfoRow(
                      label: 'Contact',
                      value: rider.contactNumber,
                      isDark: isDark),
                if (rider.vehicleType != null) ...[
                  const SizedBox(height: 8),
                  SellerOrderInfoRow(
                      label: 'Vehicle',
                      value: rider.vehicleType!,
                      isDark: isDark),
                ],
                if (rider.licenseNumber != null) ...[
                  const SizedBox(height: 8),
                  SellerOrderInfoRow(
                      label: 'License',
                      value: rider.licenseNumber!,
                      isDark: isDark),
                ],
                if (delivery.distanceKm != null) ...[
                  const SizedBox(height: 8),
                  SellerOrderInfoRow(
                      label: 'Distance',
                      value: '${delivery.distanceKm!.toStringAsFixed(1)} km',
                      isDark: isDark),
                ],
                const SizedBox(height: 8),
                SellerOrderInfoRow(
                    label: 'Delivery Fee',
                    value: '₱${delivery.fee.toStringAsFixed(2)}',
                    isDark: isDark,
                    bold: true),
              ],
            ),
          ),

          // Proof of delivery
          if (delivery.proofPhotoUrl != null || delivery.proofNote != null) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proof of Delivery',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (delivery.proofPhotoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        delivery.proofPhotoUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.warmBeige,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: AppColors.mutedForeground),
                          ),
                        ),
                      ),
                    ),
                  if (delivery.proofNote != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      delivery.proofNote!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _deliveryStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'Delivered';
      case 'picked_up':
        return 'Picked Up';
      case 'pending':
        return 'Pending';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }
}

