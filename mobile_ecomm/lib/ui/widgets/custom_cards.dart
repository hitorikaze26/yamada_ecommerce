import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/routes/app_router.dart';
import '../../core/services/alert_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../data/providers/auth_notifier.dart';
import '../../data/providers/wishlist_notifier.dart';
import '../../data/services/wishlist_api.dart';

/// Custom Card matching the web client's rounded, bordered card style
class YamadaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool hasShadow;

  const YamadaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = AppTheme.defaultRadius,
    this.backgroundColor,
    this.onTap,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark ? AppColors.darkCard : AppColors.card);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    Widget cardContent = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// Feature Card used in the "Why Shop with Yamada" section
class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final double delay;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return YamadaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMuted : AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDark ? AppColors.darkForeground : AppColors.charcoal,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          ),
        ],
      ),
    );
  }
}

/// Portal Card for Rider/Seller sections
class PortalCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final bool isReversed;

  const PortalCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.onButtonPressed,
    this.isReversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return YamadaCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isReversed)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkMuted : AppColors.secondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.charcoal,
                  ),
                ),
              if (!isReversed) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkForeground
                                : AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ],
                ),
              ),
              if (isReversed) const SizedBox(width: 16),
              if (isReversed)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkMuted : AppColors.secondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.charcoal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onButtonPressed,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats Card for dashboard
class StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return YamadaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          ),
        ],
      ),
    );
  }
}

/// Product Card for displaying products - styled to match client web design
class ProductCard extends ConsumerStatefulWidget {
  final String name;
  final double price;
  final double? salePrice;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final String? sellerName;
  final String? subcategory;
  final int itemsSold;
  final String? productId;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onQuickView;
  final bool isLoading;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.salePrice,
    this.imageUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.sellerName,
    this.subcategory,
    this.itemsSold = 0,
    this.productId,
    this.onTap,
    this.onAddToCart,
    this.onQuickView,
    this.isLoading = false,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _localLiked = false;
  bool _isPressed = false;

  bool get _isLiked {
    final id = widget.productId;
    if (id != null && id.isNotEmpty) {
      return ref.watch(wishlistProvider).items.any((p) => p.id == id);
    }
    return _localLiked;
  }

  Future<void> _onHeartTap() async {
    final id = widget.productId;
    if (id == null || id.isEmpty) {
      setState(() => _localLiked = !_localLiked);
      return;
    }

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

    final productId = int.tryParse(id);
    if (productId == null) return;

    final notifier = ref.read(wishlistProvider.notifier);
    if (notifier.isWishlisted(id)) {
      try {
        await WishlistApi.removeFromWishlist(productId);
        await notifier.fetchWishlist();
      } catch (_) {
        if (mounted) {
          AlertService.showSnackBar(
            context: context,
            message: 'Could not update wishlist',
            variant: AlertVariant.error,
          );
        }
      }
    } else {
      try {
        await WishlistApi.addToWishlist(productId);
        await notifier.fetchWishlist();
      } catch (_) {
        if (mounted) {
          AlertService.showSnackBar(
            context: context,
            message: 'Could not update wishlist',
            variant: AlertVariant.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDiscount = widget.salePrice != null && widget.salePrice! < widget.price;
    final displayPrice = widget.salePrice ?? widget.price;
    final discountPercent = hasDiscount
        ? ((1 - widget.salePrice! / widget.price) * 100).round()
        : 0;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final cardBg = isDark ? AppColors.darkCard : AppColors.card;

    if (widget.isLoading) {
      return _buildSkeleton(context);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
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
                      Container(
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                        child: widget.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    _buildImagePlaceholder(context),
                                errorWidget: (context, url, error) =>
                                    _buildImageError(context),
                              )
                            : _buildImagePlaceholder(context),
                      ),
                      if (hasDiscount && discountPercent > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-$discountPercent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _onHeartTap,
                          child: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: _isLiked
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkForeground
                                    : Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sellerName ?? 'Yamada Store',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkForeground
                            : AppColors.charcoal,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 11,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          FormatUtils.soldCount(widget.itemsSold),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.rating > 0) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const Icon(
                            Icons.star,
                            size: 11,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasDiscount)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              FormatUtils.peso(widget.price),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedForeground,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        Text(
                          FormatUtils.peso(displayPrice),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: hasDiscount
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkForeground
                                    : AppColors.charcoal),
                          ),
                        ),
                        const Spacer(),
                        if (widget.onAddToCart != null)
                          GestureDetector(
                            onTap: widget.onAddToCart,
                            behavior: HitTestBehavior.opaque,
                            child: Icon(
                              Icons.add_shopping_cart_outlined,
                              size: 20,
                              color: AppColors.primary,
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

  Widget _buildImagePlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkMuted : AppColors.muted,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildImageError(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkMuted : AppColors.muted,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 32,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
            const SizedBox(height: 4),
            Text(
              'No image',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: baseColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: Container(color: baseColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 10,
                    width: 70,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 56,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 12,
                        width: 40,
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 56,
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(4),
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
    );
  }
}

/// Category Card for the category grid or horizontal list
class CategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isHorizontal;
  final bool isLoading;

  const CategoryCard({
    super.key,
    required this.name,
    required this.icon,
    this.onTap,
    this.isHorizontal = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return _buildSkeleton(context);
    }

    return GestureDetector(
      onTap: onTap,
      child: isHorizontal
          ? _buildHorizontalLayout(context, isDark)
          : _buildGridLayout(context, isDark),
    );
  }

  Widget _buildHorizontalLayout(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkMuted
                : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.border.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 92,
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkForeground
                      : AppColors.charcoal,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout(BuildContext context, bool isDark) {
    return YamadaCard(
      padding: const EdgeInsets.all(16),
      hasShadow: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkMuted
                  : AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkForeground
                      : AppColors.charcoal,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: baseColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 11,
            width: 60,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable Card with press animation effects
/// Adapted from reference role selection card interactions
class SelectableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Duration animationDuration;

  const SelectableCard({
    super.key,
    required this.child,
    required this.onTap,
    required this.accentColor,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.borderRadius = 16.0,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<SelectableCard> createState() => _SelectableCardState();
}

class _SelectableCardState extends State<SelectableCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: widget.animationDuration,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _isPressed
                ? widget.accentColor
                : (isDark ? AppColors.darkBorder : AppColors.border),
            width: _isPressed ? 2 : 1,
          ),
          color: _isPressed
              ? widget.accentColor.withOpacity(0.05)
              : (isDark ? AppColors.darkCard : AppColors.card),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Animated card entrance wrapper
/// Provides consistent fade-in-up animation for cards
class AnimatedCard extends StatelessWidget {
  final Widget child;
  final double delay;
  final double duration;

  const AnimatedCard({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          duration: Duration(milliseconds: (duration * 1000).toInt()),
          delay: Duration(milliseconds: (delay * 1000).toInt()),
        )
        .slideY(
          begin: 0.2,
          duration: Duration(milliseconds: (duration * 1000).toInt()),
          delay: Duration(milliseconds: (delay * 1000).toInt()),
        );
  }
}
