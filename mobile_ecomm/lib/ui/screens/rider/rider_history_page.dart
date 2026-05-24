import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/address_utils.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/rider_delivery_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/rider_notifier.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/rider_delivery_widgets.dart';
import '../../../core/report/report_navigation.dart';

class RiderHistoryPage extends ConsumerStatefulWidget {
  const RiderHistoryPage({super.key});

  @override
  ConsumerState<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends ConsumerState<RiderHistoryPage> {
  String _statusFilter = 'all';
  String _dateFilter = 'all';

  static const _statusFilters = ['all', 'delivered', 'transit', 'pickup', 'pending'];
  static const _statusLabels = {
    'all': 'All',
    'delivered': 'Completed',
    'transit': 'In Transit',
    'pickup': 'Pickup',
    'pending': 'Pending',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(riderProvider.notifier).load();
    });
  }

  String _formatDate(String? value) {
    if (value == null) return '';
    final d = DateTime.tryParse(value);
    if (d == null) return value;
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusLabel(String status) {
    return _statusLabels[status] ?? status;
  }

  List<RiderDeliveryModel> _filteredDeliveries(List<RiderDeliveryModel> all) {
    var items = all.toList();

    if (_statusFilter != 'all') {
      items = items.where((d) => d.status == _statusFilter).toList();
    }

    if (_dateFilter == 'today') {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);
      items = items.where((d) {
        final created = d.createdAt;
        if (created == null) return false;
        final dt = DateTime.tryParse(created);
        return dt != null && dt.toIso8601String().substring(0, 10) == todayStr;
      }).toList();
    } else if (_dateFilter == 'week') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      items = items.where((d) {
        final created = d.createdAt;
        if (created == null) return false;
        final dt = DateTime.tryParse(created);
        return dt != null && dt.isAfter(weekAgo);
      }).toList();
    } else if (_dateFilter == 'month') {
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      items = items.where((d) {
        final created = d.createdAt;
        if (created == null) return false;
        final dt = DateTime.tryParse(created);
        return dt != null && dt.isAfter(monthAgo);
      }).toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = ref.watch(authProvider).isVerified;
    final riderState = ref.watch(riderProvider);
    final allDeliveries = riderState.deliveries;
    final items = _filteredDeliveries(allDeliveries);

    return RefreshIndicator(
      onRefresh: () => ref.read(riderProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View your delivery history.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isVerified)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: RiderVerificationNotice(),
              ),
            ),
          if (riderState.error != null && isVerified)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: MaterialBanner(
                  content: Text(riderState.error!),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          ref.read(riderProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (isVerified)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusFilters.map((filter) {
                          final isActive = _statusFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_statusLabels[filter]!),
                              selected: isActive,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = filter),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              side: BorderSide(
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _dateChip('all', 'All Time'),
                        const SizedBox(width: 8),
                        _dateChip('today', 'Today'),
                        const SizedBox(width: 8),
                        _dateChip('week', 'This Week'),
                        const SizedBox(width: 8),
                        _dateChip('month', 'This Month'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (riderState.isLoading && allDeliveries.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: RiderHistoryEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildHistoryCard(items[index]),
                  childCount: items.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _dateChip(String value, String label) {
    final selected = _dateFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _dateFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(RiderDeliveryModel item) {
    final theme = Theme.of(context);
    final firstItem =
        item.items != null && item.items!.isNotEmpty ? item.items!.first : null;

    return YamadaCard(
      margin: const EdgeInsets.only(bottom: 12),
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      item.displayLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    RiderDeliveryStatusBadge(
                      status: item.status,
                      label: _getStatusLabel(item.status),
                    ),
                  ],
                ),
              ),
              Text(
                FormatUtils.pesoWhole(item.fee),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Order #${item.orderId ?? 'N/A'} · ${_formatDate(item.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (firstItem != null) ...[
            const SizedBox(height: 6),
            Text(firstItem['name']?.toString() ?? 'Item'),
          ],
          const SizedBox(height: 12),
          RiderDeliveryLocationBlock(
            type: DeliveryLocationType.dropoff,
            subtitle: AddressUtils.formatShippingAddress(
              shippingAddress: item.shippingAddress,
              municipalityName: item.municipalityName,
            ),
            isDeliveryComplete: true,
          ),
          if (item.proofPhotoUrl != null ||
              (item.proofNote != null && item.proofNote!.trim().isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RiderProofOfDeliverySection(
                photoUrl: item.proofPhotoUrl,
                note: item.proofNote,
              ),
            ),
          if (item.orderId != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.storeId != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      openReportSubmit(
                        context,
                        targetRole: 'seller',
                        storeId: item.storeId,
                        orderId: item.orderId,
                        label: item.storeName,
                      );
                    },
                    icon: const Icon(Icons.storefront_outlined, size: 16),
                    label: const Text('Report seller'),
                  ),
                if (item.buyer?['id'] != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      final buyerId = item.buyer!['id'];
                      openReportSubmit(
                        context,
                        targetRole: 'buyer',
                        orderId: item.orderId,
                        targetUserId: buyerId is int
                            ? buyerId
                            : int.tryParse(buyerId.toString()),
                        label: item.buyer!['name']?.toString(),
                      );
                    },
                    icon: const Icon(Icons.person_off_outlined, size: 16),
                    label: const Text('Report buyer'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
