import 'dart:developer' as developer;
import 'package:flutter/material.dart' hide CarouselController;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/alert_service.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/services/products_api.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/cart_notifier.dart';
import '../../../data/providers/chat_notifier.dart';
import '../../widgets/app_count_badge.dart';
import '../../widgets/chat/chat_header_icon_button.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/notifications/notification_icon_button.dart';

class HomePage extends ConsumerStatefulWidget {
  /// When true (seller browse shop), chat/notification live in [SellerBrowseShell] only.
  final bool hideMessagingHeader;

  const HomePage({super.key, this.hideMessagingHeader = false});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentSlideIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  // Carousel slides (static content)
  final List<CarouselSlide> _slides = CarouselSlide.mockSlides;
  
  // Dynamic data
  List<Product> _newArrivals = [];
  List<Product> _bestSellers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        ref.read(chatProvider.notifier).connectIfAuthenticated();
      }
    });
  }

  Future<void> _fetchHomeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch data in parallel
      final results = await Future.wait([
        ProductsApi.getNewArrivals(limit: 8),
        ProductsApi.getBestSellers(limit: 8),
      ]);

      // Debug: Log first product images after parsing
      if (results[0].isNotEmpty) {
        final first = results[0].first;
        developer.log('HomePage: First product images: ${first.images}', name: 'HomePage');
        if (first.images.isNotEmpty) {
          final resolved = ApiClient.resolveImageUrl(first.images.first);
          developer.log('HomePage: First resolved image URL: $resolved', name: 'HomePage');
        }
      }

      setState(() {
        _newArrivals = results[0];
        _bestSellers = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load products. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchHomeData,
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          child: CustomScrollView(
            slivers: [
              // Search Bar (Mobile-optimized, prominent)
              SliverToBoxAdapter(
                child: _buildSearchBar(context, isDark),
              ),

              // App Bar with Logo
              SliverToBoxAdapter(
                child: _buildAppBar(context, isDark),
              ),

              // Hero Carousel (Mobile-optimized height)
              SliverToBoxAdapter(
                child: _buildHeroCarousel(context, isDark),
              ),

              // Category Section (Horizontal scrolling)
              SliverToBoxAdapter(
                child: _buildCategorySection(context, isDark),
              ),

              // Product Sections with skeleton loading
              if (_isLoading) ...[
                // New Arrivals Skeleton
                SliverToBoxAdapter(
                  child: _buildSectionSkeleton(context, 'New Arrivals', 'Fresh styles just for you'),
                ),
                // Best Sellers Skeleton
                SliverToBoxAdapter(
                  child: _buildSectionSkeleton(context, 'Best Sellers', 'Our most loved pieces'),
                ),
              ] else if (_error != null)
                SliverToBoxAdapter(
                  child: _buildErrorState(context, isDark),
                )
              else ...[
                // New Arrivals Section
                SliverToBoxAdapter(
                  child: _buildProductSection(
                    context,
                    isDark,
                    title: 'New Arrivals',
                    subtitle: 'Fresh styles just for you',
                    products: _newArrivals,
                    delay: 0.1,
                  ),
                ),

                // Best Sellers Section
                SliverToBoxAdapter(
                  child: _buildProductSection(
                    context,
                    isDark,
                    title: 'Best Sellers',
                    subtitle: 'Our most loved pieces',
                    products: _bestSellers,
                    delay: 0.2,
                  ),
                ),
              ],

              // Bottom Spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkForeground : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _fetchHomeData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? AppColors.darkBackground : AppColors.background,
      child: GestureDetector(
        onTap: () => context.go(
          widget.hideMessagingHeader
              ? AppRouter.sellerBrowseSearch
              : AppRouter.search,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search products, brands...',
                  style: TextStyle(
                    color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mic_none,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? AppColors.darkBackground : AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset(
            'assets/images/logo/logo.png',
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.rosewood,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'Y',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Yamada',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkForeground
                              : AppColors.charcoal,
                        ),
                  ),
                ],
              );
            },
          ),

          if (!widget.hideMessagingHeader)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ref.watch(authProvider).isAuthenticated)
                  ChatHeaderIconButton(isDark: isDark, compact: true)
                else
                  _HomeHeaderIconButton(
                    icon: Icons.chat_bubble_outline,
                    isDark: isDark,
                    onTap: () => context.push('/login?role=buyer'),
                  ),
                if (ref.watch(authProvider).isAuthenticated) ...[
                  const SizedBox(width: 8),
                  NotificationIconButton(isDark: isDark, compact: true),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionSkeleton(BuildContext context, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Skeleton
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 120,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 14,
                      width: 160,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 14,
                  width: 50,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Product Grid Skeleton
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => ProductCard(
              name: '',
              price: 0,
              isLoading: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCarousel(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.background,
      child: Column(
        children: [
          CarouselSlider(
            carouselController: _carouselController,
            options: CarouselOptions(
              height: 180,
              viewportFraction: 0.92,
              enlargeCenterPage: false,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              onPageChanged: (index, reason) {
                setState(() {
                  _currentSlideIndex = index;
                });
              },
            ),
            items: _slides.map((slide) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image with CachedNetworkImage
                          CachedNetworkImage(
                            imageUrl: slide.image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark ? AppColors.darkMuted : AppColors.muted,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: isDark ? AppColors.darkMuted : AppColors.muted,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isDark
                                      ? AppColors.darkBackground.withOpacity(0.7)
                                      : AppColors.background.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    slide.subtitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  slide.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.darkForeground
                                            : AppColors.charcoal,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  slide.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? AppColors.darkMutedForeground
                                            : AppColors.mutedForeground,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    // Navigate to slide.href
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(slide.cta, style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward, size: 14),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SmoothPageIndicator(
            controller: PageController(initialPage: _currentSlideIndex),
            count: _slides.length,
            effect: ExpandingDotsEffect(
              activeDotColor: AppColors.primary,
              dotColor: isDark 
                  ? AppColors.darkMutedForeground.withOpacity(0.3)
                  : AppColors.mutedForeground.withOpacity(0.3),
              dotHeight: 6,
              dotWidth: 6,
              expansionFactor: 3,
            ),
            onDotClicked: (index) {
              _carouselController.animateToPage(index);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0),
    );
  }

  Widget _buildCategorySection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: isDark ? AppColors.darkBackground : AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkForeground
                                : AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Find what you need',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    // View all categories
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('See All'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Horizontal Category List
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: Category.categories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CategoryCard(
                    name: category.name,
                    icon: category.icon,
                    isHorizontal: true,
                    onTap: () {
                      final searchBase = widget.hideMessagingHeader
                          ? AppRouter.sellerBrowseSearch
                          : AppRouter.search;
                      context.go('$searchBase?category=${category.id}');
                    },
                  ).animate(
                    effects: AppAnimations.staggeredItem(index: index),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate(
      effects: AppAnimations.fadeInUp(delay: 0.1),
    );
  }

  Widget _buildProductSection(
    BuildContext context,
    bool isDark, {
    required String title,
    required String subtitle,
    required List<Product> products,
    required double delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // View all
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Product Grid - Mobile optimized with better aspect ratio
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final rawImage = product.images.isNotEmpty ? product.images.first : null;
              final imageUrl = rawImage != null ? ApiClient.resolveImageUrl(rawImage) : null;
              
              return ProductCard(
                productId: product.id,
                name: product.name,
                price: product.price,
                salePrice: product.salePrice,
                imageUrl: imageUrl,
                rating: product.rating,
                reviewCount: product.reviewCount,
                sellerName: product.sellerName,
                subcategory: product.subcategory,
                itemsSold: product.itemsSold,
                onTap: () => context.push('${AppRouter.product}/${Uri.encodeComponent(product.slug)}'),
                onAddToCart: () {
                  // Quick add to cart - adds without variation
                  ref.read(cartProvider.notifier).addToCartSimple(product, 1);
                  AlertService.showSnackBar(
                    context: context,
                    message: '${product.name} added to cart',
                    variant: AlertVariant.success,
                  );
                },
              ).animate(
                effects: AppAnimations.staggeredItem(index: index),
              );
            },
          ),
        ],
      ),
    ).animate(
      effects: AppAnimations.fadeInUp(delay: delay),
    );
  }

}

class _HomeHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final int badgeCount;

  const _HomeHeaderIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? AppColors.darkForeground : AppColors.charcoal,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
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
