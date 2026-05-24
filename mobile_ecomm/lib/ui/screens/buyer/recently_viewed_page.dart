import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/recently_viewed_notifier.dart';
import '../../../data/services/recently_viewed_api.dart';

class RecentlyViewedPage extends ConsumerStatefulWidget {
  const RecentlyViewedPage({super.key});

  @override
  ConsumerState<RecentlyViewedPage> createState() => _RecentlyViewedPageState();
}

class _RecentlyViewedPageState extends ConsumerState<RecentlyViewedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentlyViewedProvider.notifier).fetch();
    });
  }

  Future<void> _refresh() async {
    await ref.read(recentlyViewedProvider.notifier).fetch();
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('Remove all recently viewed products?'),
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
      await ref.read(recentlyViewedProvider.notifier).clearAll();
      if (context.mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Recently viewed cleared',
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
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final state = ref.watch(recentlyViewedProvider);

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
        title: Text(
          'Recently Viewed',
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

  Widget _buildBody(bool isDark, RecentlyViewedState state) {
    if (state.isLoading && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }

    if (state.error != null && state.items.isEmpty) {
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

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 64,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
                const SizedBox(height: 16),
                Text(
                  'No recently viewed items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkForeground
                            : AppColors.charcoal,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Products you open will appear here for quick access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(AppRouter.home),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Start Shopping'),
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
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _RecentRow(
          item: item,
          isDark: isDark,
          onTap: () => context.push(
            '${AppRouter.product}/${Uri.encodeComponent(item.product.slug)}',
          ),
        )
            .animate()
            .fadeIn(duration: 350.ms, delay: (35 * index).ms)
            .slideX(begin: 0.03, end: 0);
      },
    );
  }
}

class _RecentRow extends StatelessWidget {
  final RecentlyViewedItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _RecentRow({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final imagePath = product.images.isNotEmpty ? product.images.first : null;
    final imageUrl =
        imagePath != null ? ApiClient.resolveImageUrl(imagePath) : null;
    final cardBg = isDark ? AppColors.darkCard : AppColors.card;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final viewedLabel = _relativeTime(item.viewedAt);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: isDark
                              ? AppColors.darkMuted
                              : AppColors.muted,
                          child: Icon(
                            Icons.image_outlined,
                            color: isDark
                                ? AppColors.darkMutedForeground
                                : AppColors.mutedForeground,
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
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkForeground
                            : AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      viewedLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
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

  String _relativeTime(DateTime viewedAt) {
    final diff = DateTime.now().difference(viewedAt);
    if (diff.inMinutes < 1) return 'Viewed just now';
    if (diff.inHours < 1) return 'Viewed ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Viewed ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Viewed ${diff.inDays}d ago';
    return 'Viewed ${DateFormat.MMMd().format(viewedAt)}';
  }
}
