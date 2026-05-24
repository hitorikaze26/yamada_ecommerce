import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/cart_notifier.dart';
import '../../../data/providers/orders_notifier.dart';
import '../../widgets/chat/chat_navigation.dart';
import '../../widgets/notifications/notification_icon_button.dart';
import '../../widgets/report_problem_sheet.dart';
import '../order/buyer_orders_ui.dart' show buyerOrderFilterCounts;

/// Cozy feminine buyer profile — used inside [BuyerShell].
class BuyerProfilePage extends ConsumerStatefulWidget {
  /// When false, only the scrollable body is returned (for nested hosts).
  final bool wrapInScaffold;

  const BuyerProfilePage({super.key, this.wrapInScaffold = true});

  @override
  ConsumerState<BuyerProfilePage> createState() => _BuyerProfilePageState();
}

class _BuyerProfilePageState extends ConsumerState<BuyerProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.isAuthenticated) {
        ref.read(ordersProvider.notifier).fetchOrders();
        ref.read(cartProvider.notifier).loadCart();
      }
    });
  }

  void _goOrders(String status) {
    context.go('${AppRouter.buyerDashboard}?tab=orders&status=$status');
  }

  void _comingSoon(String feature) {
    AlertService.showSnackBar(
      context: context,
      message: '$feature coming soon',
      variant: AlertVariant.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final orders = ref.watch(ordersProvider).orders;

    final content = RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        if (auth.isAuthenticated) {
          await Future.wait([
            ref.read(ordersProvider.notifier).fetchOrders(),
            ref.read(cartProvider.notifier).loadCart(),
          ]);
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                widget.wrapInScaffold ? 12 : 8,
                20,
                0,
              ),
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.wrapInScaffold) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'My Profile',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkForeground
                                          : AppColors.charcoal,
                                    ),
                              ),
                            ),
                            NotificationIconButton(isDark: isDark, compact: true),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      _ProfileHeaderCard(user: user, isDark: isDark)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.06, end: 0),
                      const SizedBox(height: 16),
                      _RewardsStrip(isDark: isDark)
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 400.ms),
                      const SizedBox(height: 24),
                      _sectionTitle(context, 'My Orders'),
                      const SizedBox(height: 12),
                      _OrderStatusGrid(
                        isDark: isDark,
                        counts: buyerOrderFilterCounts(orders),
                        onTap: _goOrders,
                      ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
                      const SizedBox(height: 24),
                      _sectionTitle(context, 'Shopping'),
                      const SizedBox(height: 12),
                      _MenuGrid(
                        isDark: isDark,
                        items: [
                          _MenuItem(
                            icon: Icons.favorite_outline_rounded,
                            label: 'Wishlist',
                            onTap: () => context.push(AppRouter.wishlist),
                          ),
                          _MenuItem(
                            icon: Icons.history_rounded,
                            label: 'Recently Viewed',
                            onTap: () => context.push(AppRouter.recentlyViewed),
                          ),
                          _MenuItem(
                            icon: Icons.storefront_outlined,
                            label: 'Following Stores',
                            onTap: () => context.push(AppRouter.followingStores),
                          ),
                          _MenuItem(
                            icon: Icons.receipt_long_outlined,
                            label: 'Order History',
                            onTap: () => _goOrders('all'),
                          ),
                        ],
                      ).animate().fadeIn(delay: 160.ms, duration: 400.ms),
                      const SizedBox(height: 24),
                      _sectionTitle(context, 'Account'),
                      const SizedBox(height: 12),
                      _MenuListCard(
                        isDark: isDark,
                        items: [
                          _MenuItem(
                            icon: Icons.location_on_outlined,
                            label: 'Saved Addresses',
                            onTap: () => context.push(AppRouter.addresses),
                          ),
                          _MenuItem(
                            icon: Icons.local_offer_outlined,
                            label: 'Vouchers & Coupons',
                            onTap: () => context.push(AppRouter.coupons),
                          ),
                          _MenuItem(
                            icon: Icons.stars_outlined,
                            label: 'Rewards & Points',
                            subtitle: '0 points',
                            onTap: () => _comingSoon('Rewards'),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                      const SizedBox(height: 24),
                      _sectionTitle(context, 'Support'),
                      const SizedBox(height: 12),
                      _MenuListCard(
                        isDark: isDark,
                        items: [
                          _MenuItem(
                            icon: Icons.report_outlined,
                            label: 'My Reports',
                            onTap: () => context.push(AppRouter.myReports),
                          ),
                          _MenuItem(
                            icon: Icons.report_problem_outlined,
                            label: 'Report from order or store',
                            subtitle: 'Use order or store pages for new reports',
                            onTap: () => showReportHelpOrMyReports(context),
                          ),
                          _MenuItem(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Chat Support',
                            onTap: () => openSupportChat(context, ref),
                          ),
                          _MenuItem(
                            icon: Icons.rate_review_outlined,
                            label: 'My Reviews',
                            onTap: () => context.push(AppRouter.myReviews),
                          ),
                        ],
                      ).animate().fadeIn(delay: 240.ms, duration: 400.ms),
                      const SizedBox(height: 28),
                      _sectionTitle(context, 'Account settings'),
                      const SizedBox(height: 12),
                      _MenuListCard(
                        isDark: isDark,
                        items: [
                          _MenuItem(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            onTap: () => context.push(AppRouter.settings),
                          ),
                          _MenuItem(
                            icon: Icons.help_outline_rounded,
                            label: 'Help Center',
                            onTap: () => context.push(AppRouter.help),
                          ),
                        ],
                      ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
                      const SizedBox(height: 20),
                      _LogoutButton(isAuthenticated: auth.isAuthenticated)
                          .animate()
                          .fadeIn(delay: 320.ms, duration: 400.ms),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );

    if (!widget.wrapInScaffold) {
      return ColoredBox(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(child: content),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
    );
  }

}

class _ProfileHeaderCard extends StatelessWidget {
  final User? user;
  final bool isDark;

  const _ProfileHeaderCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final handle = user?.profileHandle;
    final displayName = user?.fullName ?? 'Guest';
    final titleText = (handle != null && handle.isNotEmpty) ? handle : displayName;
    final subtitle = handle != null ? displayName : (user?.email ?? '');

    final avatarUrl = user?.avatarUrl ?? user?.avatar;
    final resolvedAvatar =
        avatarUrl != null ? ApiClient.resolveImageUrl(avatarUrl.toString()) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _glassCard(isDark),
      child: Row(
        children: [
          _AvatarRing(imageUrl: resolvedAvatar, name: displayName, isDark: isDark),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (user?.isVerified == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified member',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final bool isDark;

  const _AvatarRing({
    required this.imageUrl,
    required this.name,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.6),
            AppColors.blush.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 36,
        backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
        backgroundImage:
            imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl!)
                : null,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'Y',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
    );
  }
}

class _RewardsStrip extends StatelessWidget {
  final bool isDark;

  const _RewardsStrip({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _glassCard(isDark),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lilac.withValues(alpha: isDark ? 0.2 : 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.stars_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yamada Rewards',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Earn points on every purchase',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '0 pts',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusGrid extends StatelessWidget {
  final bool isDark;
  final Map<String, int> counts;
  final void Function(String status) onTap;

  const _OrderStatusGrid({
    required this.isDark,
    required this.counts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _OrderShortcut(
        icon: Icons.shopping_bag_outlined,
        label: 'All',
        count: counts['all'] ?? 0,
        status: 'all',
      ),
      _OrderShortcut(
        icon: Icons.wallet_outlined,
        label: 'To Pay',
        count: counts['to_pay'] ?? 0,
        status: 'to_pay',
      ),
      _OrderShortcut(
        icon: Icons.hourglass_top_outlined,
        label: 'Processing',
        count: counts['processing'] ?? 0,
        status: 'processing',
      ),
      _OrderShortcut(
        icon: Icons.local_shipping_outlined,
        label: 'Shipped',
        count: counts['shipped'] ?? 0,
        status: 'shipped',
      ),
      _OrderShortcut(
        icon: Icons.check_circle_outline,
        label: 'Delivered',
        count: counts['delivered'] ?? 0,
        status: 'delivered',
      ),
      _OrderShortcut(
        icon: Icons.cancel_outlined,
        label: 'Cancelled',
        count: counts['cancelled'] ?? 0,
        status: 'cancelled',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCard(isDark),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
        children: items
            .map(
              (item) => _OrderStatusTile(
                item: item,
                isDark: isDark,
                onTap: () => onTap(item.status),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OrderShortcut {
  final IconData icon;
  final String label;
  final int count;
  final String status;

  const _OrderShortcut({
    required this.icon,
    required this.label,
    required this.count,
    required this.status,
  });
}

class _OrderStatusTile extends StatefulWidget {
  final _OrderShortcut item;
  final bool isDark;
  final VoidCallback onTap;

  const _OrderStatusTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_OrderStatusTile> createState() => _OrderStatusTileState();
}

class _OrderStatusTileState extends State<_OrderStatusTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.darkMuted.withValues(alpha: 0.4)
                : AppColors.offWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(widget.item.icon, color: AppColors.primary, size: 24),
                  if (widget.item.count > 0)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          widget.item.count > 9 ? '9+' : '${widget.item.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });
}

class _MenuGrid extends StatelessWidget {
  final bool isDark;
  final List<_MenuItem> items;

  const _MenuGrid({required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _glassCard(isDark),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.4,
        children: items
            .map((item) => _MenuTile(item: item, isDark: isDark))
            .toList(),
      ),
    );
  }
}

class _MenuListCard extends StatelessWidget {
  final bool isDark;
  final List<_MenuItem> items;

  const _MenuListCard({required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _glassCard(isDark),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _MenuRow(item: item, isDark: isDark),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuTile extends StatefulWidget {
  final _MenuItem item;
  final bool isDark;

  const _MenuTile({required this.item, required this.isDark});

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.item.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(widget.item.icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.item.label,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.mutedForeground.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  final _MenuItem item;
  final bool isDark;

  const _MenuRow({required this.item, required this.isDark});

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.item.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: _pressed
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.item.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (widget.item.subtitle != null)
                      Text(
                        widget.item.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  final bool isAuthenticated;

  const _LogoutButton({required this.isAuthenticated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isAuthenticated) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('${AppRouter.login}?role=buyer'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Sign in'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Log out?'),
              content: const Text('You will need to sign in again to shop.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                  ),
                  child: const Text('Log out'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go(AppRouter.login);
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.destructive,
          side: BorderSide(color: AppColors.destructive.withValues(alpha: 0.5)),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _glassCard(bool isDark) {
  return BoxDecoration(
    color: isDark
        ? AppColors.darkCard.withValues(alpha: 0.92)
        : AppColors.card.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark
          ? AppColors.darkBorder.withValues(alpha: 0.8)
          : AppColors.border.withValues(alpha: 0.6),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
