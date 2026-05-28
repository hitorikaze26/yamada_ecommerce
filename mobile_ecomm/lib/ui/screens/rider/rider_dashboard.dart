import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/address_utils.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/rider_delivery_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/chat_notifier.dart';
import '../../../data/providers/rider_notifier.dart';
import '../../widgets/chat/chat_header_icon_button.dart';
import '../../widgets/notifications/notification_icon_button.dart';
import '../../widgets/rider_delivery_widgets.dart';

const Color kPrimaryPink = Color(0xFFE891A0);

class RiderDashboard extends ConsumerStatefulWidget {
  const RiderDashboard({super.key});

  @override
  ConsumerState<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends ConsumerState<RiderDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(riderProvider.notifier).load();
      ref.read(chatProvider.notifier).connectIfAuthenticated();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pickup':
        return 'Ready for Pickup';
      case 'transit':
        return 'In Transit';
      case 'pending':
        return 'Shipped';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber;
      case 'pickup':
        return Colors.blue;
      case 'transit':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _callBuyer(RiderDeliveryModel delivery) async {
    final contact = delivery.buyer?['contact']?.toString();
    if (contact == null || contact.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No buyer contact number available')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: contact.replaceAll(RegExp(r'\s'), ''));
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final riderState = ref.watch(riderProvider);
    final user = authState.user;
    final isVerified = authState.isVerified;
    final recent = ref.read(riderProvider.notifier).recentDeliveries(3);

    return RefreshIndicator(
      onRefresh: () => ref.read(riderProvider.notifier).refresh(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()}, ${user?.givenName ?? 'Rider'}!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ready for today\'s deliveries?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ChatHeaderIconButton(
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    compact: true,
                  ),
                  const SizedBox(width: 4),
                  NotificationIconButton(
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    accentColor: kPrimaryPink,
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
          if (!isVerified)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: RiderVerificationNotice(),
              ),
            ),
          if (riderState.error != null && isVerified)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: MaterialBanner(
                  content: Text(riderState.error!),
                  actions: [
                    TextButton(
                      onPressed: () => ref.read(riderProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildPinkStatCard(
                    icon: Icons.local_shipping_outlined,
                    value: '${riderState.stats.todayDeliveries}',
                    label: 'Today\'s Deliveries',
                  ),
                  _buildPinkStatCard(
                    icon: Icons.check_circle_outline,
                    value: '${riderState.stats.completed}',
                    label: 'Completed',
                  ),
                  _buildPinkStatCard(
                    icon: Icons.pending_actions_outlined,
                    value: '${riderState.stats.pending}',
                    label: 'Pending',
                  ),
                  _buildPinkStatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    value: FormatUtils.peso(riderState.stats.earnings),
                    label: 'Today\'s Earnings',
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Deliveries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: isVerified
                        ? () => context.go(AppRouter.riderDeliveries)
                        : null,
                    style: TextButton.styleFrom(foregroundColor: kPrimaryPink),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (!isVerified)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _emptyCard(
                  'Deliveries will appear here once your rider account is verified.',
                ),
              ),
            )
          else if (riderState.isLoading && recent.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (recent.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _emptyCard('No recent deliveries.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildDeliveryCard(recent[index]),
                  childCount: recent.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
    );
  }

  Widget _buildPinkStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryPink,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryPink.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(RiderDeliveryModel delivery) {
    final statusColor = _getStatusColor(delivery.status);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    delivery.displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(delivery.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                FormatUtils.peso(delivery.fee),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryPink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            delivery.storeName ?? delivery.pickupAddress ?? 'Store location',
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            AddressUtils.formatShippingAddress(
              shippingAddress: delivery.shippingAddress,
              municipalityName: delivery.municipalityName,
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!delivery.isAutoMatched && delivery.status == 'pickup') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callBuyer(delivery),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryPink,
                      side: const BorderSide(color: kPrimaryPink),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                      AppRouter.riderLiveTrackingPath(delivery.id),
                    ),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Track'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryPink,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
