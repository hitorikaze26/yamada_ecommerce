import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/services/products_api.dart';
import '../../../data/services/search_history_service.dart';
import 'search/search_typo_utils.dart';

/// Pinterest-inspired fashion discovery & SQL-backed search (see `GET /products?search=`).
class SearchScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;

  const SearchScreen({super.key, this.initialCategoryId});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

enum _SearchSort { relevance, newest, popular, priceLow, priceHigh }

class _SearchFilters {
  String? categoryId;
  RangeValues priceRange;
  String? size;
  String? colorHint;
  double minRating;
  _SearchSort sort;

  _SearchFilters({
    this.categoryId,
    required this.priceRange,
    this.size,
    this.colorHint,
    this.minRating = 0,
    this.sort = _SearchSort.relevance,
  });

  _SearchFilters copyWith({
    String? categoryId,
    bool clearCategory = false,
    RangeValues? priceRange,
    String? size,
    bool clearSize = false,
    String? colorHint,
    bool clearColor = false,
    double? minRating,
    _SearchSort? sort,
  }) {
    return _SearchFilters(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      priceRange: priceRange ?? this.priceRange,
      size: clearSize ? null : (size ?? this.size),
      colorHint: clearColor ? null : (colorHint ?? this.colorHint),
      minRating: minRating ?? this.minRating,
      sort: sort ?? this.sort,
    );
  }
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchFocus = FocusNode();
  final _searchController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  Timer? _debounce;
  List<Product> _apiResults = [];
  List<Product> _visibleProducts = [];
  List<Product> _trendingPool = [];
  List<Product> _newArrivalsPool = [];
  List<Map<String, dynamic>> _stores = [];
  List<String> _recent = [];
  bool _loadingDiscovery = true;
  bool _loadingResults = false;
  String? _error;
  String? _didYouMean;
  bool _searchFocused = false;
  bool _speechReady = false;
  bool _speechListening = false;

  _SearchFilters _filters = _SearchFilters(
    priceRange: const RangeValues(0, 100000),
  );

  double _catalogPriceMax = 50000;

  static const _trendingQueries = [
    'Floral midi dress',
    'Satin slip dress',
    'Work blouses',
    'Minimal jewelry',
    'Cozy knit cardigan',
    'Date night heels',
    'Linen summer set',
    'Everyday tote bag',
  ];

  @override
  void initState() {
    super.initState();
    final initialCat = Category.findById(widget.initialCategoryId);
    if (initialCat != null) {
      _filters = _filters.copyWith(categoryId: initialCat.id, clearCategory: false);
      _searchController.text = initialCat.name;
    }
    _searchFocus.addListener(() {
      final v = _searchFocus.hasFocus;
      if (_searchFocused != v) setState(() => _searchFocused = v);
    });
    _searchController.addListener(_onTextChanged);
    _loadDiscovery();
    _initSpeech();
    if (initialCat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submitSearch(initialCat.name));
    }
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (!mounted) return;
        if (s == 'done' || s == 'notListening') {
          setState(() => _speechListening = false);
        }
      },
      onError: (e) {
        if (!mounted) return;
        AlertService.showSnackBar(
          context: context,
          message: e.errorMsg,
          variant: AlertVariant.warning,
        );
      },
    );
    if (mounted) setState(() => _speechReady = ok);
  }

  Future<void> _loadDiscovery() async {
    setState(() {
      _loadingDiscovery = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ProductsApi.getProducts(limit: 36, sort: 'popular'),
        ProductsApi.getNewArrivals(limit: 14),
        ProductsApi.getFeaturedStores(limit: 14),
        SearchHistoryService.load(),
      ]);
      final trending = results[0] as List<Product>;
      final fresh = results[1] as List<Product>;
      final stores = results[2] as List<Map<String, dynamic>>;
      final recent = results[3] as List<String>;
      var maxP = 5000.0;
      for (final p in [...trending, ...fresh]) {
        final c = p.currentPrice;
        if (c > maxP) maxP = c;
      }
      if (mounted) {
        setState(() {
          _trendingPool = trending;
          _newArrivalsPool = fresh;
          _stores = stores;
          _recent = recent;
          _catalogPriceMax = maxP.clamp(5000, 200000);
          _filters = _filters.copyWith(
            priceRange: RangeValues(0, _catalogPriceMax),
          );
          _loadingDiscovery = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'We could not load inspiration picks. Pull to refresh.';
          _loadingDiscovery = false;
        });
      }
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _runSearch);
    setState(() {});
  }

  Future<void> _runSearch() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _apiResults = [];
        _visibleProducts = [];
        _loadingResults = false;
        _didYouMean = null;
      });
      return;
    }

    setState(() {
      _loadingResults = true;
      _error = null;
      _didYouMean = null;
    });

    try {
      final sortParam = switch (_filters.sort) {
        _SearchSort.newest => 'newest',
        _SearchSort.popular => 'popular',
        _ => null,
      };
      var list = await ProductsApi.searchProducts(
        q,
        limit: 60,
        sort: sortParam,
        category: _filters.categoryId,
      );

      if (list.isEmpty) {
        final hint = bestTypoMatch(q, [
          ..._trendingQueries,
          ..._recent,
          ..._trendingPool.map((p) => p.name),
        ]);
        if (mounted) setState(() => _didYouMean = hint);
      }

      if (!mounted) return;
      setState(() {
        _apiResults = list;
        _applyLocalFilters();
        _loadingResults = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingResults = false;
        _error = 'Search is taking a breath—try again in a moment.';
      });
    }
  }

  void _applyLocalFilters() {
    Iterable<Product> it = _apiResults;
    final r = _filters.priceRange;
    it = it.where((p) {
      final price = p.currentPrice;
      if (price < r.start || price > r.end) return false;
      if (p.rating < _filters.minRating) return false;
      if (_filters.size != null && _filters.size!.isNotEmpty) {
        final has = p.variations.any(
          (v) => v.size.toLowerCase() == _filters.size!.toLowerCase(),
        );
        if (!has) return false;
      }
      if (_filters.colorHint != null && _filters.colorHint!.trim().isNotEmpty) {
        final hint = _filters.colorHint!.toLowerCase();
        final has = p.variations.any(
          (v) => v.color.toLowerCase().contains(hint),
        );
        if (!has) return false;
      }
      return true;
    });

    var out = it.toList();
    switch (_filters.sort) {
      case _SearchSort.priceLow:
        out.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
        break;
      case _SearchSort.priceHigh:
        out.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case _SearchSort.popular:
        out.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SearchSort.newest:
        out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SearchSort.relevance:
        break;
    }
    _visibleProducts = out;
  }

  int get _activeFilterCount {
    var n = 0;
    if (_filters.categoryId != null) n++;
    if (_filters.minRating > 0) n++;
    if (_filters.size != null && _filters.size!.isNotEmpty) n++;
    if (_filters.colorHint != null && _filters.colorHint!.trim().isNotEmpty) {
      n++;
    }
    final r = _filters.priceRange;
    if (r.start > 0 || r.end < _catalogPriceMax * 0.995) n++;
    return n;
  }

  Future<void> _submitSearch(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    await SearchHistoryService.add(q);
    _recent = await SearchHistoryService.load();
    _searchFocus.unfocus();
    await _runSearch();
    if (mounted) setState(() {});
  }

  Future<void> _toggleVoice() async {
    if (!_speechReady) {
      AlertService.showSnackBar(
        context: context,
        message: 'Voice search is not available on this device.',
        variant: AlertVariant.info,
      );
      return;
    }
    if (_speechListening) {
      await _speech.stop();
      if (mounted) setState(() => _speechListening = false);
      return;
    }
    setState(() => _speechListening = true);
    await _speech.listen(
      onResult: (res) {
        _searchController.text = res.recognizedWords;
        _searchController.selection = TextSelection.collapsed(
          offset: _searchController.text.length,
        );
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  List<String> _liveSuggestions(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    final pool = <String>{
      ..._trendingQueries,
      ..._recent,
      ..._trendingPool.map((p) => p.name),
      ..._trendingPool.expand((p) => p.categories),
      ..._trendingPool.map((p) => p.brand).whereType<String>(),
    };
    return pool
        .where((s) => s.toLowerCase().contains(lower) && s.toLowerCase() != lower)
        .take(8)
        .toList();
  }

  List<Map<String, dynamic>> _matchedStores(String q) {
    if (q.length < 2) return [];
    final lower = q.toLowerCase();
    return _stores
        .where((m) {
          final name = (m['store_name'] ?? m['name'] ?? '').toString().toLowerCase();
          return name.contains(lower);
        })
        .take(10)
        .toList();
  }

  Set<String> _brandChips() {
    final s = <String>{};
    for (final p in _trendingPool.followedBy(_newArrivalsPool)) {
      final b = p.brand?.trim();
      if (b != null && b.isNotEmpty) s.add(b);
    }
    return s;
  }

  void _openProduct(Product p) {
    final seg = p.slug.isNotEmpty ? p.slug : p.id;
    context.push('${AppRouter.product}/$seg');
  }

  Future<void> _openFilters() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizes = <String>{};
    final colors = <String>{};
    for (final p in _apiResults.isNotEmpty ? _apiResults : _trendingPool) {
      for (final v in p.variations) {
        if (v.size.isNotEmpty) sizes.add(v.size);
        if (v.color.isNotEmpty) colors.add(v.color);
      }
    }
    final sizeList = sizes.toList()..sort();
    final colorList = colors.toList()..sort();

    final next = await showModalBottomSheet<_SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _FiltersSheet(
          isDark: isDark,
          initial: _filters,
          catalogMax: _catalogPriceMax,
          sizeOptions: sizeList,
          colorOptions: colorList.take(24).toList(),
        );
      },
    );
    if (next != null && mounted) {
      setState(() => _filters = next);
      if (_searchController.text.trim().isNotEmpty) {
        _runSearch();
      } else if (_apiResults.isNotEmpty) {
        setState(() => _applyLocalFilters());
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final fullName = auth.user?.fullName;
    final firstName = (fullName != null && fullName.isNotEmpty)
        ? fullName.split(' ').first
        : null;
    final query = _searchController.text.trim();
    final suggestions = _liveSuggestions(query);
    final stores = _matchedStores(query);

    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final fg = isDark ? AppColors.darkForeground : AppColors.charcoal;
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await _loadDiscovery();
          if (query.isNotEmpty) await _runSearch();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, isDark, fg, muted, firstName)),
            SliverToBoxAdapter(child: _buildSearchPill(context, isDark)),
            if (suggestions.isNotEmpty && query.isNotEmpty)
              SliverToBoxAdapter(child: _buildSuggestionStrip(context, isDark, suggestions)),
            if (query.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildResultsToolbar(context, isDark)),
              if (stores.isNotEmpty)
                SliverToBoxAdapter(child: _buildStoreRail(context, isDark, stores)),
            ],
            if (query.isEmpty)
              ..._discoverySlivers(context, isDark, fg, muted)
            else if (_loadingResults)
              SliverToBoxAdapter(child: _buildResultsShimmer(context, isDark))
            else if (_didYouMean != null && _visibleProducts.isEmpty)
              SliverToBoxAdapter(child: _buildDidYouMean(context, isDark))
            else if (_visibleProducts.isEmpty)
              SliverToBoxAdapter(child: _buildNoResults(context, isDark, fg, muted))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: _visibleProducts.length,
                  itemBuilder: (context, index) {
                    final p = _visibleProducts[index];
                    return _PinterestProductCard(
                      product: p,
                      index: index,
                      isDark: isDark,
                      onTap: () => _openProduct(p),
                    )
                        .animate(
                          key: ValueKey('${p.id}-$index'),
                        )
                        .fadeIn(
                          duration: AppAnimations.normal,
                          delay: Duration(milliseconds: (index % 6) * 28),
                        );
                  },
                ),
              ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: muted)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color fg,
    Color muted,
    String? firstName,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: -0.3,
                ),
          ).animate(effects: AppAnimations.fadeInUp(delay: 0, duration: 0.45)),
          const SizedBox(height: 4),
          Text(
            firstName != null
                ? '$firstName, curated picks & live search await you.'
                : 'A boutique moodboard—browse, search, fall in love.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.35),
          ).animate(effects: AppAnimations.fadeInUp(delay: 0.05, duration: 0.45)),
        ],
      ),
    );
  }

  Widget _buildSearchPill(BuildContext context, bool isDark) {
    final focused = _searchFocused;
    final borderColor = focused
        ? AppColors.primary.withValues(alpha: isDark ? 0.85 : 0.65)
        : (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.7);
    final fill = (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.78);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: borderColor, width: focused ? 1.5 : 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: focused ? 0.12 : 0.04),
                  blurRadius: focused ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.search_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(color: isDark ? AppColors.darkForeground : AppColors.charcoal),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: 'Search pieces, boutiques, moods…',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: TextStyle(color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground),
                    ),
                    onSubmitted: _submitSearch,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _apiResults = [];
                        _visibleProducts = [];
                        _didYouMean = null;
                      });
                    },
                    icon: Icon(Icons.close_rounded, color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground),
                  ),
                Material(
                  color: _speechListening
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      try {
                        await _toggleVoice();
                      } catch (_) {
                        if (context.mounted) {
                          AlertService.showSnackBar(
                            context: context,
                            message: 'Could not start voice search.',
                            variant: AlertVariant.warning,
                          );
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _speechListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionStrip(BuildContext context, bool isDark, List<String> suggestions) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = suggestions[i];
          return ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppColors.darkMuted.withValues(alpha: 0.5) : AppColors.muted.withValues(alpha: 0.65),
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
            onPressed: () {
              _searchController.text = s;
              _submitSearch(s);
            },
          );
        },
      ),
    );
  }

  Widget _buildResultsToolbar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SortPill(
                    label: 'Relevance',
                    selected: _filters.sort == _SearchSort.relevance,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(sort: _SearchSort.relevance);
                      if (_apiResults.isNotEmpty) _applyLocalFilters();
                    }),
                  ),
                  _SortPill(
                    label: 'Newest',
                    selected: _filters.sort == _SearchSort.newest,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(sort: _SearchSort.newest);
                      _runSearch();
                    }),
                  ),
                  _SortPill(
                    label: 'Popular',
                    selected: _filters.sort == _SearchSort.popular,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(sort: _SearchSort.popular);
                      _runSearch();
                    }),
                  ),
                  _SortPill(
                    label: 'Price ↑',
                    selected: _filters.sort == _SearchSort.priceLow,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(sort: _SearchSort.priceLow);
                      if (_apiResults.isNotEmpty) _applyLocalFilters();
                    }),
                  ),
                  _SortPill(
                    label: 'Price ↓',
                    selected: _filters.sort == _SearchSort.priceHigh,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(sort: _SearchSort.priceHigh);
                      if (_apiResults.isNotEmpty) _applyLocalFilters();
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              FilledButton.tonalIcon(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Filters'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: -2,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreRail(BuildContext context, bool isDark, List<Map<String, dynamic>> stores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            'Boutiques for you',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: stores.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final m = stores[i];
              final name = (m['store_name'] ?? m['name'] ?? 'Boutique').toString();
              final logo = m['logo_url'] ?? m['image_url'];
              final storeId = (m['id'] ?? m['store_id'] ?? '').toString();
              return _GlassMiniCard(
                isDark: isDark,
                width: 160,
                onTap: storeId.isNotEmpty
                    ? () => context.push(AppRouter.storePath(storeId))
                    : null,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark ? AppColors.darkMuted : AppColors.muted,
                      backgroundImage: () {
                        if (logo == null) return null;
                        final url = ApiClient.resolveImageUrl(logo.toString());
                        return url != null ? CachedNetworkImageProvider(url) : null;
                      }(),
                      child: logo == null ? const Icon(Icons.storefront_outlined, size: 20) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _discoverySlivers(BuildContext context, bool isDark, Color fg, Color muted) {
    if (_loadingDiscovery) {
      return [
        SliverToBoxAdapter(child: _buildDiscoveryShimmer(context, isDark)),
      ];
    }
    return [
      SliverToBoxAdapter(child: _buildTrendingQueries(context, isDark)),
      SliverToBoxAdapter(child: _buildRecentSection(context, isDark)),
      SliverToBoxAdapter(child: _buildBrandStrip(context, isDark)),
      SliverToBoxAdapter(child: _buildCategoryMosaic(context, isDark)),
      SliverToBoxAdapter(child: _buildHorizontalProducts(context, isDark, 'Trending now', _trendingPool)),
      SliverToBoxAdapter(child: _buildHorizontalProducts(context, isDark, 'Fresh arrivals', _newArrivalsPool)),
      SliverToBoxAdapter(child: const SizedBox(height: 96)),
    ];
  }

  Widget _buildTrendingQueries(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trending searches', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingQueries.map((t) {
              return Material(
                color: Colors.transparent,
                child: ActionChip(
                  label: Text(t),
                  onPressed: () {
                    _searchController.text = t;
                    _submitSearch(t);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  backgroundColor: isDark ? AppColors.darkCard.withValues(alpha: 0.9) : AppColors.card.withValues(alpha: 0.95),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeInUp(delay: 0.02, duration: 0.45));
  }

  Widget _buildRecentSection(BuildContext context, bool isDark) {
    if (_recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recent', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: () async {
                await SearchHistoryService.clear();
                _recent = [];
                setState(() {});
              }, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final r = _recent[i];
                return InputChip(
                  label: Text(r, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () async {
                    await SearchHistoryService.remove(r);
                    _recent = await SearchHistoryService.load();
                    setState(() {});
                  },
                  onPressed: () {
                    _searchController.text = r;
                    _submitSearch(r);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeInUp(delay: 0.06, duration: 0.45));
  }

  Widget _buildBrandStrip(BuildContext context, bool isDark) {
    final brands = _brandChips().take(16).toList();
    if (brands.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Brands in bloom', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: brands.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final b = brands[i];
                return ChoiceChip(
                  label: Text(b, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  selected: false,
                  onSelected: (_) {
                    _searchController.text = b;
                    _submitSearch(b);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeInUp(delay: 0.1, duration: 0.45));
  }

  Widget _buildCategoryMosaic(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shop by mood', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Category.categories.map((cat) {
                  return _GlassMiniCard(
                    isDark: isDark,
                    width: w,
                    onTap: () {
                      _filters = _filters.copyWith(categoryId: cat.id, clearCategory: false);
                      _searchController.text = cat.name;
                      _submitSearch(cat.name);
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(cat.icon, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_outward_rounded, size: 16, color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeInUp(delay: 0.12, duration: 0.45));
  }

  Widget _buildHorizontalProducts(
    BuildContext context,
    bool isDark,
    String title,
    List<Product> products,
  ) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 210,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: products.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = products[i];
                return _DiscoveryHeroCard(product: p, isDark: isDark, onTap: () => _openProduct(p));
              },
            ),
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeInUp(delay: 0.14, duration: 0.45));
  }

  Widget _buildDiscoveryShimmer(BuildContext context, bool isDark) {
    final base = isDark ? AppColors.darkMuted : Colors.grey.shade300;
    final hi = isDark ? AppColors.darkCard : Colors.grey.shade100;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: hi,
        child: Column(
          children: List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: i == 0 ? 52 : 88,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsShimmer(BuildContext context, bool isDark) {
    final base = isDark ? AppColors.darkMuted : Colors.grey.shade300;
    final hi = isDark ? AppColors.darkCard : Colors.grey.shade100;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: hi,
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
          children: List.generate(6, (i) => Container(decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(18)))),
        ),
      ),
    );
  }

  Widget _buildDidYouMean(BuildContext context, bool isDark) {
    final d = _didYouMean!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _GlassMiniCard(
        isDark: isDark,
        width: double.infinity,
        child: Column(
          children: [
            Text('Did you mean “$d”?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                _searchController.text = d;
                _submitSearch(d);
              },
              child: const Text('Try this search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(BuildContext context, bool isDark, Color fg, Color muted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_mosaic_outlined, size: 52, color: AppColors.primary.withValues(alpha: 0.65)),
          const SizedBox(height: 12),
          Text(
            'No exact matches—let’s keep exploring',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: fg),
          ),
          const SizedBox(height: 8),
          Text(
            'Soft filters or a gentler phrase usually brings treasures back.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          _buildHorizontalProducts(context, isDark, 'You may adore', _trendingPool.take(8).toList()),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _SortPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _SortPill({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
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
                  ? AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.18)
                  : (isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.9),
              border: Border.all(
                color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : (isDark ? AppColors.darkForeground : AppColors.charcoal),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMiniCard extends StatelessWidget {
  final bool isDark;
  final double width;
  final Widget child;
  final VoidCallback? onTap;

  const _GlassMiniCard({
    required this.isDark,
    required this.width,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: (isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.92),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _DiscoveryHeroCard extends StatelessWidget {
  final Product product;
  final bool isDark;
  final VoidCallback onTap;

  const _DiscoveryHeroCard({
    required this.product,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final img = product.images.isNotEmpty ? ApiClient.resolveImageUrl(product.images.first) : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isDark ? AppColors.darkCard : AppColors.card,
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                  child: img != null
                      ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, width: double.infinity)
                      : Container(color: isDark ? AppColors.darkMuted : AppColors.muted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FormatUtils.pesoCompact(product.currentPrice),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
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

class _PinterestProductCard extends StatefulWidget {
  final Product product;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _PinterestProductCard({
    required this.product,
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PinterestProductCard> createState() => _PinterestProductCardState();
}

class _PinterestProductCardState extends State<_PinterestProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final img = p.images.isNotEmpty ? ApiClient.resolveImageUrl(p.images.first) : null;
    final ratio = 0.68 + (widget.index % 4) * 0.035;
    final hasDisc = p.salePrice != null && p.salePrice! < p.price;
    final disc = hasDisc ? p.discountPercent : 0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.isDark ? AppColors.darkCard : AppColors.card,
            border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.28 : 0.07),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: ratio,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      img != null
                          ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                          : Container(color: widget.isDark ? AppColors.darkMuted : AppColors.muted),
                      if (hasDisc && disc > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.destructive.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('-$disc%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                      p.sellerName.isNotEmpty ? p.sellerName : 'Boutique',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.2,
                        color: widget.isDark ? AppColors.darkForeground : AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: AppColors.peach.withValues(alpha: 0.95)),
                        const SizedBox(width: 2),
                        Text(
                          p.rating > 0 ? p.rating.toStringAsFixed(1) : '—',
                          style: TextStyle(fontSize: 11, color: widget.isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground),
                        ),
                        const SizedBox(width: 6),
                        Text('(${p.reviewCount})', style: TextStyle(fontSize: 10, color: widget.isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground)),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              FormatUtils.pesoCompact(p.currentPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: widget.isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                            ),
                            if (hasDisc)
                              Text(
                                FormatUtils.pesoCompact(p.price),
                                style: TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  color: widget.isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                                ),
                              ),
                          ],
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

class _FiltersSheet extends StatefulWidget {
  final bool isDark;
  final _SearchFilters initial;
  final double catalogMax;
  final List<String> sizeOptions;
  final List<String> colorOptions;

  const _FiltersSheet({
    required this.isDark,
    required this.initial,
    required this.catalogMax,
    required this.sizeOptions,
    required this.colorOptions,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late _SearchFilters _f;
  late RangeValues _price;
  String? _size;
  String? _color;
  late double _rating;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    _price = _f.priceRange;
    _size = _f.size;
    _color = _f.colorHint;
    _rating = _f.minRating;
    _categoryId = _f.categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.largeRadius)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: (widget.isDark ? AppColors.darkCard : AppColors.card).withValues(alpha: 0.94),
                  border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: widget.isDark ? AppColors.darkMuted : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Refine your edit', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Soft filters, boutique pacing.', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 20),
                    Text('Category', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _categoryId == null,
                          onSelected: (_) => setState(() => _categoryId = null),
                        ),
                        ...Category.categories.map((c) {
                          return ChoiceChip(
                            label: Text(c.name),
                            selected: _categoryId == c.id,
                            onSelected: (_) => setState(() => _categoryId = c.id),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Price', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    RangeSlider(
                      values: _price,
                      min: 0,
                      max: widget.catalogMax,
                      divisions: 24,
                      labels: RangeLabels(
                        FormatUtils.pesoCompact(_price.start),
                        FormatUtils.pesoCompact(_price.end),
                      ),
                      onChanged: (v) => setState(() => _price = v),
                    ),
                    const SizedBox(height: 8),
                    Text('Min. rating', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _rating,
                      max: 5,
                      divisions: 10,
                      label: _rating <= 0 ? 'Any' : _rating.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _rating = v),
                    ),
                    if (widget.sizeOptions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Size', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any'),
                            selected: _size == null,
                            onSelected: (_) => setState(() => _size = null),
                          ),
                          ...widget.sizeOptions.take(20).map((s) {
                            return ChoiceChip(
                              label: Text(s),
                              selected: _size == s,
                              onSelected: (_) => setState(() => _size = s),
                            );
                          }),
                        ],
                      ),
                    ],
                    if (widget.colorOptions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Color', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any'),
                            selected: _color == null,
                            onSelected: (_) => setState(() => _color = null),
                          ),
                          ...widget.colorOptions.map((c) {
                            return ChoiceChip(
                              label: Text(c),
                              selected: _color == c,
                              onSelected: (_) => setState(() => _color = c),
                            );
                          }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                _SearchFilters(
                                  priceRange: RangeValues(0, widget.catalogMax),
                                  sort: _f.sort,
                                ),
                              );
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                _SearchFilters(
                                  categoryId: _categoryId,
                                  priceRange: _price,
                                  size: _size,
                                  colorHint: _color,
                                  minRating: _rating,
                                  sort: _f.sort,
                                ),
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
