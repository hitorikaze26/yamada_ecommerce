import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/store_profile_model.dart';
import '../../../data/providers/following_stores_notifier.dart';

class FollowingStoresPage extends ConsumerStatefulWidget {
  const FollowingStoresPage({super.key});

  @override
  ConsumerState<FollowingStoresPage> createState() =>
      _FollowingStoresPageState();
}

class _FollowingStoresPageState extends ConsumerState<FollowingStoresPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followingStoresProvider.notifier).fetch();
    });
  }

  Future<void> _refresh() async {
    await ref.read(followingStoresProvider.notifier).fetch();
  }

  Future<void> _unfollow(StoreProfile store) async {
    try {
      await ref.read(followingStoresProvider.notifier).unfollow(store.id);
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Unfollowed ${store.storeName}',
          variant: AlertVariant.info,
        );
      }
    } catch (_) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Could not unfollow store',
          variant: AlertVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final state = ref.watch(followingStoresProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.darkForeground : AppColors.charcoal,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Following Stores',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    isDark ? AppColors.darkForeground : AppColors.charcoal,
              ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: _buildBody(isDark, state),
      ),
    );
  }

  Widget _buildBody(bool isDark, FollowingStoresState state) {
    if (state.isLoading && state.stores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }

    if (state.error != null && state.stores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(state.error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
        ],
      );
    }

    if (state.stores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            child: Column(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
                const SizedBox(height: 16),
                Text(
                  'No boutiques followed yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkForeground
                            : AppColors.charcoal,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Follow stores you love from their boutique page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(AppRouter.search),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Browse Boutiques'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: state.stores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final store = state.stores[index];
        return _StoreRow(
          store: store,
          isDark: isDark,
          onTap: () => context.push(AppRouter.storePath(store.id)),
          onUnfollow: () => _unfollow(store),
        )
            .animate()
            .fadeIn(duration: 350.ms, delay: (40 * index).ms)
            .slideX(begin: 0.03, end: 0);
      },
    );
  }
}

class _StoreRow extends StatelessWidget {
  final StoreProfile store;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onUnfollow;

  const _StoreRow({
    required this.store,
    required this.isDark,
    required this.onTap,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = store.logoUrl != null
        ? ApiClient.resolveImageUrl(store.logoUrl)
        : null;
    final cardBg = isDark ? AppColors.darkCard : AppColors.card;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: logoUrl,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: isDark
                              ? AppColors.darkMuted
                              : AppColors.muted,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.storeName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark
                            ? AppColors.darkForeground
                            : AppColors.charcoal,
                      ),
                    ),
                    if (store.tagline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        store.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: onUnfollow,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Unfollow', style: TextStyle(fontSize: 12)),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
