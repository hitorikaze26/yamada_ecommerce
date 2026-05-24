import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';

/// Soft card surface used across the product detail page.
BoxDecoration productDetailSoftCardDecoration(bool isDark) {
  return BoxDecoration(
    color: isDark ? AppColors.darkCard : AppColors.card,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark ? AppColors.darkBorder : AppColors.border.withValues(alpha: 0.7),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class ProductDetailFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color? iconColor;

  const ProductDetailFloatingButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: iconColor ??
                (isDark ? AppColors.darkForeground : AppColors.charcoal),
          ),
        ),
      ),
    );
  }
}

class ProductDetailImageHero extends StatelessWidget {
  final List<String> imageUrls;
  final int discountPercent;
  final bool isLiked;
  final bool isDark;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;
  final void Function(int index, String url) onImageTap;

  const ProductDetailImageHero({
    super.key,
    required this.imageUrls,
    required this.discountPercent,
    required this.isLiked,
    required this.isDark,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.onToggleLike,
    required this.onShare,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.width * 1.05;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: pageController,
            itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final url = imageUrls.isEmpty ? '' : imageUrls[index];
              return GestureDetector(
                onTap: () {
                  if (url.isNotEmpty) onImageTap(index, url);
                },
                child: Container(
                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                  child: url.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary.withValues(alpha: 0.6),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _imageFallback(isDark),
                        )
                      : _imageFallback(isDark),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    (isDark ? AppColors.darkBackground : AppColors.background)
                        .withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          if (discountPercent > 0)
            Positioned(
              left: 20,
              bottom: 36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blush.withValues(alpha: isDark ? 0.25 : 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '$discountPercent% off',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.blush : AppColors.primary,
                  ),
                ),
              ),
            ),
          if (imageUrls.length > 1) ...[
            Positioned(
              left: 16,
              bottom: 52,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkCard : Colors.black)
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentIndex + 1} / ${imageUrls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 44,
              child: Center(
                child: SmoothPageIndicator(
                  controller: pageController,
                  count: imageUrls.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: AppColors.primary,
                    dotColor: Colors.white.withValues(alpha: 0.45),
                    dotHeight: 6,
                    dotWidth: 6,
                    expansionFactor: 3,
                    spacing: 6,
                  ),
                  onDotClicked: (index) {
                    pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
            ),
            if (currentIndex > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GalleryArrow(
                    icon: Icons.chevron_left_rounded,
                    isDark: isDark,
                    onTap: () => pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              ),
            if (currentIndex < imageUrls.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GalleryArrow(
                    icon: Icons.chevron_right_rounded,
                    isDark: isDark,
                    onTap: () => pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              ),
          ],
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ProductDetailFloatingButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                  isDark: isDark,
                ),
                Row(
                  children: [
                    ProductDetailFloatingButton(
                      icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      onTap: onToggleLike,
                      isDark: isDark,
                      iconColor: isLiked ? AppColors.primary : null,
                    ),
                    const SizedBox(width: 8),
                    ProductDetailFloatingButton(
                      icon: Icons.ios_share_rounded,
                      onTap: onShare,
                      isDark: isDark,
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

  Widget _imageFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkMuted,
                  AppColors.darkCard,
                ]
              : [
                  AppColors.blush.withValues(alpha: 0.5),
                  AppColors.offWhite,
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
            const SizedBox(height: 8),
            Text(
              'No product photos',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _GalleryArrow({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.88),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Thumbnail strip shown under the hero when multiple images exist.
class ProductDetailImageThumbnails extends StatelessWidget {
  final List<String> imageUrls;
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onThumbnailTap;

  const ProductDetailImageThumbnails({
    super.key,
    required this.imageUrls,
    required this.currentIndex,
    required this.isDark,
    required this.onThumbnailTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          final isSelected = index == currentIndex;
          return GestureDetector(
            onTap: () => onThumbnailTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imageUrls[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductDetailVariantTrigger extends StatefulWidget {
  final bool isDark;
  final String? selectedLabel;
  final VoidCallback onTap;

  const ProductDetailVariantTrigger({
    super.key,
    required this.isDark,
    required this.onTap,
    this.selectedLabel,
  });

  @override
  State<ProductDetailVariantTrigger> createState() =>
      _ProductDetailVariantTriggerState();
}

class _ProductDetailVariantTriggerState extends State<ProductDetailVariantTrigger> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selectedLabel != null && widget.selectedLabel!.isNotEmpty;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: productDetailSoftCardDecoration(widget.isDark).copyWith(
            color: widget.isDark
                ? AppColors.darkMuted.withValues(alpha: 0.5)
                : AppColors.offWhite,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.straighten_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSelection ? 'Selected options' : 'Choose size & color',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? AppColors.darkForeground
                                : AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSelection
                          ? widget.selectedLabel!
                          : 'Tap to select before adding to bag',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailSellerCard extends StatelessWidget {
  final String sellerName;
  final String? sellerLogo;
  final bool isDark;
  final VoidCallback? onTap;

  const ProductDetailSellerCard({
    super.key,
    required this.sellerName,
    this.sellerLogo,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: productDetailSoftCardDecoration(isDark),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage:
                    sellerLogo != null && sellerLogo!.isNotEmpty
                        ? CachedNetworkImageProvider(sellerLogo!)
                        : null,
                child: sellerLogo == null || sellerLogo!.isEmpty
                    ? Text(
                        sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'Y',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 14,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified seller',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.mutedForeground.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailBottomBar extends StatefulWidget {
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;
  final VoidCallback? onEditProduct;

  const ProductDetailBottomBar({
    super.key,
    required this.onAddToCart,
    required this.onBuyNow,
    this.onEditProduct,
  });

  @override
  State<ProductDetailBottomBar> createState() => _ProductDetailBottomBarState();
}

class _ProductDetailBottomBarState extends State<ProductDetailBottomBar> {
  bool _cartPressed = false;
  bool _buyPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.onEditProduct != null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: _PremiumActionButton(
              label: 'Edit product',
              icon: Icons.edit_outlined,
              isOutlined: false,
              isPressed: false,
              onTapDown: () {},
              onTapUp: () {},
              onTapCancel: () {},
              onTap: widget.onEditProduct!,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: _PremiumActionButton(
                  label: 'Add to Cart',
                  icon: Icons.shopping_bag_outlined,
                  isOutlined: true,
                  isPressed: _cartPressed,
                  onTapDown: () => setState(() => _cartPressed = true),
                  onTapUp: () => setState(() => _cartPressed = false),
                  onTapCancel: () => setState(() => _cartPressed = false),
                  onTap: widget.onAddToCart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _PremiumActionButton(
                  label: 'Buy Now',
                  icon: null,
                  isOutlined: false,
                  isPressed: _buyPressed,
                  onTapDown: () => setState(() => _buyPressed = true),
                  onTapUp: () => setState(() => _buyPressed = false),
                  onTapCancel: () => setState(() => _buyPressed = false),
                  onTap: widget.onBuyNow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isOutlined;
  final bool isPressed;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  const _PremiumActionButton({
    required this.label,
    required this.icon,
    required this.isOutlined,
    required this.isPressed,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      onTap: onTap,
      child: AnimatedScale(
        scale: isPressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.xlargeRadius),
            color: isOutlined ? Colors.transparent : AppColors.primary,
            border: isOutlined
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5)
                : null,
            boxShadow: isOutlined
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isOutlined ? AppColors.primary : AppColors.primaryForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailRelatedCard extends StatelessWidget {
  final String name;
  final double price;
  final double? salePrice;
  final String? imageUrl;
  final bool isDark;
  final VoidCallback onTap;

  const ProductDetailRelatedCard({
    super.key,
    required this.name,
    required this.price,
    this.salePrice,
    this.imageUrl,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrice = salePrice ?? price;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        height: 218,
        margin: const EdgeInsets.only(right: 14),
        decoration: productDetailSoftCardDecoration(isDark),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
                child: imageUrl != null
                    ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
                    : Icon(
                        Icons.image_outlined,
                        color: AppColors.mutedForeground.withValues(alpha: 0.5),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormatUtils.peso(displayPrice),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.08, end: 0);
  }
}

/// Shimmer-style skeleton while product detail loads.
class ProductDetailLoadingSkeleton extends StatelessWidget {
  final bool isDark;

  const ProductDetailLoadingSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? AppColors.darkMuted : AppColors.muted;
    final highlight = isDark
        ? AppColors.darkCard.withValues(alpha: 0.9)
        : AppColors.card;

    Widget block({double? w, double h = 14, double radius = 8}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    final heroH = MediaQuery.of(context).size.width * 1.05;

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: heroH,
            color: base,
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(w: 80, h: 10),
                  const SizedBox(height: 12),
                  block(h: 22, radius: 10),
                  const SizedBox(height: 10),
                  block(h: 22, w: 200, radius: 10),
                  const SizedBox(height: 16),
                  block(h: 28, w: 120, radius: 12),
                  const SizedBox(height: 20),
                  Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: highlight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: highlight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen pinch-zoom image viewer.
void showProductImageZoom(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: MediaQuery.of(ctx).padding.top + 12,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
