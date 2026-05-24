import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/cart_notifier.dart';
import '../../widgets/app_count_badge.dart';

/// Buyer shop shell — keeps bottom navigation visible across home, search, cart, profile.
class BuyerShell extends ConsumerStatefulWidget {
  final Widget child;

  const BuyerShell({super.key, required this.child});

  @override
  ConsumerState<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends ConsumerState<BuyerShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCartBadge());
  }

  void _syncCartBadge() {
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      ref.read(cartProvider.notifier).loadCart();
    }
  }
  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      route: AppRouter.home,
    ),
    _NavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
      label: 'Search',
      route: AppRouter.search,
    ),
    _NavItem(
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart_rounded,
      label: 'Cart',
      route: AppRouter.cart,
      showCartBadge: true,
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      route: AppRouter.buyerDashboard,
    ),
  ];

  int _indexForLocation(String location) {
    for (var i = 0; i < _navItems.length; i++) {
      final route = _navItems[i].route;
      if (location == route || location.startsWith('$route/')) {
        return i;
      }
    }
    return 0;
  }

  void _onItemTapped(int index) {
    final target = _navItems[index].route;
    final current = GoRouterState.of(context).uri.path;
    if (current == target) return;
    if (target == AppRouter.cart) {
      ref.read(cartProvider.notifier).loadCart();
    }
    context.go(target);
  }

  /// "My Orders" lives at `/buyer?tab=orders` with `go()`, so the shell stack
  /// has nothing to pop — system back would leave the shop. Send user to profile.
  void _leaveBuyerOrdersTab(BuildContext context) {
    context.go(AppRouter.buyerDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uri = GoRouterState.of(context).uri;
    final location = uri.path;
    final isBuyerOrdersTab =
        location == AppRouter.buyerDashboard &&
        uri.queryParameters['tab'] == 'orders';
    final currentIndex = _indexForLocation(location);
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        ref.read(cartProvider.notifier).loadCart();
      }
    });

    final cartQuantity = ref.watch(
      cartProvider.select((s) => s.totalQuantity),
    );

    final body = isBuyerOrdersTab
        ? PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _leaveBuyerOrdersTab(context);
            },
            child: widget.child,
          )
        : widget.child;

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: _onItemTapped,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: isDark
                ? AppColors.darkMutedForeground
                : AppColors.mutedForeground,
            selectedFontSize: 12,
            unselectedFontSize: 12,
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
                icon: _CartNavIcon(
                  icon: item.icon,
                  badgeCount: cartQuantity,
                  isActive: false,
                ),
                activeIcon: _CartNavIcon(
                  icon: item.activeIcon,
                  badgeCount: cartQuantity,
                  isActive: true,
                ),
                label: item.label,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool isActive;

  const _CartNavIcon({
    required this.icon,
    required this.badgeCount,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
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
          if (badgeCount > 0)
            Positioned(
              top: -3,
              right: -6,
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final bool showCartBadge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.showCartBadge = false,
  });
}
