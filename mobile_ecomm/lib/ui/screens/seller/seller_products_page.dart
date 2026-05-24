import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/routes/app_router.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/seller_products_notifier.dart';
import '../../../data/services/auth_api.dart';

class SellerProductsPage extends ConsumerStatefulWidget {
  const SellerProductsPage({super.key});

  @override
  ConsumerState<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends ConsumerState<SellerProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  // Mirrors the client tabs: all / active / draft / out of stock
  String _activeTab = 'all';
  static const _tabs = ['all', 'active', 'draft', 'out of stock'];

  Future<void> _onAddProduct() async {
    if (!ref.read(authProvider).isVerified) {
      AlertService.showSnackBar(
        context: context,
        message: 'Your store must be approved before adding products.',
        variant: AlertVariant.info,
      );
      return;
    }
    try {
      final profile = await AuthApi.getSellerProfile();
      if ((profile['storeId'] as num?) == null) {
        if (!mounted) return;
        AlertService.showSnackBar(
          context: context,
          message: 'Store not ready yet. Please wait for admin approval.',
          variant: AlertVariant.info,
        );
        return;
      }
      if (mounted) context.push(AppRouter.sellerAddProduct);
    } catch (e) {
      if (!mounted) return;
      AlertService.showSnackBar(
        context: context,
        message: e.toString().replaceAll('Exception: ', ''),
        variant: AlertVariant.error,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    Future.microtask(
      () => ref.read(sellerProductsProvider.notifier).fetchProducts(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _matchesSearch(Map<String, dynamic> p) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    final fields = [
      p['name']?.toString(),
      p['brand']?.toString(),
      p['subcategory']?.toString(),
      p['tags']?.toString(),
      p['description']?.toString(),
    ];
    for (final field in fields) {
      if (field != null && field.toLowerCase().contains(q)) return true;
    }

    final variations = p['variations'] as List<dynamic>? ?? [];
    for (final raw in variations) {
      if (raw is! Map) continue;
      final sku = raw['sku']?.toString().toLowerCase() ?? '';
      final color = raw['color']?.toString().toLowerCase() ?? '';
      if (sku.contains(q) || color.contains(q)) return true;
    }
    return false;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Derive status the same way the Next.js client does:
  ///   - visibility == false  → "draft"
  ///   - total inventory == 0 → "out of stock"
  ///   - otherwise            → "active"
  String _statusOf(Map<String, dynamic> p) {
    final visibility = p['visibility'] as bool? ?? true;
    if (!visibility) return 'draft';

    final variations = p['variations'] as List<dynamic>? ?? [];
    final totalInventory = variations.fold<int>(
      0,
      (sum, v) => sum + ((v as Map<String, dynamic>)['inventory'] as int? ?? 0),
    );
    // Also fall back to top-level quantity when no variations exist
    final quantity = p['quantity'] as int? ?? totalInventory;
    final stock = variations.isNotEmpty ? totalInventory : quantity;

    if (stock == 0) return 'out of stock';
    return 'active';
  }

  int _stockOf(Map<String, dynamic> p) {
    final variations = p['variations'] as List<dynamic>? ?? [];
    if (variations.isNotEmpty) {
      return variations.fold<int>(
        0,
        (sum, v) => sum + ((v as Map<String, dynamic>)['inventory'] as int? ?? 0),
      );
    }
    return p['quantity'] as int? ?? 0;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> products) {
    return products.where((p) {
      final status = _statusOf(p);
      final matchesTab = _activeTab == 'all' || status == _activeTab;
      return matchesTab && _matchesSearch(p);
    }).toList();
  }

  // ── delete flow ───────────────────────────────────────────────────────────

  Future<void> _confirmDelete(
    BuildContext context,
    String productId,
    String productName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Product',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete "$productName"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final success = await ref
        .read(sellerProductsProvider.notifier)
        .deleteProduct(productId);

    if (!context.mounted) return;
    AlertService.showSnackBar(
      context: context,
      message: success ? 'Product deleted successfully' : 'Failed to delete product',
      variant: success ? AlertVariant.success : AlertVariant.error,
    );
  }

  // ── product detail bottom sheet ───────────────────────────────────────────

  void _showProductDetail(
    BuildContext context,
    Map<String, dynamic> product,
    bool isDark,
  ) {
    final imageUrl = ApiClient.resolveImageUrl(product['image_url'] as String?);
    final name = product['name'] as String? ?? 'Unknown Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final description = product['description'] as String? ?? '';
    final subcategory = product['subcategory'] as String?;
    final sold = product['sold'] as int? ?? 0;
    final stock = _stockOf(product);
    final status = _statusOf(product);
    final variations = product['variations'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _imagePlaceholder(),
                              )
                            : _imagePlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name + price row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          FormatUtils.peso(price),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    if (subcategory != null && subcategory.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subcategory,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Stats row
                    Row(
                      children: [
                        _detailChip(
                          label: 'Status',
                          value: status,
                          color: _statusColor(status),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _detailChip(
                          label: 'Stock',
                          value: stock.toString(),
                          color: stock == 0
                              ? Colors.red
                              : const Color(0xFF3B82F6),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _detailChip(
                          label: 'Sold',
                          value: sold.toString(),
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    // Description
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        // Strip basic HTML tags from rich-text description
                        description
                            .replaceAll(RegExp(r'<[^>]*>'), '')
                            .trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                    ],

                    // Variations
                    if (variations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Variations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...variations.map((v) {
                        final vMap = v as Map<String, dynamic>;
                        final size = vMap['size'] as String? ?? '';
                        final color = vMap['color'] as String? ?? '';
                        final sku = vMap['sku'] as String? ?? '';
                        final inv = vMap['inventory'] as int? ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBackground
                                : AppColors.warmBeige,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  [
                                    if (size.isNotEmpty) 'Size: $size',
                                    if (color.isNotEmpty) 'Color: $color',
                                    if (sku.isNotEmpty) 'SKU: $sku',
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.charcoal,
                                  ),
                                ),
                              ),
                              Text(
                                'Stock: $inv',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: inv == 0
                                      ? Colors.red
                                      : AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF22C55E);
      case 'draft':
        return const Color(0xFF6B7280);
      case 'out of stock':
        return const Color(0xFFEF4444);
      default:
        return AppColors.mutedForeground;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsState = ref.watch(sellerProductsProvider);
    final filtered = _filtered(productsState.products);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(isDark, filtered.length, productsState.products.length),
                const SizedBox(height: 12),
                _buildStatsRow(productsState, isDark),
                const SizedBox(height: 12),
                _buildTabBar(isDark),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Expanded(
            child: productsState.isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : productsState.error != null && productsState.products.isEmpty
                    ? _buildError(productsState.error!)
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : Stack(
                            children: [
                              RefreshIndicator(
                                onRefresh: () => ref
                                    .read(sellerProductsProvider.notifier)
                                    .refreshProducts(),
                                child: _buildProductList(filtered, isDark),
                              ),
                              if (productsState.isRefreshing)
                                const Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: LinearProgressIndicator(minHeight: 2),
                                ),
                            ],
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddProduct,
        backgroundColor: AppColors.rosewood,
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildSearchBar(bool isDark, int shown, int total) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final focused = _searchFocus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: AppColors.rosewood.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (v) => setState(() => _searchQuery = v),
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.charcoal,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name, brand, SKU, tags…',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : AppColors.mutedForeground,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: focused
                    ? AppColors.rosewood
                    : (isDark ? Colors.grey[400] : AppColors.mutedForeground),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.rosewood, width: 1.5),
              ),
            ),
          ),
        ),
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Showing $shown of $total products',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : AppColors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(SellerProductsState state, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total',
            state.totalProducts.toString(),
            const Color(0xFF10B981),
            isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'Active',
            state.activeProducts.toString(),
            const Color(0xFF3B82F6),
            isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'Sold',
            state.totalSold.toString(),
            const Color(0xFFF59E0B),
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.map((tab) {
          final isActive = _activeTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.rosewood
                    : (isDark ? AppColors.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppColors.rosewood
                      : (isDark
                          ? AppColors.darkBorder
                          : AppColors.border),
                ),
              ),
              child: Text(
                tab[0].toUpperCase() + tab.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : AppColors.mutedForeground,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(color: Colors.red[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(sellerProductsProvider.notifier)
                  .refreshProducts(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No products match "$_searchQuery"'
                : 'No products in this category',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(
      List<Map<String, dynamic>> products, bool isDark) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildProductCard(context, products[index], isDark),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Map<String, dynamic> product,
    bool isDark,
  ) {
    final imageUrl = ApiClient.resolveImageUrl(product['image_url'] as String?);
    final name = product['name'] as String? ?? 'Unknown Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final sold = product['sold'] as int? ?? 0;
    final stock = _stockOf(product);
    final status = _statusOf(product);
    final productId = product['id'].toString();

    return GestureDetector(
      onTap: () => _showProductDetail(context, product, isDark),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product image ──────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: SizedBox(
                width: 90,
                height: 90,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          );
                        },
                      )
                    : _imagePlaceholder(),
              ),
            ),

            // ── Product info ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.charcoal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      FormatUtils.peso(price),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Status + stock + sold chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _statusBadge(status, isDark),
                        _infoBadge(
                          'Stock: $stock',
                          stock == 0
                              ? Colors.red
                              : const Color(0xFF3B82F6),
                          isDark,
                        ),
                        _infoBadge(
                          '$sold sold',
                          const Color(0xFFF59E0B),
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Action buttons ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Edit
                  _actionButton(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF3B82F6),
                    onTap: () async {
                      final updated = await context.push<bool>(
                        AppRouter.sellerEditProduct(productId),
                      );
                      if (updated == true && context.mounted) {
                        await ref
                            .read(sellerProductsProvider.notifier)
                            .fetchProducts();
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // Delete
                  _actionButton(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: () =>
                        _confirmDelete(context, productId, name),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status, bool isDark) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _infoBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
