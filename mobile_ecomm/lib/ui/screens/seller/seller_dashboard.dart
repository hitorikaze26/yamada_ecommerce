import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/chat_notifier.dart';
import '../../../data/providers/seller_stats_notifier.dart';
import '../../../data/providers/seller_insights_notifier.dart';
import '../../../data/providers/seller_orders_notifier.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_count_badge.dart';
import '../../widgets/chat/chat_header_icon_button.dart';
import '../../widgets/notifications/notification_icon_button.dart';
import '../../widgets/seller/store_insights_preview_card.dart';

/// Seller Dashboard with real stats fetched from the backend.
class SellerDashboard extends ConsumerStatefulWidget {
  const SellerDashboard({super.key});

  @override
  ConsumerState<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends ConsumerState<SellerDashboard> {
  @override
  void initState() {
    super.initState();
    // Refresh stats every time the dashboard is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerStatsProvider.notifier).refresh();
      ref.read(sellerInsightsProvider.notifier).fetch();
      ref.read(sellerOrdersProvider.notifier).fetchOrders();
      ref.read(authProvider.notifier).refreshSellerProfile();
      ref.read(chatProvider.notifier).connectIfAuthenticated();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final stats = ref.watch(sellerStatsProvider);
    final insightsState = ref.watch(sellerInsightsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(authProvider.notifier).refreshSellerProfile();
            await ref.read(sellerStatsProvider.notifier).fetchStats();
            await ref.read(sellerInsightsProvider.notifier).fetch();
            await ref.read(sellerOrdersProvider.notifier).fetchOrders();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with notification + chat icons
                _buildHeader(context, user?.fullName ?? 'Seller', isDark)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.2, duration: 600.ms),
                const SizedBox(height: 20),

                // Verification banner
                if (!(user?.isVerified ?? false)) ...[
                  _buildVerificationCard(isDark)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 100.ms)
                      .slideY(begin: 0.2, duration: 600.ms, delay: 100.ms),
                  const SizedBox(height: 20),
                ],

                // Stats Grid
                _buildStatsGrid(context, stats, insightsState, isDark)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .slideY(begin: 0.2, duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 20),

                // Quick Actions
                _buildSectionTitle(context, 'Quick Actions', isDark)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 300.ms)
                    .slideX(begin: -0.2, duration: 600.ms, delay: 300.ms),
                const SizedBox(height: 12),
                _buildQuickActions(context, isDark)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 400.ms)
                    .slideY(begin: 0.2, duration: 600.ms, delay: 400.ms),
                const SizedBox(height: 20),

                // Recent Activity
                _buildSectionTitle(context, 'Recent Activity', isDark)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 500.ms)
                    .slideX(begin: -0.2, duration: 600.ms, delay: 500.ms),
                const SizedBox(height: 12),
                _buildRecentActivity(context, isDark)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 600.ms)
                    .slideY(begin: 0.2, duration: 600.ms, delay: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String name, bool isDark) {
    return Row(
      children: [
        // Store avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.store, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),

        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Chat icon
        ChatHeaderIconButton(isDark: isDark, compact: true),
        const SizedBox(width: 4),

        NotificationIconButton(isDark: isDark, compact: true),
      ],
    );
  }

  // ─── Verification banner ───────────────────────────────────────────────────

  Widget _buildVerificationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account awaiting approval',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.amber.shade900,
                  ),
                ),
                Text(
                  'Your seller account is pending verification.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats grid ────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(
    BuildContext context,
    SellerStats stats,
    SellerInsightsState insightsState,
    bool isDark,
  ) {
    final isLoading = stats.isLoading || insightsState.isLoading;
    final insights = insightsState.insights;

    String salesLabel = isLoading
        ? '...'
        : '₱${_formatNumber(stats.totalSales)}';
    String ordersLabel = isLoading ? '...' : '${stats.totalOrders}';
    String productsLabel = isLoading ? '...' : '${stats.totalProducts}';

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.payments_outlined,
                  value: salesLabel,
                  label: 'Total Sales',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.receipt_long_outlined,
                  value: ordersLabel,
                  label: 'Orders',
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.inventory_2_outlined,
                  value: productsLabel,
                  label: 'Products',
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StoreInsightsPreviewCard(
                  isLoading: isLoading,
                  rating: insights?.rating ?? stats.rating,
                  wishlistBuyers: insights?.wishlistBuyerCount ?? 0,
                  followers: insights?.followersCount ?? 0,
                  isDark: isDark,
                  onTap: () => context.push(AppRouter.sellerInsights),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(
      BuildContext context, String title, bool isDark) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.charcoal,
          ),
    );
  }

  // ─── Quick actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        _buildActionButton(
          context,
          'Browse Shop',
          Icons.storefront_outlined,
          () => context.push(AppRouter.sellerBrowse),
          isDark,
          const Color(0xFFE891A0),
        ),
        _buildActionButton(
          context,
          'Store insights',
          Icons.insights_outlined,
          () => context.push(AppRouter.sellerInsightsHub),
          isDark,
          const Color(0xFF8B5CF6),
        ),
        _buildActionButton(
          context,
          'Add Product',
          Icons.add_box_outlined,
          () => context.go(AppRouter.sellerProducts),
          isDark,
          const Color(0xFF10B981),
        ),
        _buildActionButton(
          context,
          'View Orders',
          Icons.receipt_long_outlined,
          () => context.go(AppRouter.sellerOrders),
          isDark,
          const Color(0xFF3B82F6),
        ),
        _buildActionButton(
          context,
          'Analytics',
          Icons.analytics_outlined,
          () => context.go(AppRouter.sellerAnalytics),
          isDark,
          const Color(0xFFF59E0B),
        ),
        _buildActionButton(
          context,
          'Account',
          Icons.settings_outlined,
          () => context.go(AppRouter.sellerSettings),
          isDark,
          Colors.grey,
        ),
        _buildActionButton(
          context,
          'Shop settings',
          Icons.store_outlined,
          () => context.push(AppRouter.sellerShopSettings),
          isDark,
          const Color(0xFF6366F1),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ─── Recent activity ───────────────────────────────────────────────────────

  Widget _buildRecentActivity(BuildContext context, bool isDark) {
    final orders = ref.watch(sellerOrdersProvider).orders;
    final sorted = [...orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: recent.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No orders yet',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'New customer orders will appear here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRouter.sellerOrders),
                  child: const Text('View orders'),
                ),
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _buildActivityItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'Order ${recent[i].displayId}',
                    subtitle: recent[i].status.toUpperCase(),
                    time: _formatOrderTime(recent[i].createdAt),
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go(AppRouter.sellerOrders),
                    child: const Text('See all orders'),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatOrderTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

// ─── Header icon button widget ─────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final int badgeCount;

  const _HeaderIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: AppCountBadge(
                count: badgeCount,
                size: AppBadgeSize.small,
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }
}
