import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Skeleton loader base widget using shimmer effect
class SkeletonLoader extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const SkeletonLoader({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

/// Product card skeleton loader
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image skeleton
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.defaultRadius),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: isDark ? AppColors.darkMuted : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Name skeleton
        Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMuted : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        // Rating skeleton
        Container(
          height: 12,
          width: 80,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMuted : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        // Price skeleton
        Container(
          height: 16,
          width: 100,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMuted : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

/// Product grid skeleton loader
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const ProductGridSkeleton({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.65,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => const ProductCardSkeleton(),
      ),
    );
  }
}

/// Category card skeleton loader
class CategoryCardSkeleton extends StatelessWidget {
  const CategoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon skeleton
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMuted : Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 12),
        // Name skeleton
        Container(
          height: 12,
          width: 60,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMuted : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

/// Horizontal category list skeleton
class CategoryListSkeleton extends StatelessWidget {
  final int itemCount;

  const CategoryListSkeleton({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(
            itemCount,
            (index) => const Padding(
              padding: EdgeInsets.only(right: 12),
              child: CategoryCardSkeleton(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero carousel skeleton loader
class HeroCarouselSkeleton extends StatelessWidget {
  const HeroCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMuted : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

/// Section header skeleton loader
class SectionHeaderSkeleton extends StatelessWidget {
  const SectionHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkMuted : Colors.grey[300]!;
    final highlightColor = isDark ? AppColors.darkCard : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 140,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkMuted : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkMuted : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            Container(
              height: 14,
              width: 50,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMuted : Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
