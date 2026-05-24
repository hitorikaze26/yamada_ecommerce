import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/services/shop_settings_api.dart';

/// Account hub: navigation to security, branding, shop ops, wallet, etc.
class SellerAccountPage extends ConsumerStatefulWidget {
  const SellerAccountPage({super.key});

  @override
  ConsumerState<SellerAccountPage> createState() => _SellerAccountPageState();
}

class _SellerAccountPageState extends ConsumerState<SellerAccountPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).refreshSellerProfile();
      final profile = await ShopSettingsApi.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  bool get _hasStore => (_profile['storeId'] as num?) != null;
  bool get _isVerified =>
      _profile['isVerified'] == true ||
      ref.watch(authProvider).isVerified;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final shopName =
        _profile['shopName']?.toString() ?? user?.fullName ?? 'Seller';
    final avatarUrl = _profile['avatarUrl']?.toString();

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (!_isVerified) ...[
              _pendingBanner(isDark),
              const SizedBox(height: 16),
            ],
            _headerCard(
              isDark: isDark,
              shopName: shopName,
              email: user?.email ?? _profile['email']?.toString() ?? '',
              avatarUrl: avatarUrl,
              isVerified: _isVerified,
            ),
            const SizedBox(height: 20),
            _sectionTitle('Account', isDark),
            const SizedBox(height: 8),
            _tile(
              icon: Icons.lock_outline,
              title: 'Account security',
              subtitle: 'Password, email, contact',
              isDark: isDark,
              onTap: () => context.push(AppRouter.sellerSettings),
            ),
            _tile(
              icon: Icons.palette_outlined,
              title: 'Shop branding',
              subtitle: 'Logo, banner, shop description',
              isDark: isDark,
              enabled: _isVerified,
              onTap: () => context.push(AppRouter.sellerEditProfile),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Shop management', isDark),
            const SizedBox(height: 8),
            _tile(
              icon: Icons.store_outlined,
              title: 'Shop settings',
              subtitle: 'Shipping, payments, returns, chat',
              isDark: isDark,
              enabled: _hasStore && _isVerified,
              onTap: () => context.push(AppRouter.sellerShopSettings),
            ),
            _tile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet',
              subtitle: 'Balance and transactions',
              isDark: isDark,
              enabled: _hasStore && _isVerified,
              onTap: () => context.push(AppRouter.sellerWallet),
            ),
            _tile(
              icon: Icons.receipt_long_outlined,
              title: 'Refunds',
              subtitle: 'Buyer refund requests',
              isDark: isDark,
              enabled: _hasStore && _isVerified,
              onTap: () => context.push(AppRouter.sellerRefunds),
            ),
            _tile(
              icon: Icons.local_offer_outlined,
              title: 'Coupons',
              subtitle: 'Store discount codes',
              isDark: isDark,
              enabled: _hasStore && _isVerified,
              onTap: () => context.push(AppRouter.sellerCoupons),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Insights', isDark),
            const SizedBox(height: 8),
            _tile(
              icon: Icons.insights_outlined,
              title: 'Store insights',
              subtitle: 'Followers, wishlist, ratings',
              isDark: isDark,
              enabled: _hasStore && _isVerified,
              onTap: () => context.push(AppRouter.sellerInsightsHub),
            ),
            _tile(
              icon: Icons.rate_review_outlined,
              title: 'Customer reviews',
              subtitle: 'Reply and moderate reviews',
              isDark: isDark,
              enabled: _hasStore && _isVerified,
              onTap: () => context.push(
                '${AppRouter.sellerInsightsHub}?tab=reviews',
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('You will need to log in again.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go(AppRouter.landing);
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign out',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pending.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.pending_outlined, color: AppColors.pending),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your store is awaiting admin approval. Shop management unlocks after approval.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard({
    required bool isDark,
    required String shopName,
    required String email,
    required String? avatarUrl,
    required bool isVerified,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.rosewood.withValues(alpha: 0.15),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.rosewood,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isVerified ? Icons.verified : Icons.pending,
                      size: 14,
                      color: isVerified ? AppColors.delivered : AppColors.pending,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Verified' : 'Pending approval',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isVerified ? AppColors.delivered : AppColors.pending,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : AppColors.charcoal,
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: enabled
                      ? AppColors.rosewood
                      : Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? (isDark ? Colors.white : AppColors.charcoal)
                              : Colors.grey,
                        ),
                      ),
                      Text(
                        enabled
                            ? subtitle
                            : 'Available after store approval',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled ? Colors.grey : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legacy route name — same as [SellerAccountPage].
class SellerProfilePage extends SellerAccountPage {
  const SellerProfilePage({super.key});
}
