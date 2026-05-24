import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_api.dart';
import '../../../data/providers/wishlist_notifier.dart';
import '../../../data/services/products_api.dart';
import '../../../data/models/product_review_model.dart';
import '../../../data/providers/recently_viewed_notifier.dart';
import '../../widgets/product_variant_modal.dart';
import 'widgets/product_detail_widgets.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final String slug;

  const ProductDetailPage({super.key, required this.slug});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  late PageController _imagePageController;
  int _currentImageIndex = 0;
  ProductVariation? _selectedVariation;
  int _quantity = 1;
  bool _isLiked = false;
  bool _descriptionExpanded = false;

  Product? _product;
  bool _isLoading = true;
  String? _error;
  int? _myStoreId;
  List<ProductReview> _productReviews = [];
  Map<String, int> _ratingBreakdown = {};
  bool _reviewsLoading = false;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _fetchProduct();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _fetchProduct() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final product = await ProductsApi.getProductBySlug(widget.slug);
      final images = product.images
          .map((img) => ApiClient.resolveImageUrl(img))
          .whereType<String>()
          .toList();
      if (mounted) {
        final auth = ref.read(authProvider);
        if (auth.isAuthenticated) {
          ref.read(wishlistProvider.notifier).fetchWishlist();
          ref.read(recentlyViewedProvider.notifier).recordView(product);
        }
      }

      int? myStoreId;
      final auth = ref.read(authProvider);
      if (auth.user?.role == UserRole.seller) {
        try {
          final profile = await AuthApi.getSellerProfile();
          myStoreId = (profile['storeId'] as num?)?.toInt();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _product = product;
        _myStoreId = myStoreId;
        _isLoading = false;
        _isLiked = ref.read(wishlistProvider.notifier).isWishlisted(product.id);
      });
      final pid = int.tryParse(product.id);
      if (pid != null) await _loadReviews(pid);
    } catch (e) {
      setState(() {
        _error = 'Failed to load product: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews(int productId) async {
    setState(() => _reviewsLoading = true);
    try {
      final result = await ProductsApi.getProductReviews(productId);
      if (mounted) {
        setState(() {
          _productReviews = result.reviews;
          _ratingBreakdown = result.ratingBreakdown;
          _reviewsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _toggleWishlist() async {
    final product = _product;
    if (product == null) return;

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      AlertService.showSnackBar(
        context: context,
        message: 'Sign in to save items to your wishlist',
        variant: AlertVariant.info,
      );
      context.push('${AppRouter.login}?role=buyer');
      return;
    }

    final wasLiked = _isLiked;
    setState(() => _isLiked = !wasLiked);
    try {
      if (wasLiked) {
        await ref.read(wishlistProvider.notifier).remove(product);
        if (mounted) {
          AlertService.showSnackBar(
            context: context,
            message: 'Removed from wishlist',
            variant: AlertVariant.info,
          );
        }
      } else {
        await ref.read(wishlistProvider.notifier).add(product);
        if (mounted) {
          AlertService.showSnackBar(
            context: context,
            message: 'Added to wishlist',
            variant: AlertVariant.success,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLiked = wasLiked);
        AlertService.showSnackBar(
          context: context,
          message: 'Could not update wishlist',
          variant: AlertVariant.error,
        );
      }
    }
  }

  List<String> get _resolvedImages {
    if (_product == null) return [];
    return _product!.images
        .map((img) => ApiClient.resolveImageUrl(img))
        .where((url) => url != null)
        .cast<String>()
        .toList();
  }

  String? get _variantLabel {
    if (_selectedVariation == null) return null;
    return '${_selectedVariation!.color} · ${_selectedVariation!.size} · qty $_quantity';
  }

  double get _displayPrice {
    if (_product == null) return 0;
    return _selectedVariation?.price ?? _product!.salePrice ?? _product!.price;
  }

  bool _isOwnProduct(Product product) {
    if (_myStoreId == null) return false;
    return product.sellerId == '$_myStoreId';
  }

  Future<void> _shareProduct() async {
    final product = _product;
    if (product == null) return;

    final shareBase = dotenv.env['APP_SHARE_BASE_URL']?.trim();
    final path = product.slug.isNotEmpty ? product.slug : product.id;
    final link = (shareBase != null && shareBase.isNotEmpty)
        ? '$shareBase/product/$path'
        : 'yamada://product/$path';
    final price = FormatUtils.peso(_displayPrice);

    try {
      await Share.share(
        '${product.name}\n$price\n$link',
        subject: product.name,
      );
    } catch (e) {
      if (!mounted) return;
      AlertService.showSnackBar(
        context: context,
        message: 'Could not open share sheet',
        variant: AlertVariant.error,
      );
    }
  }

  void _openVariantModal({required bool isBuyNow}) {
    if (_product == null) return;
    showProductVariantModal(
      context: context,
      product: _product!,
      initialVariation: _selectedVariation,
      initialQuantity: _quantity,
      isBuyNow: isBuyNow,
      onSelectionChanged: (variation, qty) {
        setState(() {
          _selectedVariation = variation;
          _quantity = qty;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: ProductDetailLoadingSkeleton(isDark: isDark),
      );
    }

    if (_error != null || _product == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: AppColors.primary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Product unavailable',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'This item may have been removed or the link is invalid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _fetchProduct,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(AppRouter.home),
                  child: const Text('Back to shop'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final product = _product!;
    final images = _resolvedImages;

    final hasVariations = product.variations.isNotEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchProduct,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                ProductDetailImageHero(
                  imageUrls: images,
                  discountPercent: product.discountPercent,
                  isLiked: _isLiked,
                  isDark: isDark,
                  pageController: _imagePageController,
                  currentIndex: _currentImageIndex,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  onBack: () => context.pop(),
                  onToggleLike: _toggleWishlist,
                  onShare: _shareProduct,
                  onImageTap: (_, url) => showProductImageZoom(context, url),
                ),
                if (images.length > 1) ...[
                  const SizedBox(height: 10),
                  ProductDetailImageThumbnails(
                    imageUrls: images,
                    currentIndex: _currentImageIndex,
                    isDark: isDark,
                    onThumbnailTap: (index) {
                      _imagePageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                      setState(() => _currentImageIndex = index);
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: Offset(0, images.length > 1 ? -8 : -24),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductHeader(context, product, isDark),
                      const SizedBox(height: 20),
                      if (hasVariations) ...[
                        ProductDetailVariantTrigger(
                          isDark: isDark,
                          selectedLabel: _variantLabel,
                          onTap: () => _openVariantModal(isBuyNow: false),
                        ),
                        const SizedBox(height: 20),
                      ] else if (product.totalStock > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: AppColors.delivered,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${product.totalStock} in stock',
                                style: TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ProductDetailSellerCard(
                        sellerName: product.sellerName,
                        sellerLogo: product.sellerLogo != null
                            ? ApiClient.resolveImageUrl(product.sellerLogo)
                            : null,
                        isDark: isDark,
                        onTap: product.sellerId.isNotEmpty
                            ? () => context.push(AppRouter.storePath(product.sellerId))
                            : null,
                      ),
                      const SizedBox(height: 24),
                      _buildTrustStrip(isDark),
                      const SizedBox(height: 28),
                      _buildDescriptionSection(context, product, isDark),
                      const SizedBox(height: 28),
                      _buildReviewsSection(context, product, isDark),
                      const SizedBox(height: 28),
                      _buildRelatedSection(context, isDark),
                      SizedBox(height: 96 + bottomInset),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: ProductDetailBottomBar(
        onAddToCart: () => _openVariantModal(isBuyNow: false),
        onBuyNow: () => _openVariantModal(isBuyNow: true),
        onEditProduct: _isOwnProduct(product)
            ? () => context.push(AppRouter.sellerEditProduct(product.id))
            : null,
      ),
    );
  }

  Widget _buildProductHeader(BuildContext context, Product product, bool isDark) {
    final plainDescription = product.description.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final shortDescription = plainDescription.length > 120
        ? '${plainDescription.substring(0, 120)}…'
        : plainDescription;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.subcategory != null)
          Text(
            product.subcategory!.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary.withValues(alpha: 0.85),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
          ),
        if (product.subcategory != null) const SizedBox(height: 6),
        Text(
          product.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: isDark ? AppColors.darkForeground : AppColors.charcoal,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    product.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    '  (${product.reviewCount} reviews)',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (product.itemsSold > 0)
              Text(
                FormatUtils.soldCount(product.itemsSold),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              FormatUtils.peso(_displayPrice),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            if (product.salePrice != null) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  FormatUtils.peso(product.price),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.mutedForeground,
                      ),
                ),
              ),
            ],
          ],
        ),
        if (shortDescription.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            shortDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                  height: 1.55,
                ),
          ),
        ],
      ],
    ).animate(effects: AppAnimations.fadeInUp(delay: 0.05));
  }

  Widget _buildTrustStrip(bool isDark) {
    final items = [
      (Icons.local_shipping_outlined, 'Free shipping', 'Orders over ₱2,000'),
      (Icons.replay_outlined, 'Easy returns', '30-day policy'),
      (Icons.lock_outline_rounded, 'Secure pay', 'Protected checkout'),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: item == items.last ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkMuted.withValues(alpha: 0.45)
                  : AppColors.blush.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(item.$1, size: 18, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.$3,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: AppColors.mutedForeground),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, Product product, bool isDark) {
    final plain = product.description.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: productDetailSoftCardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand != null) _detailRow('Brand', product.brand!),
              if (product.material != null) _detailRow('Material', product.material!),
              if (product.productCondition != null)
                _detailRow('Condition', product.productCondition!),
              if (product.weightKg != null)
                _detailRow('Weight', '${product.weightKg} kg'),
              if (plain.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _descriptionExpanded || plain.length <= 160
                      ? plain
                      : '${plain.substring(0, 160)}…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                      ),
                ),
                if (plain.length > 160)
                  TextButton(
                    onPressed: () =>
                        setState(() => _descriptionExpanded = !_descriptionExpanded),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_descriptionExpanded ? 'Show less' : 'Read more'),
                  ),
              ] else
                Text(
                  'No description available.',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context, Product product, bool isDark) {
    final totalReviews = product.reviewCount > 0
        ? product.reviewCount
        : _productReviews.length;
    final breakdownTotal = _ratingBreakdown.values.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: productDetailSoftCardDecoration(isDark),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    product.rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < product.rating.floor()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalReviews reviews',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final stars = 5 - i;
                    final count = _ratingBreakdown[stars.toString()] ?? 0;
                    final pct = breakdownTotal > 0 ? count / breakdownTotal : 0.0;
                    return _ratingBar(stars, pct, isDark);
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_reviewsLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_productReviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No reviews yet. Reviews appear after buyers complete their orders.',
              style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
          )
        else
          ..._productReviews.map((r) => _apiReviewCard(r, isDark)),
      ],
    );
  }

  Widget _apiReviewCard(ProductReview review, bool isDark) {
    final labels = dimensionLabelsForFormat(review.reviewFormat);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: productDetailSoftCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.buyerName ?? 'Yamada Shopper',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 14,
                  color: Colors.amber,
                )),
              ),
            ],
          ),
          if (review.ratings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...review.ratings.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    labels[e.key] ?? e.key,
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                  ),
                  Text('${e.value}/5', style: const TextStyle(fontSize: 11)),
                ],
              ),
            )),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!, style: const TextStyle(fontSize: 13)),
          ],
          if (review.deliverySatisfaction != null) ...[
            const SizedBox(height: 6),
            Text(
              'Delivery: ${review.deliverySatisfaction}/5',
              style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
            ),
          ],
          if (review.deliveryPills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: review.deliveryPills
                  .map((p) => Chip(
                        label: Text(p, style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
          if (review.sellerReply != null && review.sellerReply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMuted : AppColors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Seller: ${review.sellerReply}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ratingBar(int stars, double pct, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$stars', style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: isDark ? AppColors.darkMuted : AppColors.muted,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.primary.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedSection(BuildContext context, bool isDark) {
    return FutureBuilder<List<Product>>(
      future: _getRelatedProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 218,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: 3,
              itemBuilder: (_, __) => Container(
                width: 148,
                height: 218,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        }

        final related = snapshot.data ?? [];
        if (related.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You may also like',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 218,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: related.length,
                itemBuilder: (context, index) {
                  final p = related[index];
                  final imageUrl = p.images.isNotEmpty
                      ? ApiClient.resolveImageUrl(p.images.first)
                      : null;
                  return ProductDetailRelatedCard(
                    name: p.name,
                    price: p.price,
                    salePrice: p.salePrice,
                    imageUrl: imageUrl,
                    isDark: isDark,
                    onTap: () =>
                        context.push('${AppRouter.product}/${Uri.encodeComponent(p.slug)}'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Product>> _getRelatedProducts() async {
    if (_product?.categories.isEmpty ?? true) return [];
    try {
      final products = await ProductsApi.getProducts(
        category: _product!.categories.first,
        limit: 10,
      );
      return products.where((p) => p.id != _product!.id).take(6).toList();
    } catch (e) {
      developer.log('Related products error: $e', name: 'ProductDetail');
      return [];
    }
  }

}
