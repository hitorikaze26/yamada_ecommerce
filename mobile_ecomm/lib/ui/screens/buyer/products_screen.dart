import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/product_model.dart';

class ProductsScreen extends ConsumerWidget {
  final List<Product> products;
  final String? title;

  const ProductsScreen({
    super.key,
    required this.products,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(title ?? 'Products'),
        elevation: 0,
      ),
      body: products.isEmpty
          ? _buildEmptyState(context, isDark)
          : CustomScrollView(
              slivers: [
                // Categories Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shop by Category',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.foreground,
                              ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideX(begin: -0.2, duration: 600.ms),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'Dresses',
                              'Tops',
                              'Outerwear',
                              'Activewear',
                              'Lingerie',
                            ]
                                .asMap()
                                .entries
                                .expand(
                                  (entry) => [
                                    _CategoryChip(
                                      label: entry.value,
                                      delay: 200 + (entry.key * 100),
                                      isDark: isDark,
                                    ),
                                    if (entry.key < 4) const SizedBox(width: 12),
                                  ],
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Products Grid
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return _ProductCard(
                          product: product,
                          onTap: () => context.push(
                            '${AppRouter.product}/${Uri.encodeComponent(product.slug)}',
                          ),
                          delay: 300 + (index * 100),
                          isDark: isDark,
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            'No products available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white : AppColors.foreground,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int delay;
  final bool isDark;

  const _CategoryChip({
    required this.label,
    required this.delay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      onSelected: (value) {},
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isDark ? Colors.white : AppColors.foreground,
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: Duration(milliseconds: delay))
        .slideX(begin: 0.2, duration: 600.ms, delay: Duration(milliseconds: delay));
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final int delay;
  final bool isDark;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.delay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final discountPercent = product.discountPercent;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        color: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkMuted : AppColors.warmGray,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.network(
                        product.images.isNotEmpty ? product.images.first : '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                            ),
                          );
                        },
                      ),
                    ),
                    if (discountPercent > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.destructive,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$discountPercent% OFF',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white : AppColors.foreground,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        FormatUtils.peso(product.currentPrice),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (product.salePrice != null && product.salePrice! < product.price) ...[
                        const SizedBox(width: 8),
                        Text(
                          FormatUtils.peso(product.price),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                              ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${product.rating}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white70 : AppColors.foreground,
                                ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.add,
                          size: 14,
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
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: Duration(milliseconds: delay))
        .slideY(begin: 0.2, duration: 600.ms, delay: Duration(milliseconds: delay));
  }
}

