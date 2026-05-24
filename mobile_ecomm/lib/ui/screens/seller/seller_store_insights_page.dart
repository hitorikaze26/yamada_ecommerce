import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/seller_insights_notifier.dart';
import '../../../data/services/seller_insights_api.dart';
import '../../widgets/seller/store_insights_preview_card.dart';

class SellerStoreInsightsPage extends ConsumerStatefulWidget {
  final bool embedded;

  const SellerStoreInsightsPage({super.key, this.embedded = false});

  @override
  ConsumerState<SellerStoreInsightsPage> createState() =>
      _SellerStoreInsightsPageState();
}

class _SellerStoreInsightsPageState extends ConsumerState<SellerStoreInsightsPage> {
  List<StoreFollower> _followers = [];
  bool _loadingFollowers = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    setState(() => _loadingFollowers = true);
    try {
      final list = await SellerInsightsApi.getFollowers();
      if (mounted) setState(() => _followers = list);
    } catch (_) {
      if (mounted) setState(() => _followers = []);
    } finally {
      if (mounted) setState(() => _loadingFollowers = false);
    }
  }

  Future<void> _refresh() async {
    await ref.read(sellerInsightsProvider.notifier).fetch();
    await _loadFollowers();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerInsightsProvider);
    final insights = state.insights;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 24;

    final body = RefreshIndicator(
        onRefresh: _refresh,
        color: StoreInsightsTheme.accent,
        child: state.isLoading && insights == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                children: [
                  _buildHeroSummary(context, null, true, isDark),
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildHeroSummary(context, insights, state.isLoading, isDark),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    context,
                    icon: Icons.star_rounded,
                    title: 'Ratings overview',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _ratingsCard(context, insights, isDark),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    context,
                    icon: Icons.rate_review_outlined,
                    title: 'Customer feedback',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _feedbackCard(context, insights, isDark),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    context,
                    icon: Icons.people_outline_rounded,
                    title: 'Followers',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _followersCard(context, isDark),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    context,
                    icon: Icons.favorite_border_rounded,
                    title: 'Wishlist insights',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _wishlistCard(context, insights, isDark),
                ],
              ),
    );

    if (widget.embedded) {
      return ColoredBox(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Store Insights'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.charcoal,
      ),
      body: body,
    );
  }

  Widget _buildHeroSummary(
    BuildContext context,
    SellerInsights? insights,
    bool isLoading,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: StoreInsightsTheme.cardGradient(isDark),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StoreInsightsTheme.border(isDark)),
        boxShadow: [
          BoxShadow(
            color: StoreInsightsTheme.accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: StoreInsightsTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: StoreInsightsTheme.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your boutique at a glance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StoreInsightsMetricsRow(
            isLoading: isLoading,
            rating: insights?.rating ?? 0,
            wishlistBuyers: insights?.wishlistBuyerCount ?? 0,
            followers: insights?.followersCount ?? 0,
            isDark: isDark,
            height: 56,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: StoreInsightsTheme.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.charcoal,
              ),
        ),
      ],
    );
  }

  Widget _ratingsCard(BuildContext context, SellerInsights? i, bool isDark) {
    final rating = i?.rating ?? 0;
    final count = i?.reviewCount ?? 0;
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: StoreInsightsTheme.pageCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 36),
              const SizedBox(width: 10),
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.charcoal,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$count reviews',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
            ],
          ),
          if (i != null && i.ratingBreakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(5, (idx) {
              final star = 5 - idx;
              final n = i.ratingBreakdown['$star'] ?? 0;
              final pct = count > 0 ? n / count : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$star ★',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct > 0 ? pct : null,
                          backgroundColor:
                              isDark ? AppColors.darkMuted : AppColors.muted,
                          color: StoreInsightsTheme.accent,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$n',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Reviews will appear here once customers rate your products.',
              style: TextStyle(fontSize: 13, color: muted, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedbackCard(BuildContext context, SellerInsights? i, bool isDark) {
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: StoreInsightsTheme.pageCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${i?.reviewCount ?? 0} customer reviews on your products',
            style: TextStyle(fontSize: 14, color: muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => context.push(AppRouter.sellerFeedback),
            icon: const Icon(Icons.rate_review_outlined, size: 20),
            label: const Text('View customer feedback'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosewood,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _followersCard(BuildContext context, bool isDark) {
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: StoreInsightsTheme.pageCardDecoration(isDark),
      child: _loadingFollowers
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _followers.isEmpty
              ? Text(
                  'No followers yet. Share your storefront to grow your audience.',
                  style: TextStyle(fontSize: 13, color: muted, height: 1.35),
                )
              : Column(
                  children: _followers.take(10).map((f) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                StoreInsightsTheme.accent.withValues(alpha: 0.2),
                            foregroundColor: StoreInsightsTheme.accent,
                            child: Text(
                              f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : AppColors.charcoal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  f.email,
                                  style: TextStyle(fontSize: 12, color: muted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _wishlistCard(BuildContext context, SellerInsights? i, bool isDark) {
    final products = i?.wishlistProductBreakdown ?? [];
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: StoreInsightsTheme.pageCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${i?.wishlistBuyerCount ?? 0} buyers wishlisted your products',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Text(
              'No wishlist activity yet.',
              style: TextStyle(fontSize: 13, color: muted),
            )
          else
            ...products.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.productName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : AppColors.charcoal,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: StoreInsightsTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: StoreInsightsTheme.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${p.wishlistCount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: StoreInsightsTheme.accentDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
