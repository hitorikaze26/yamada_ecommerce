import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/cart_notifier.dart';
import '../../../data/services/auth_api.dart';
import '../../widgets/app_count_badge.dart';
import '../../widgets/chat/chat_header_icon_button.dart';
import '../../widgets/notifications/notification_icon_button.dart';

/// Buyer-style shop chrome for sellers browsing the marketplace.
class SellerBrowseShell extends ConsumerStatefulWidget {
  final Widget child;

  const SellerBrowseShell({super.key, required this.child});

  @override
  ConsumerState<SellerBrowseShell> createState() => _SellerBrowseShellState();
}

class _SellerBrowseShellState extends ConsumerState<SellerBrowseShell> {
  int? _storeId;

  static const _navItems = [
    _BrowseNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      route: AppRouter.sellerBrowse,
    ),
    _BrowseNavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
      label: 'Search',
      route: AppRouter.sellerBrowseSearch,
    ),
    _BrowseNavItem(
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart_rounded,
      label: 'Cart',
      route: AppRouter.sellerBrowseCart,
      showCartBadge: true,
    ),
    _BrowseNavItem(
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
      label: 'My store',
      route: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartProvider.notifier).loadCart();
      _loadStoreId();
    });
  }

  Future<void> _loadStoreId() async {
    try {
      final profile = await AuthApi.getSellerProfile();
      final id = (profile['storeId'] as num?)?.toInt();
      if (mounted) setState(() => _storeId = id);
    } catch (_) {}
  }

  void _openMyStorefront() {
    if (_storeId != null) {
      context.push('${AppRouter.storePath('$_storeId')}?owner=1');
    } else {
      context.go(AppRouter.sellerProfile);
    }
  }

  int _indexForLocation(String location) {
    if (location.contains('/search')) return 1;
    if (location == AppRouter.sellerBrowseCart ||
        location.startsWith('${AppRouter.sellerBrowseCart}/')) {
      return 2;
    }
    return 0;
  }

  void _onNavTap(int index) {
    final item = _navItems[index];
    if (item.route == null) {
      _openMyStorefront();
      return;
    }
    if (item.route == AppRouter.sellerBrowseCart) {
      ref.read(cartProvider.notifier).loadCart();
    }
    context.go(item.route!);
  }

  Widget _cartNavIcon(IconData icon, int count, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isActive ? AppColors.primary : null;

    return SizedBox(
      width: 32,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          if (count > 0)
            Positioned(
              top: -3,
              right: -6,
              child: AppCountBadge(
                count: count,
                size: AppBadgeSize.small,
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final location = GoRouterState.of(context).uri.path;
    final isSearch = location.contains('/search');
    final isCart = location == AppRouter.sellerBrowseCart;
    final cartQty = ref.watch(cartProvider.select((s) => s.totalQuantity));
    final navIndex = _indexForLocation(location);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back to seller dashboard',
          onPressed: () => context.go(AppRouter.sellerDashboard),
        ),
        title: Text(
          isCart ? 'Cart' : (isSearch ? 'Search' : 'Browse shop'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChatHeaderIconButton(isDark: isDark, compact: true),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationIconButton(isDark: isDark, compact: true),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MaterialBanner(
            content: const Text(
              "You're shopping as a customer. Purchases use your buyer cart.",
            ),
            leading: const Icon(Icons.shopping_bag_outlined),
            backgroundColor: AppColors.rosewood.withValues(alpha: 0.08),
            actions: [
              TextButton(
                onPressed: () => context.go(AppRouter.sellerDashboard),
                child: const Text('Back to seller panel'),
              ),
            ],
          ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: BottomNavigationBar(
              currentIndex: navIndex,
              onTap: _onNavTap,
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              iconSize: 24,
              type: BottomNavigationBarType.fixed,
              items: _navItems.map((item) {
                if (!item.showCartBadge) {
                  return BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    activeIcon: Icon(item.activeIcon),
                    label: item.label,
                  );
                }
                return BottomNavigationBarItem(
                  icon: _cartNavIcon(item.icon, cartQty, false),
                  activeIcon: _cartNavIcon(item.activeIcon, cartQty, true),
                  label: item.label,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrowseNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? route;
  final bool showCartBadge;

  const _BrowseNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.route,
    this.showCartBadge = false,
  });
}
