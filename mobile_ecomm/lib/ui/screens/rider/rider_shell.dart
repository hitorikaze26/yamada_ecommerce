import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';

class RiderShell extends ConsumerStatefulWidget {
  final Widget child;

  const RiderShell({super.key, required this.child});

  @override
  ConsumerState<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends ConsumerState<RiderShell> {
  int _currentIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: AppRouter.riderDashboard,
    ),
    _NavItem(
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping,
      label: 'Deliveries',
      route: AppRouter.riderDeliveries,
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Earnings',
      route: AppRouter.riderEarnings,
    ),
    _NavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'History',
      route: AppRouter.riderHistory,
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
      route: AppRouter.riderProfile,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    _currentIndex = _navItems.indexWhere((item) => item.route == location);
    if (_currentIndex < 0) _currentIndex = 0;
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: widget.child,
      ),
      bottomNavigationBar: _buildBottomNav(colorScheme),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location != AppRouter.riderProfile) return null;

    return AppBar(
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'My Profile',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push(AppRouter.riderSettings),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Account Settings',
        ),
      ],
    );
  }

  Widget _buildBottomNav(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface, // Use theme surface color
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isActive = index == _currentIndex;
              return _buildNavItem(item, isActive, index);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool isActive, int index) {
    final activeColor = const Color(0xFFE891A0); // Pink color from screenshot
    final inactiveColor = Colors.grey.shade400;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
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
