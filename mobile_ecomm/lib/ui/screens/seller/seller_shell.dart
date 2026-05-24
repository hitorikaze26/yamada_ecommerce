import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_notifier.dart';

class SellerShell extends ConsumerStatefulWidget {
  final Widget child;

  const SellerShell({super.key, required this.child});

  @override
  ConsumerState<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends ConsumerState<SellerShell> {
  int _currentIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: AppRouter.sellerDashboard,
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
      route: AppRouter.sellerOrders,
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Products',
      route: AppRouter.sellerProducts,
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      label: 'Analytics',
      route: AppRouter.sellerAnalytics,
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Account',
      route: AppRouter.sellerAccount,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    _currentIndex = _navItems.indexWhere((item) => location == item.route);
    if (_currentIndex < 0) _currentIndex = 0;
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    final isVerified = ref.read(authProvider).isVerified;
    if (!isVerified && index != 4) {
      AlertService.showInfo(
        context: context,
        title: 'Store pending approval',
        message:
            'Your store is awaiting admin approval. You can only access your account for now.',
      );
      context.go(AppRouter.sellerAccount);
      return;
    }
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final location = GoRouterState.of(context).uri.path;
    final isVerified = authState.isVerified;

    if (!authState.isCheckingAuth) {
      if (!authState.isAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('${AppRouter.login}?role=seller');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (user?.role != UserRole.seller) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(AppRouter.home);
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    return Scaffold(
      appBar: _buildAppBar(context, colorScheme, location),
      body: SafeArea(child: widget.child),
      bottomNavigationBar: _buildBottomNav(colorScheme, isVerified),
    );
  }

  PreferredSizeWidget? _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    String location,
  ) {
    if (location == AppRouter.sellerDashboard) return null;

    String title = 'Seller';
    switch (location) {
      case AppRouter.sellerOrders:
        title = 'Customer Orders';
        break;
      case AppRouter.sellerProducts:
        title = 'My Products';
        break;
      case AppRouter.sellerAnalytics:
        title = 'Analytics';
        break;
      case AppRouter.sellerAccount:
        title = 'Account';
        break;
    }

    return AppBar(
      elevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      ),
    );
  }

  Widget _buildBottomNav(ColorScheme colorScheme, bool isVerified) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isActive = index == _currentIndex;
              final restricted = !isVerified && index != 4;
              return _buildNavItem(item, isActive, index, restricted: restricted);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    _NavItem item,
    bool isActive,
    int index, {
    bool restricted = false,
  }) {
    const activeColor = Color(0xFF10B981);
    final inactiveColor = Colors.grey.shade400;
    final color = restricted
        ? inactiveColor.withValues(alpha: 0.5)
        : (isActive ? activeColor : inactiveColor);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
