import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/services/api_client.dart';
import '../../core/services/alert_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_router.dart';
import '../../data/models/order_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/products_api.dart';
import '../../data/providers/cart_notifier.dart';

class CartItemModal extends ConsumerStatefulWidget {
  final CartItem cartItem;

  const CartItemModal({
    super.key,
    required this.cartItem,
  });

  @override
  ConsumerState<CartItemModal> createState() => _CartItemModalState();
}

class _CartItemModalState extends ConsumerState<CartItemModal> {
  Product? _product;
  bool _isLoading = true;
  String? _error;

  ProductVariation? _selectedVariation;
  int _quantity = 1;
  late PageController _imagePageController;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _quantity = widget.cartItem.quantity;
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

      final product = await ProductsApi.getProductById(widget.cartItem.productId);

      setState(() {
        _product = product;
        _isLoading = false;
      });

      // Pre-select current variation if it exists
      if (widget.cartItem.size != null || widget.cartItem.color != null) {
        _selectedVariation = product.variations.firstWhere(
          (v) =>
              v.size == widget.cartItem.size && v.color == widget.cartItem.color,
          orElse: () => product.variations.first,
        );
      } else if (product.variations.isNotEmpty) {
        _selectedVariation = product.variations.first;
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load product details: $e';
        _isLoading = false;
      });
    }
  }

  double get _currentPrice {
    if (_product == null) return widget.cartItem.price;
    return _selectedVariation?.price ?? _product!.salePrice ?? _product!.price;
  }

  void _updateCartItem() {
    final cartNotifier = ref.read(cartProvider.notifier);

    // If variant changed, we need to remove old and add new
    if (_selectedVariation != null &&
        (_selectedVariation!.size != widget.cartItem.size ||
            _selectedVariation!.color != widget.cartItem.color)) {
      // Remove old item
      cartNotifier.removeItem(widget.cartItem.id);
      // Add new with updated variant
      cartNotifier.addToCart(_product!, _quantity, _selectedVariation!);
    } else {
      // Just update quantity
      cartNotifier.updateQuantity(widget.cartItem.id, _quantity);
    }

    Navigator.pop(context);
    AlertService.showSnackBar(
      context: context,
      message: '${widget.cartItem.productName} updated',
      variant: AlertVariant.success,
    );
  }

  void _removeItem() {
    final cartNotifier = ref.read(cartProvider.notifier);
    cartNotifier.removeItem(widget.cartItem.id);
    Navigator.pop(context);
    AlertService.showSnackBar(
      context: context,
      message: '${widget.cartItem.productName} removed from cart',
      variant: AlertVariant.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(isDark)
                    : _error != null
                        ? _buildErrorState()
                        : _buildContent(context, isDark, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading product details...',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.destructive),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Failed to load product',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchProduct,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, ScrollController scrollController) {
    final product = _product!;
    final resolvedImages = product.images
        .map((img) => ApiClient.resolveImageUrl(img))
        .where((url) => url != null)
        .cast<String>()
        .toList();

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // Image Gallery
        SliverToBoxAdapter(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: PageView.builder(
                  controller: _imagePageController,
                  itemCount: resolvedImages.isNotEmpty ? resolvedImages.length : 1,
                  onPageChanged: (index) {
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final imageUrl = resolvedImages.isNotEmpty ? resolvedImages[index] : '';
                    return Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: isDark ? AppColors.darkMuted : AppColors.muted,
                                  highlightColor: isDark ? AppColors.darkCard : Colors.white,
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                                  child: Icon(Icons.broken_image, color: AppColors.mutedForeground),
                                ),
                              )
                            : Container(
                                color: isDark ? AppColors.darkMuted : AppColors.muted,
                                child: Icon(Icons.image_not_supported, color: AppColors.mutedForeground),
                              ),
                      ),
                    );
                  },
                ),
              ),

              // Page Indicator
              if (resolvedImages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SmoothPageIndicator(
                    controller: _imagePageController,
                    count: resolvedImages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: isDark ? AppColors.darkMuted : AppColors.muted,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 2,
                    ),
                    onDotClicked: (index) {
                      _imagePageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // Product Info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller Name
                if (product.sellerName.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      // Navigate to seller page
                    },
                    child: Text(
                      product.sellerName,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 4),

                // Product Name
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                      ),
                ),

                const SizedBox(height: 8),

                // Rating
                if (product.rating > 0)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (product.reviewCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${product.reviewCount} reviews)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),

                const SizedBox(height: 16),

                // Price
                Row(
                  children: [
                    Text(
                      FormatUtils.peso(_currentPrice),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (product.salePrice != null && product.salePrice! < product.price) ...[
                      const SizedBox(width: 12),
                      Text(
                        FormatUtils.peso(product.price),
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.mutedForeground,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Description
                if (product.description.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkMuted : AppColors.muted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'About this product',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          product.description.replaceAll(RegExp(r'<[^>]*>'), ''),
                          style: TextStyle(
                            color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                            height: 1.6,
                            fontSize: 14,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Variant Picker
                if (product.variations.isNotEmpty)
                  _buildVariantPicker(context, isDark, product),

                const SizedBox(height: 24),

                // Quantity Selector
                _buildQuantitySelector(context, isDark),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Bottom Actions
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _updateCartItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Update Cart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Remove Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: _removeItem,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                      ),
                      child: const Text(
                        'Remove Item',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // View Full Details
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      final slug = widget.cartItem.productSlug ?? product.slug;
                      if (slug.isNotEmpty) {
                        context.push('${AppRouter.product}/${Uri.encodeComponent(slug)}');
                      }
                    },
                    child: Text(
                      'View Full Details',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate(
      effects: AppAnimations.fadeIn(delay: 0),
    );
  }

  Widget _buildVariantPicker(BuildContext context, bool isDark, Product product) {
    final sizes = product.variations.map((v) => v.size).where((s) => s.isNotEmpty).toSet().toList();
    final colors = product.variations.map((v) => v.color).where((c) => c.isNotEmpty).toSet().toList();

    String? selectedSize;
    String? selectedColor;

    if (_selectedVariation != null) {
      selectedSize = _selectedVariation!.size;
      selectedColor = _selectedVariation!.color;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color Section
        if (colors.isNotEmpty) ...[
          Text(
            'Color',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: colors.map((color) {
              final isSelected = selectedColor == color;
              final colorVariations = product.variations.where((v) => v.color == color).toList();
              final hasStock = colorVariations.any((v) => v.inventory > 0);

              return GestureDetector(
                onTap: hasStock
                    ? () {
                        setState(() {
                          selectedColor = color;
                          // Find matching variation with current size or any size
                          if (selectedSize != null) {
                            _selectedVariation = product.variations.firstWhere(
                              (v) => v.color == color && v.size == selectedSize,
                              orElse: () => product.variations.firstWhere((v) => v.color == color),
                            );
                          } else {
                            _selectedVariation = product.variations.firstWhere((v) => v.color == color);
                            selectedSize = _selectedVariation!.size;
                          }
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : hasStock
                            ? (isDark ? AppColors.darkMuted : AppColors.muted)
                            : (isDark ? AppColors.darkMuted.withOpacity(0.5) : AppColors.muted.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    color,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : hasStock
                              ? (isDark ? AppColors.darkForeground : AppColors.charcoal)
                              : AppColors.mutedForeground,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Size Section
        if (sizes.isNotEmpty && selectedColor != null) ...[
          Text(
            'Size',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: sizes.map((size) {
              final isSelected = selectedSize == size;
              final matchingVariation = product.variations.firstWhere(
                (v) => v.size == size && (selectedColor == null || v.color == selectedColor),
                orElse: () => ProductVariation(id: '', size: size, color: selectedColor ?? '', inventory: 0, sku: ''),
              );
              final hasStock = matchingVariation.inventory > 0;

              return GestureDetector(
                onTap: hasStock && selectedColor != null && matchingVariation.id.isNotEmpty
                    ? () {
                        setState(() {
                          selectedSize = size;
                          _selectedVariation = product.variations.firstWhere(
                            (v) => v.size == size && v.color == selectedColor,
                          );
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : hasStock && selectedColor != null
                            ? (isDark ? AppColors.darkMuted : AppColors.muted)
                            : (isDark ? AppColors.darkMuted.withOpacity(0.5) : AppColors.muted.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    size,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : hasStock && selectedColor != null
                              ? (isDark ? AppColors.darkForeground : AppColors.charcoal)
                              : AppColors.mutedForeground,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Stock Info
          if (_selectedVariation != null)
            Text(
              '${_selectedVariation!.inventory} available',
              style: TextStyle(
                color: _selectedVariation!.inventory > 0 ? Colors.green : AppColors.destructive,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildQuantitySelector(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMuted : AppColors.muted.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.charcoal,
                ),
              ),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: (_selectedVariation != null && _quantity < _selectedVariation!.inventory) ||
                        (_selectedVariation == null && _quantity < 99)
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper function to show the modal
void showCartItemModal(BuildContext context, CartItem cartItem) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CartItemModal(cartItem: cartItem),
  );
}
