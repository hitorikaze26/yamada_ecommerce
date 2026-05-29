import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../../core/routes/app_router.dart';
import '../../core/services/api_client.dart';
import '../../core/services/alert_service.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/product_model.dart';
import '../../data/providers/cart_notifier.dart';
import '../screens/product/widgets/product_detail_widgets.dart';

typedef ProductVariantSelectionCallback = void Function(
  ProductVariation? variation,
  int quantity,
);

/// Modal for selecting product variant (color, size, quantity) before adding to cart
class ProductVariantModal extends ConsumerStatefulWidget {
  final Product product;
  final ProductVariation? initialVariation;
  final int initialQuantity;
  final bool isBuyNow;
  final VoidCallback? onClose;
  final ProductVariantSelectionCallback? onSelectionChanged;

  const ProductVariantModal({
    super.key,
    required this.product,
    this.initialVariation,
    this.initialQuantity = 1,
    this.isBuyNow = false,
    this.onClose,
    this.onSelectionChanged,
  });

  @override
  ConsumerState<ProductVariantModal> createState() => _ProductVariantModalState();
}

class _ProductVariantModalState extends ConsumerState<ProductVariantModal> {
  ProductVariation? _selectedVariation;
  int _quantity = 1;
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _selectedVariation = widget.initialVariation;
    _quantity = widget.initialQuantity;
    _quantityController = TextEditingController(text: '$_quantity');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _notifySelection() {
    widget.onSelectionChanged?.call(_selectedVariation, _quantity);
  }

  double get _currentPrice {
    return _selectedVariation?.price ?? widget.product.salePrice ?? widget.product.price;
  }

  String get _mainImageUrl {
    if (widget.product.images.isNotEmpty) {
      final resolved = ApiClient.resolveImageUrl(widget.product.images.first);
      return resolved ?? '';
    }
    return '';
  }

  Color _parseColor(String hexColor) {
    try {
      if (hexColor.startsWith('#')) {
        return Color(int.parse(hexColor.substring(1), radix: 16) + 0xFF000000);
      }
      return Colors.grey;
    } catch (_) {
      return Colors.grey;
    }
  }

  String _getColorHex(String colorName) {
    final colorMap = {
      'black': '#000000',
      'white': '#FFFFFF',
      'red': '#FF0000',
      'blue': '#0000FF',
      'green': '#008000',
      'yellow': '#FFFF00',
      'pink': '#FFC0CB',
      'purple': '#800080',
      'orange': '#FFA500',
      'gray': '#808080',
      'grey': '#808080',
      'brown': '#8B4513',
      'navy': '#000080',
      'beige': '#F5F5DC',
      'cream': '#FFFDD0',
    };
    return colorMap[colorName.toLowerCase()] ?? '#808080';
  }

  void _addToCart() {
    if (_selectedVariation == null) {
      _showError('Please select a color and size');
      return;
    }

    if (_selectedVariation!.inventory <= 0) {
      _showError('This item is out of stock');
      return;
    }

    if (_quantity > _selectedVariation!.inventory) {
      _showError('Only ${_selectedVariation!.inventory} items available');
      return;
    }

    ref.read(cartProvider.notifier).addToCart(
          widget.product,
          _quantity,
          _selectedVariation!,
        );

    Navigator.of(context).pop();

    AlertService.showSnackBar(
      context: context,
      message: '${widget.product.name} added to cart',
      variant: AlertVariant.success,
    );
  }

  Future<void> _buyNow() async {
    if (_selectedVariation == null) {
      _showError('Please select a color and size');
      return;
    }

    if (_selectedVariation!.inventory <= 0) {
      _showError('This item is out of stock');
      return;
    }

    if (_quantity > _selectedVariation!.inventory) {
      _showError('Only ${_selectedVariation!.inventory} items available');
      return;
    }

    try {
      if (widget.isBuyNow) {
        await ref.read(cartProvider.notifier).startBuyNowCheckout(
              widget.product,
              _quantity,
              _selectedVariation!,
            );
      } else {
        await ref.read(cartProvider.notifier).addToCart(
              widget.product,
              _quantity,
              _selectedVariation!,
            );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      context.push(AppRouter.checkout);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    AlertService.showSnackBar(
      context: context,
      message: message,
      variant: AlertVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? AppColors.darkBackground : AppColors.offWhite;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select options',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.darkMuted
                            : AppColors.blush.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: productDetailSoftCardDecoration(isDark),
                        child: _buildProductHeader(context, isDark),
                      ),
                      const SizedBox(height: 20),
                      _buildColorSelector(context, isDark),
                      const SizedBox(height: 20),
                      _buildSizeSelector(context, isDark),
                      const SizedBox(height: 20),
                      _buildQuantitySelector(context, isDark),
                      if (_selectedVariation != null) ...[
                        const SizedBox(height: 16),
                        _buildStockInfo(context, isDark),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              _buildBottomActions(context, isDark),
            ],
          );
        },
      ),
    ).animate(effects: AppAnimations.fadeInUp());
  }

  Widget _buildProductHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Product Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 80,
            height: 80,
            color: isDark ? AppColors.darkMuted : AppColors.muted,
            child: _mainImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: _mainImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: isDark ? AppColors.darkMuted : AppColors.muted,
                      highlightColor: isDark ? AppColors.darkCard : Colors.white,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.image_not_supported,
                      color: AppColors.mutedForeground,
                    ),
                  )
                : Icon(
                    Icons.image_not_supported,
                    color: AppColors.mutedForeground,
                  ),
          ),
        ),
        const SizedBox(width: 16),

        // Product Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                FormatUtils.peso(_currentPrice),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              if (_selectedVariation != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_selectedVariation!.color} / ${_selectedVariation!.size}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelector(BuildContext context, bool isDark) {
    // Extract unique colors with their hex values
    final colorMap = <String, String>{};
    for (final v in widget.product.variations) {
      if (v.color.isNotEmpty && !colorMap.containsKey(v.color)) {
        colorMap[v.color] = v.colorHex ?? _getColorHex(v.color);
      }
    }
    final colors = colorMap.entries.toList();

    if (colors.isEmpty) return const SizedBox.shrink();

    final selectedColor = _selectedVariation?.color ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            if (selectedColor.isNotEmpty)
              Text(
                selectedColor,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: colors.map((entry) {
            final colorName = entry.key;
            final colorHex = entry.value;
            final isSelected = selectedColor == colorName;
            final hasStock = widget.product.variations.any(
              (v) => v.color == colorName && v.inventory > 0,
            );

            return GestureDetector(
              onTap: hasStock
                  ? () {
                      setState(() {
                        final variationForColor = widget.product.variations.firstWhere(
                          (v) => v.color == colorName && v.inventory > 0,
                          orElse: () => widget.product.variations.firstWhere(
                            (v) => v.color == colorName,
                          ),
                        );
                        _selectedVariation = variationForColor;
                      });
                      _notifySelection();
                    }
                  : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _parseColor(colorHex),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : hasStock
                            ? Colors.transparent
                            : Colors.grey.shade300,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: !hasStock
                    ? Center(
                        child: Container(
                          width: 2,
                          height: 30,
                          color: Colors.grey.shade400,
                          transform: Matrix4.rotationZ(0.785398),
                        ),
                      )
                    : isSelected
                        ? const Center(
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          )
                        : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSizeSelector(BuildContext context, bool isDark) {
    final selectedColor = _selectedVariation?.color ?? '';
    final selectedSize = _selectedVariation?.size ?? '';

    // Get available sizes for selected color
    final availableSizes = selectedColor.isNotEmpty
        ? widget.product.variations
            .where((v) => v.color == selectedColor && v.size.isNotEmpty)
            .map((v) => v.size)
            .toSet()
            .toList()
        : <String>[];

    if (availableSizes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Size',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a color first',
            style: TextStyle(
              color: AppColors.mutedForeground,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Size',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            if (selectedSize.isNotEmpty)
              Text(
                selectedSize,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: availableSizes.map((size) {
            final isSelected = selectedSize == size;
            final variation = widget.product.variations.firstWhere(
              (v) => v.color == selectedColor && v.size == size,
            );
            final hasStock = variation.inventory > 0;

            return GestureDetector(
              onTap: hasStock
                  ? () {
                      setState(() => _selectedVariation = variation);
                      _notifySelection();
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : hasStock
                          ? (isDark ? AppColors.darkMuted : AppColors.offWhite)
                          : AppColors.muted.withValues(alpha: 0.4),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.border),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : hasStock
                            ? (isDark ? AppColors.darkForeground : AppColors.charcoal)
                            : Colors.grey.shade500,
                    decoration: hasStock ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector(BuildContext context, bool isDark) {
    final maxQuantity = _selectedVariation?.inventory ?? 99;

    void setQuantity(int value) {
      final clamped = value.clamp(1, maxQuantity);
      setState(() => _quantity = clamped);
      _quantityController.text = '$clamped';
      _quantityController.selection = TextSelection.collapsed(
        offset: _quantityController.text.length,
      );
      _notifySelection();
    }

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
        Row(
          children: [
            // Decrease button
            IconButton(
              onPressed: _quantity > 1 ? () => setQuantity(_quantity - 1) : null,
              icon: const Icon(Icons.remove),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkMuted : Colors.grey.shade200,
                foregroundColor: _quantity > 1 ? null : Colors.grey,
              ),
            ),

            // Editable quantity field
            SizedBox(
              width: 64,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed >= 1) {
                    setState(() => _quantity = parsed.clamp(1, maxQuantity));
                  }
                },
                onSubmitted: (value) {
                  final parsed = int.tryParse(value) ?? 1;
                  setQuantity(parsed);
                },
                onTapOutside: (_) {
                  // Clamp and sync when focus leaves
                  final parsed = int.tryParse(_quantityController.text) ?? 1;
                  setQuantity(parsed);
                  FocusScope.of(context).unfocus();
                },
              ),
            ),

            // Increase button
            IconButton(
              onPressed: _quantity < maxQuantity
                  ? () => setQuantity(_quantity + 1)
                  : null,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkMuted : Colors.grey.shade200,
                foregroundColor: _quantity < maxQuantity ? null : Colors.grey,
              ),
            ),

            const Spacer(),

            // Max indicator
            Text(
              'Max: $maxQuantity',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockInfo(BuildContext context, bool isDark) {
    final stock = _selectedVariation?.inventory ?? 0;

    return Row(
      children: [
        Icon(
          stock > 0 ? Icons.check_circle : Icons.error,
          color: stock > 0 ? Colors.green : AppColors.destructive,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          stock > 0 ? '$stock items in stock' : 'Out of stock',
          style: TextStyle(
            fontSize: 14,
            color: stock > 0 ? Colors.green : AppColors.destructive,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.isBuyNow ? _buyNow : _addToCart,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 50),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(widget.isBuyNow ? 'Buy Now' : 'Add to Cart'),
          ),
        ),
      ),
    );
  }
}

/// Show the product variant modal
void showProductVariantModal({
  required BuildContext context,
  required Product product,
  ProductVariation? initialVariation,
  int initialQuantity = 1,
  bool isBuyNow = false,
  ProductVariantSelectionCallback? onSelectionChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ProductVariantModal(
      product: product,
      initialVariation: initialVariation,
      initialQuantity: initialQuantity,
      isBuyNow: isBuyNow,
      onSelectionChanged: onSelectionChanged,
    ),
  );
}
