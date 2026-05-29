import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/following_stores_notifier.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/store_profile_model.dart';
import '../../../data/services/store_api.dart';
import '../../../data/services/coupons_api.dart';
import '../../widgets/chat/chat_navigation.dart';
import '../../widgets/report_problem_sheet.dart';
import '../seller/seller_edit_profile_page.dart';

/// Curated boutique storefront — collapsing header, sticky tabs, in-store discovery.
class StoreProfilePage extends ConsumerStatefulWidget {
  final String storeId;
  final bool isOwner;

  const StoreProfilePage({
    super.key,
    required this.storeId,
    this.isOwner = false,
  });

  @override
  ConsumerState<StoreProfilePage> createState() => _StoreProfilePageState();
}

class _StoreProfilePageState extends ConsumerState<StoreProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  StoreProfile? _store;
  List<Product> _products = [];
  List<StoreReview> _reviews = [];
  Map<String, int> _ratingBreakdown = {};
  bool _loading = true;
  bool _loadingProducts = true;
  String? _error;
  bool _following = false;
  String? _subcategoryFilter;
  String _sort = 'relevance';
  String _storeSearch = '';
  List<CouponModel> _storeCoupons = [];

  /// Uniform product tile aspect (width / height) for aligned 2-column grid.
  static const double _productGridAspectRatio = 0.58;

  static const _tabs = [
    'Products',
    'New',
    'Best',
    'Reviews',
    'About',
    'More',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await StoreApi.getStoreProfile(widget.storeId);
      final storeKey = store.id;
      var products = await StoreApi.getStoreProducts(storeKey, limit: 100);
      if (products.isEmpty && store.productCount > 0) {
        products = await StoreApi.getStoreProducts(
          widget.storeId,
          limit: 100,
        );
      }

      var following = false;
      if (!widget.isOwner &&
          ref.read(authProvider).isAuthenticated) {
        following = await ref
            .read(followingStoresProvider.notifier)
            .checkFollowing(storeKey);
      }
      final reviews = await StoreApi.getStoreReviews(storeKey);
      List<CouponModel> coupons = [];
      try {
        final sid = int.tryParse(widget.storeId);
        if (sid != null) {
          coupons = await CouponsApi.getCoupons(storeId: sid);
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _store = store;
        _products = products;
        _reviews = reviews;
        _following = following;
        _storeCoupons = coupons;
        _loading = false;
        _loadingProducts = false;
      });
      _loadReviewBreakdown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'This boutique is unavailable right now.';
          _loading = false;
          _loadingProducts = false;
        });
      }
    }
  }

  Future<void> _loadReviewBreakdown() async {
    final b = await StoreApi.getReviewBreakdown(widget.storeId);
    if (mounted) setState(() => _ratingBreakdown = b);
  }

  Future<void> _toggleFollow(String storeName) async {
    if (!ref.read(authProvider).isAuthenticated) {
      AlertService.showSnackBar(
        context: context,
        message: 'Sign in to follow boutiques',
        variant: AlertVariant.info,
      );
      context.push('${AppRouter.login}?role=buyer');
      return;
    }

    final wasFollowing = _following;
    setState(() => _following = !wasFollowing);
    try {
      final nowFollowing = await ref
          .read(followingStoresProvider.notifier)
          .toggleFollow(widget.storeId);
      if (mounted) {
        setState(() => _following = nowFollowing);
        AlertService.showSnackBar(
          context: context,
          message: nowFollowing
              ? 'Following $storeName'
              : 'Unfollowed $storeName',
          variant: AlertVariant.success,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _following = wasFollowing);
        AlertService.showSnackBar(
          context: context,
          message: 'Could not update follow status',
          variant: AlertVariant.error,
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    var list = List<Product>.from(_products);
    final q = _storeSearch.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                (p.brand?.toLowerCase().contains(q) ?? false) ||
                p.category.toLowerCase().contains(q) ||
                (p.subcategory?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    if (_subcategoryFilter != null && _subcategoryFilter!.isNotEmpty) {
      final sub = _subcategoryFilter!.toLowerCase();
      list = list
          .where((p) => (p.subcategory ?? '').trim().toLowerCase() == sub)
          .toList();
    }
    switch (_tabController.index) {
      case 1:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 2:
        list.sort((a, b) {
          final r = b.rating.compareTo(a.rating);
          if (r != 0) return r;
          return b.itemsSold.compareTo(a.itemsSold);
        });
        break;
      default:
        switch (_sort) {
          case 'price_low':
            list.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
            break;
          case 'price_high':
            list.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
            break;
          case 'newest':
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case 'rating':
            list.sort((a, b) => b.rating.compareTo(a.rating));
            break;
        }
    }
    return list;
  }

  void _openProduct(Product p) {
    final seg = p.slug.isNotEmpty ? p.slug : p.id;
    context.push('${AppRouter.product}/$seg');
  }

  Future<void> _shareStore() async {
    final s = _store;
    if (s == null) return;
    await Share.share(
      'Discover ${s.storeName} on Yamada — curated fashion just for you.',
      subject: s.storeName,
    );
  }

  Future<void> _openSellerEditProfile(StoreProfile store) async {
    final result = await navigateToSellerEditProfile(
      context,
      seed: SellerProfileFormData(
        shopName: store.storeName,
        tagline: store.tagline,
        description: store.description,
        avatarUrl: store.logoUrl,
        bannerUrl: store.bannerUrl,
      ),
    );
    if (result != null && mounted) await _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: _StoreProfileShimmer(isDark: isDark),
      );
    }

    if (_error != null || _store == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(leading: const BackButton()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 56, color: AppColors.primary.withValues(alpha: 0.6)),
                const SizedBox(height: 16),
                Text(_error ?? 'Store not found', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    }

    final store = _store!;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          ..._buildHeaderSlivers(context, isDark, store),
          if (widget.isOwner)
            SliverToBoxAdapter(
              child: _OwnerStoreBanner(
                isDark: isDark,
                onEditProfile: () => _openSellerEditProfile(store),
                onManageProducts: () => context.go(AppRouter.sellerProducts),
              ),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              isDark: isDark,
              tabBar: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.18),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.primary,
                unselectedLabelColor:
                    isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
                onTap: (_) => setState(() {}),
              ),
            ),
          ),
          if (_tabController.index <= 2)
            SliverToBoxAdapter(child: _buildInStoreSearch(context, isDark, store)),
          ..._buildActiveTabSlivers(context, isDark, store),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      floatingActionButton: _buildFloatingCta(context, isDark, store),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Single scroll view — avoids [NestedScrollView] + [TabBarView] zero-height grid bugs.
  List<Widget> _buildActiveTabSlivers(
    BuildContext context,
    bool isDark,
    StoreProfile store,
  ) {
    final tab = _tabController.index;
    if (tab <= 2) {
      return _buildProductGridSlivers(context, isDark);
    }
    if (tab == 3) {
      return [SliverToBoxAdapter(child: _buildReviewsTab(context, isDark, store))];
    }
    if (tab == 4) {
      return [SliverToBoxAdapter(child: _buildAboutTab(context, isDark, store))];
    }
    return [SliverToBoxAdapter(child: _buildMoreTab(context, isDark, store))];
  }

  List<Widget> _buildProductGridSlivers(BuildContext context, bool isDark) {
    if (_loadingProducts) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
        ),
      ];
    }

    final products = _filteredProducts;
    if (products.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              children: [
                Icon(Icons.checkroom_outlined, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  _products.isEmpty
                      ? 'This boutique is adding new pieces soon.'
                      : 'No pieces match — try another filter',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: _productGridAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final p = products[index];
              return _BoutiqueProductCard(
                product: p,
                isDark: isDark,
                onTap: () => _openProduct(p),
              );
            },
            childCount: products.length,
          ),
        ),
      ),
    ];
  }

  /// Store-selected categories (registration) plus categories present on live products.
  List<String> _storeCategoryLabels(StoreProfile store) {
    final labels = <String>{};
    for (final raw in store.categories) {
      final label = _formatCategoryLabel(raw);
      if (label.isNotEmpty) labels.add(label);
    }
    for (final p in _products) {
      for (final c in p.categories) {
        final label = _formatCategoryLabel(c);
        if (label.isNotEmpty) labels.add(label);
      }
      final cat = _formatCategoryLabel(p.category);
      if (cat.isNotEmpty) labels.add(cat);
    }
    final list = labels.toList()..sort();
    return list;
  }

  List<String> get _availableSubcategories {
    final subs = <String>{};
    for (final p in _products) {
      final s = p.subcategory?.trim();
      if (s != null && s.isNotEmpty) subs.add(s);
    }
    final list = subs.toList()..sort();
    return list;
  }

  static String _formatCategoryLabel(String raw) => Category.displayName(raw);

  List<Widget> _buildHeaderSlivers(BuildContext context, bool isDark, StoreProfile store) {
    final banner = store.bannerUrl != null ? ApiClient.resolveImageUrl(store.bannerUrl) : null;
    final logo = store.logoUrl != null ? ApiClient.resolveImageUrl(store.logoUrl) : null;
    final joined = store.joinedAt != null
        ? DateFormat.yMMM().format(DateTime.tryParse(store.joinedAt!) ?? DateTime.now())
        : null;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return [
      SliverAppBar(
        expandedHeight: 152,
        pinned: true,
        stretch: true,
        backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
            onPressed: _shareStore,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (v) {
              if (v == 'report') {
                final sid = int.tryParse(widget.storeId);
                showReportProblemSheet(
                  context,
                  category: ReportCategory.store,
                  storeId: sid,
                  label: store.storeName,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Report store')),
            ],
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: Stack(
            fit: StackFit.expand,
            children: [
              if (banner != null)
                CachedNetworkImage(imageUrl: banner, fit: BoxFit.cover)
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.55),
                        AppColors.blush.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: ColoredBox(
          color: bg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _StoreProfileCard(
              store: store,
              logoUrl: logo,
              isDark: isDark,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: ColoredBox(
          color: bg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _GlassStatsStrip(
              isDark: isDark,
              store: store,
              joinedLabel: joined,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildInStoreSearch(BuildContext context, bool isDark, StoreProfile store) {
    final categoryLabels = _storeCategoryLabels(store);
    final subcategories = _availableSubcategories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoryLabels.isNotEmpty) ...[
            Text(
              'This boutique offers',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            _StoreCategoryChips(labels: categoryLabels, isDark: isDark),
            const SizedBox(height: 14),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _storeSearch = v),
                decoration: InputDecoration(
                  hintText: 'Search this boutique…',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: (isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.92),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SubcategoryDropdown(
                  isDark: isDark,
                  subcategories: subcategories,
                  value: _subcategoryFilter,
                  onChanged: (v) => setState(() => _subcategoryFilter = v),
                ),
              ),
              const SizedBox(width: 8),
              _FilterChipPill(
                label: _sortLabel(_sort),
                selected: true,
                isDark: isDark,
                icon: Icons.sort_rounded,
                onTap: () => _showSortSheet(context, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sortLabel(String key) {
    switch (key) {
      case 'price_low':
        return 'Price ↑';
      case 'price_high':
        return 'Price ↓';
      case 'newest':
        return 'Newest';
      case 'rating':
        return 'Top rated';
      default:
        return 'Sort';
    }
  }

  void _showSortSheet(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.largeRadius)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: (isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.95),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sort pieces', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...['relevance', 'newest', 'rating', 'price_low', 'price_high'].map(
                    (k) => ListTile(
                      title: Text(_sortLabel(k)),
                      trailing: _sort == k ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                      onTap: () {
                        setState(() => _sort = k);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(BuildContext context, bool isDark, StoreProfile store) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrustBadgesRow(badges: store.trustBadges, isDark: isDark),
          const SizedBox(height: 16),
          _RatingBreakdownCard(
            rating: store.rating,
            total: store.reviewCount,
            breakdown: _ratingBreakdown,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          if (_reviews.isEmpty)
            _GlassPanel(
              isDark: isDark,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Be the first to leave love for this boutique ✨'),
              ),
            )
          else
            ..._reviews.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(review: r, isDark: isDark),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context, bool isDark, StoreProfile store) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (store.announcement != null && store.announcement!.isNotEmpty)
            _GlassPanel(
              isDark: isDark,
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(store.announcement!)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _GlassPanel(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Our story', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  store.description.isNotEmpty
                      ? store.description
                      : 'A curated Yamada boutique bringing feminine fashion with heart.',
                  style: TextStyle(
                    height: 1.45,
                    color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _OperationalCard(store: store, isDark: isDark),
          const SizedBox(height: 12),
          if (widget.isOwner)
            _OwnerAboutActions(
              isDark: isDark,
              onEditProfile: () => _openSellerEditProfile(store),
              onShopSettings: () => context.push(AppRouter.sellerShopSettings),
            )
          else
            _ActionPillsRow(
              isDark: isDark,
              following: _following,
              onFollow: () => _toggleFollow(store.storeName),
              onChat: () {
                final sid = int.tryParse(widget.storeId);
                if (sid != null) {
                  openBuyerStoreChat(context, ref, storeId: sid);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMoreTab(BuildContext context, bool isDark, StoreProfile store) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Vouchers', isDark: isDark),
          const SizedBox(height: 8),
          _GlassPanel(
            isDark: isDark,
            child: _storeCoupons.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.local_offer_outlined,
                        color: AppColors.primary),
                    title: Text('No active vouchers'),
                    subtitle: Text(
                        'Follow the boutique to catch the next drop'),
                  )
                : Column(
                    children: _storeCoupons
                        .map(
                          (c) => ListTile(
                            leading: const Icon(Icons.local_offer_outlined,
                                color: AppColors.primary),
                            title: Text(c.title),
                            subtitle: Text(
                                '${c.discountLabel} · Code ${c.code}'),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Live selling', isDark: isDark),
          const SizedBox(height: 8),
          _GlassPanel(
            isDark: isDark,
            child: ListTile(
              leading: Icon(
                store.isLiveSelling ? Icons.videocam_rounded : Icons.videocam_off_outlined,
                color: AppColors.primary,
              ),
              title: Text(store.isLiveSelling ? (store.liveTitle ?? 'Live now') : 'Not live right now'),
              subtitle: const Text('We\'ll notify you when they go live'),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Policies', isDark: isDark),
          const SizedBox(height: 8),
          _PoliciesCard(policies: store.policies, isDark: isDark),
        ],
      ),
    );
  }

  Widget? _buildFloatingCta(BuildContext context, bool isDark, StoreProfile store) {
    if (widget.isOwner) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Material(
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: () => _openSellerEditProfile(store),
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: AppColors.primaryGradient,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Edit storefront',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: [
          Expanded(
            child: Material(
              elevation: 8,
              shadowColor: AppColors.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: () => _toggleFollow(store.storeName),
                borderRadius: BorderRadius.circular(28),
                child: Ink(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: _following
                        ? null
                        : AppColors.primaryGradient,
                    color: _following ? (isDark ? AppColors.darkCard : AppColors.card) : null,
                    border: _following
                        ? Border.all(color: AppColors.primary)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _following ? Icons.check_rounded : Icons.favorite_outline_rounded,
                        color: _following ? AppColors.primary : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _following ? 'Following' : 'Follow boutique',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _following ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: 'chat_${widget.storeId}',
            backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
            foregroundColor: AppColors.primary,
            elevation: 4,
            onPressed: () {
              final sid = int.tryParse(widget.storeId);
              if (sid != null) {
                openBuyerStoreChat(context, ref, storeId: sid);
              }
            },
            child: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, end: 0);
  }
}

// ── Supporting widgets ───────────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  _StickyTabBarDelegate({required this.tabBar, required this.isDark});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: (isDark ? AppColors.darkBackground : AppColors.background).withValues(alpha: 0.96),
      elevation: overlapsContent ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar || oldDelegate.isDark != isDark;
}

class _StoreProfileCard extends StatelessWidget {
  final StoreProfile store;
  final String? logoUrl;
  final bool isDark;

  const _StoreProfileCard({
    required this.store,
    required this.logoUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? AppColors.darkForeground : AppColors.charcoal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreLogo(logoUrl: logoUrl, name: store.storeName, isDark: isDark),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.storeName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.3,
                          color: fg,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (store.isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                    ],
                  ],
                ),
                if (store.tagline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    store.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: AppColors.peach),
                    const SizedBox(width: 4),
                    Text(
                      store.rating > 0 ? store.rating.toStringAsFixed(1) : 'New',
                      style: TextStyle(fontWeight: FontWeight.w600, color: fg, fontSize: 13),
                    ),
                    Text(
                      ' · ${store.reviewCount} reviews',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
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
}

class _StoreLogo extends StatelessWidget {
  final String? logoUrl;
  final String name;
  final bool isDark;

  const _StoreLogo({required this.logoUrl, required this.name, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.7), AppColors.blush],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 34,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        backgroundImage: logoUrl != null ? CachedNetworkImageProvider(logoUrl!) : null,
        child: logoUrl == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'Y',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
              )
            : null,
      ),
    );
  }
}

class _GlassStatsStrip extends StatelessWidget {
  final bool isDark;
  final StoreProfile store;
  final String? joinedLabel;

  const _GlassStatsStrip({
    required this.isDark,
    required this.store,
    this.joinedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _StatusPill(
                    label: store.isOpen ? 'Open' : 'Closed',
                    color: store.isOpen ? AppColors.delivered : AppColors.mutedForeground,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(
                    label: store.isOnline ? 'Online' : store.lastActive,
                    color: store.isOnline ? AppColors.processing : AppColors.mutedForeground,
                    isDark: isDark,
                  ),
                  const Spacer(),
                  if (joinedLabel != null)
                    Text(
                      'Since $joinedLabel',
                      style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCell(label: 'Followers', value: '${store.followersCount}')),
                  Expanded(
                    child: _StatCell(
                      label: 'Response',
                      value: '${store.responseRate.toStringAsFixed(0)}%',
                    ),
                  ),
                  Expanded(child: _StatCell(label: 'Pieces', value: '${store.productCount}')),
                  Expanded(
                    child: _StatCell(
                      label: 'Reply',
                      value: store.responseTime.contains('1 hour') ? '~1 hr' : '~24 hr',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _StatusPill({required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15)
                  : (isDark ? AppColors.darkCard : AppColors.card),
              border: Border.all(
                color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 4)],
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreCategoryChips extends StatelessWidget {
  final List<String> labels;
  final bool isDark;
  final String? emptyHint;

  const _StoreCategoryChips({
    required this.labels,
    required this.isDark,
    this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return Text(
        emptyHint ?? 'No categories listed yet.',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SubcategoryDropdown extends StatelessWidget {
  final bool isDark;
  final List<String> subcategories;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _SubcategoryDropdown({
    required this.isDark,
    required this.subcategories,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final fill = (isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.94);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: const Text('All subcategories', style: TextStyle(fontSize: 13)),
          icon: Icon(Icons.expand_more_rounded, color: AppColors.primary),
          borderRadius: BorderRadius.circular(24),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All subcategories', style: TextStyle(fontSize: 13)),
            ),
            ...subcategories.map(
              (s) => DropdownMenuItem<String?>(
                value: s,
                child: Text(s, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          onChanged: subcategories.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

class _BoutiqueProductCard extends StatefulWidget {
  final Product product;
  final bool isDark;
  final VoidCallback onTap;

  const _BoutiqueProductCard({
    required this.product,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_BoutiqueProductCard> createState() => _BoutiqueProductCardState();
}

class _BoutiqueProductCardState extends State<_BoutiqueProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final img = p.images.isNotEmpty ? ApiClient.resolveImageUrl(p.images.first) : null;
    final disc = p.discountPercent;
    final fg = widget.isDark ? AppColors.darkForeground : AppColors.charcoal;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: widget.isDark ? AppColors.darkCard : AppColors.card,
            border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (img != null)
                        CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                      else
                        ColoredBox(color: widget.isDark ? AppColors.darkMuted : AppColors.muted),
                      if (disc > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.destructive.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-$disc%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.subcategory != null && p.subcategory!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          p.subcategory!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: AppColors.peach),
                        Text(
                          p.rating > 0 ? p.rating.toStringAsFixed(1) : '—',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          FormatUtils.pesoCompact(p.currentPrice),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: widget.isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                        ),
                      ],
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

class _GlassPanel extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _GlassPanel({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: (isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.94),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TrustBadgesRow extends StatelessWidget {
  final List<String> badges;
  final bool isDark;

  const _TrustBadgesRow({required this.badges, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges.map((b) {
        final meta = _badgeMeta(b);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(meta.icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(meta.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  ({String label, IconData icon}) _badgeMeta(String key) {
    switch (key) {
      case 'top_rated':
        return (label: 'Top rated', icon: Icons.star_rounded);
      case 'fast_shipper':
        return (label: 'Fast shipper', icon: Icons.local_shipping_outlined);
      case 'responsive_seller':
        return (label: 'Responsive', icon: Icons.chat_bubble_outline_rounded);
      default:
        return (label: 'Verified', icon: Icons.verified_outlined);
    }
  }
}

class _RatingBreakdownCard extends StatelessWidget {
  final double rating;
  final int total;
  final Map<String, int> breakdown;
  final bool isDark;

  const _RatingBreakdownCard({
    required this.rating,
    required this.total,
    required this.breakdown,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final max = breakdown.values.fold<int>(0, (a, b) => a > b ? a : b);
    return _GlassPanel(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                Text('$total reviews', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: List.generate(5, (i) {
                  final star = 5 - i;
                  final count = breakdown['$star'] ?? 0;
                  final frac = max > 0 ? count / max : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('$star', style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: frac,
                              minHeight: 6,
                              backgroundColor: isDark ? AppColors.darkMuted : AppColors.muted,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final StoreReview review;
  final bool isDark;

  const _ReviewCard({required this.review, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final img = review.productImage != null ? ApiClient.resolveImageUrl(review.productImage) : null;
    return _GlassPanel(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(review.buyerName.isNotEmpty ? review.buyerName[0] : '?'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.buyerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 14,
                              color: AppColors.peach,
                            ),
                          ),
                          if (review.verifiedPurchase) ...[
                            const SizedBox(width: 6),
                            Text('Verified', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(review.comment!, style: const TextStyle(height: 1.4)),
            ],
            if (img != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: img, height: 72, width: 72, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              review.productName,
              style: TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontStyle: FontStyle.italic),
            ),
            if (review.sellerReply != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Seller: ${review.sellerReply}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OperationalCard extends StatelessWidget {
  final StoreProfile store;
  final bool isDark;

  const _OperationalCard({required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _OpRow(icon: Icons.schedule_outlined, label: 'Hours', value: store.businessHours),
            _OpRow(icon: Icons.local_shipping_outlined, label: 'Shipping', value: store.shippingSummary),
            _OpRow(icon: Icons.flash_on_outlined, label: 'Response', value: store.responseTime),
            _OpRow(
              icon: Icons.cancel_outlined,
              label: 'Cancellation rate',
              value: '${store.cancellationRate.toStringAsFixed(1)}%',
            ),
            _OpRow(icon: Icons.shopping_bag_outlined, label: 'Completed orders', value: '${store.completedOrders}'),
          ],
        ),
      ),
    );
  }
}

class _OpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OpRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: AppColors.mutedForeground, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _OwnerStoreBanner extends StatelessWidget {
  final bool isDark;
  final VoidCallback onEditProfile;
  final VoidCallback onManageProducts;

  const _OwnerStoreBanner({
    required this.isDark,
    required this.onEditProfile,
    required this.onManageProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Your storefront',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Buyers see this page. Edit your profile, banner, and products from seller tools.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onEditProfile,
                      child: const Text('Edit profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onManageProducts,
                      child: const Text('Products'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerAboutActions extends StatelessWidget {
  final bool isDark;
  final VoidCallback onEditProfile;
  final VoidCallback onShopSettings;

  const _OwnerAboutActions({
    required this.isDark,
    required this.onEditProfile,
    required this.onShopSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onShopSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Shop settings'),
          ),
        ),
      ],
    );
  }
}

class _ActionPillsRow extends StatelessWidget {
  final bool isDark;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback onChat;

  const _ActionPillsRow({
    required this.isDark,
    required this.following,
    required this.onFollow,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onFollow,
            icon: Icon(following ? Icons.check_rounded : Icons.add_rounded),
            label: Text(following ? 'Following' : 'Follow'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Chat'),
          ),
        ),
      ],
    );
  }
}

class _PoliciesCard extends StatelessWidget {
  final StorePolicies policies;
  final bool isDark;

  const _PoliciesCard({required this.policies, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              policies.allowCancellation
                  ? 'Cancel within ${policies.maxCancellationHours}h of ordering'
                  : 'Cancellations not accepted',
            ),
            const SizedBox(height: 8),
            Text(
              policies.allowReturns
                  ? 'Returns within ${policies.returnPeriodDays} days'
                  : 'All sales final',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _StoreProfileShimmer extends StatelessWidget {
  final bool isDark;

  const _StoreProfileShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? AppColors.darkMuted : Colors.grey.shade300;
    final hi = isDark ? AppColors.darkCard : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        children: [
          Container(height: 220, color: base),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(4, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
                    ),
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
