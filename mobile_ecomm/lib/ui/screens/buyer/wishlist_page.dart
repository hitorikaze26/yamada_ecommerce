import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/wishlist_notifier.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wishlistProvider.notifier).fetchWishlist();
    });
  }

  Future<void> _refresh() async {
    await ref.read(wishlistProvider.notifier).fetchWishlist();
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear wishlist?'),
        content: const Text('Remove all saved items from your wishlist?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(wishlistProvider.notifier).clearAll();
      if (context.mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Wishlist cleared',
          variant: AlertVariant.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(wishlistProvider);
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

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
        actions: [
          if (state.items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context),
              child: const Text('Clear all'),
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Wishlist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.charcoal,
                  ),
            ),
            if (!state.isLoading)
              Text(
                '${state.items.length} items saved',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                    ),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: _buildBody(context, isDark, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, WishlistState state) {
    if (state.isLoading && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ],
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _ErrorState(
            isDark: isDark,
            message: state.error!,
            onRetry: _refresh,
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_EmptyState(isDark: isDark)],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final product = state.items[index];
        return _WishlistTile(
          product: product,
          isDark: isDark,
          onTap: () => context.push(
            '${AppRouter.product}/${Uri.encodeComponent(product.slug)}',
          ),
          onRemove: () async {
            try {
              await ref.read(wishlistProvider.notifier).remove(product);
              if (context.mounted) {
                AlertService.showSnackBar(
                  context: context,
                  message: 'Removed from wishlist',
                  variant: AlertVariant.success,
                );
              }
            } catch (_) {
              if (context.mounted) {
                AlertService.showSnackBar(
                  context: context,
                  message: 'Could not remove item',
                  variant: AlertVariant.error,
                );
              }
            }
          },
        )
            .animate()
            .fadeIn(duration: 350.ms, delay: (40 * index).ms)
            .slideY(begin: 0.04, end: 0);
      },
    );
  }
}

class _WishlistTile extends StatelessWidget {
  final Product product;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _WishlistTile({
    required this.product,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = product.images.isNotEmpty ? product.images.first : null;
    final imageUrl =
        imagePath != null ? ApiClient.resolveImageUrl(imagePath) : null;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final cardBg = isDark ? AppColors.darkCard : AppColors.card;
    final hasSale =
        product.salePrice != null && product.salePrice! < product.price;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.image_outlined,
                                color: isDark
                                    ? AppColors.darkMutedForeground
                                    : AppColors.mutedForeground,
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: cardBg.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: onRemove,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkForeground
                            : AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FormatUtils.peso(product.currentPrice),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    if (hasSale)
                      Text(
                        FormatUtils.peso(product.price),
                        style: TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            size: 64,
            color: isDark
                ? AppColors.darkMutedForeground
                : AppColors.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            'Your wishlist is empty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkForeground
                      : AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save items you love to buy them later.',
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
            icon: const Icon(Icons.search_rounded),
            label: const Text('Discover Products'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.isDark,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.destructive),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? AppColors.darkMutedForeground
                : AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
