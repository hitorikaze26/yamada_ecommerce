import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/store_name_link.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/cart_notifier.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_api.dart';
import '../../widgets/buyer_verification_banner.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  Map<String, dynamic>? _buyerAddress;

  @override
  void initState() {
    super.initState();
    // Leaving buy-now must not block cart selection (stale buyNowItems).
    ref.read(cartProvider.notifier).clearBuyNowCheckout();
    _loadBuyerProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending =
          GoRouterState.of(context).uri.queryParameters['pending'];
      if (pending == '1') {
        AlertService.showInfo(
          context: context,
          title: 'Account pending verification',
          message:
              'Your account is not yet verified. Please wait for admin approval before checkout.',
        );
      }
    });
  }

  Future<void> _loadBuyerProfile() async {
    try {
      final profile = await AuthApi.getBuyerProfile();
      if (mounted) {
        setState(() {
          _buyerAddress = profile['address'] as Map<String, dynamic>?;
        });
        // Calculate shipping with buyer address (codes preferred for accuracy)
        final cartNotifier = ref.read(cartProvider.notifier);
        await cartNotifier.calculateShipping(
          buyerRegion: _buyerAddress?['regionName']?.toString(),
          buyerProvince: _buyerAddress?['provinceName']?.toString(),
          buyerMunicipality: _buyerAddress?['municipalityName']?.toString(),
          buyerRegionCode: _buyerAddress?['regionCode']?.toString(),
          buyerProvinceCode: _buyerAddress?['provinceCode']?.toString(),
          buyerMunicipalityCode: _buyerAddress?['municipalityCode']?.toString(),
        );
      }
    } catch (e) {
      // Silently fail - shipping will use fallback calculation
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    // Calculate shipping when selection changes (with buyer address)
    ref.listen(cartProvider, (previous, next) {
      if (previous?.selectedItemIds != next.selectedItemIds) {
        cartNotifier.calculateShipping(
          buyerRegion: _buyerAddress?['regionName']?.toString(),
          buyerProvince: _buyerAddress?['provinceName']?.toString(),
          buyerMunicipality: _buyerAddress?['municipalityName']?.toString(),
          buyerRegionCode: _buyerAddress?['regionCode']?.toString(),
          buyerProvinceCode: _buyerAddress?['provinceCode']?.toString(),
          buyerMunicipalityCode: _buyerAddress?['municipalityCode']?.toString(),
        );
      }
    });

    final authState = ref.watch(authProvider);
    final role = authState.user?.role;
    final buyerCheckoutBlocked = authState.isAuthenticated &&
        !authState.isVerified &&
        role != UserRole.seller &&
        role != UserRole.rider &&
        role != UserRole.admin;

    final subtotal = cart.selectedSubtotal;
    final shipping = cart.selectedShipping;
    final total = cart.selectedTotal;

    // Group items by seller
    final itemsBySeller = <String, List<CartItem>>{};
    for (final item in cart.items) {
      itemsBySeller.putIfAbsent(item.sellerId, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        elevation: 0,
        actions: [
          if (cart.items.isNotEmpty) ...[
            TextButton(
              onPressed: () => cartNotifier.toggleSelectAll(),
              child: Text(
                cart.isAllSelected ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to remove all items from your cart?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.destructive,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await cartNotifier.clearCart();
                  if (context.mounted) {
                    AlertService.showSnackBar(
                      context: context,
                      message: 'Cart cleared',
                      variant: AlertVariant.info,
                    );
                  }
                }
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: AppColors.destructive),
              ),
            ),
          ],
        ],
      ),
      body: cart.items.isEmpty
          ? _buildEmptyState(context, isDark)
          : Column(
              children: [
                if (buyerCheckoutBlocked)
                  BuyerVerificationBanner(isDark: isDark),
                if (!buyerCheckoutBlocked && cart.selectedItemsBySeller.length > 1)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'You will place ${cart.selectedItemsBySeller.length} separate orders (one per store).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkForeground
                                : AppColors.charcoal,
                          ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(cartProvider.notifier).loadCart();
                      await _loadBuyerProfile();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: itemsBySeller.length,
                      itemBuilder: (context, index) {
                        final sellerId = itemsBySeller.keys.elementAt(index);
                        final items = itemsBySeller[sellerId]!;
                        final sellerName = items.first.sellerName;
                        
                        return _SellerSection(
                          sellerId: sellerId,
                          sellerName: sellerName,
                          items: items,
                          isDark: isDark,
                          delay: 200 + (index * 100),
                        );
                      },
                    ),
                  ),
                ),
                _buildBottomBar(
                  context,
                  cart,
                  isDark,
                  subtotal,
                  shipping,
                  total,
                  buyerCheckoutBlocked,
                ),
              ],
            ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    CartState cart,
    bool isDark,
    double subtotal,
    double shipping,
    double total,
    bool buyerCheckoutBlocked,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cart.selectedItemCount} items)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : AppColors.mutedForeground,
                      ),
                ),
                Text(
                  '${FormatUtils.peso(subtotal)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : AppColors.foreground,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shipping',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : AppColors.mutedForeground,
                      ),
                ),
                Text(
                  '${FormatUtils.peso(shipping)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : AppColors.foreground,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.foreground,
                      ),
                ),
                Text(
                  '${FormatUtils.peso(total)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: cart.selectedItems.isEmpty || buyerCheckoutBlocked
                    ? null
                    : () {
                        final auth = ref.read(authProvider);
                        if (!auth.isAuthenticated) {
                          context.push(
                            '${AppRouter.login}?role=buyer&redirect=${Uri.encodeComponent(AppRouter.cart)}',
                          );
                          return;
                        }
                        ref.read(cartProvider.notifier).clearBuyNowCheckout();
                        final loc = GoRouterState.of(context).uri.path;
                        final checkout = loc.startsWith(AppRouter.sellerBrowse)
                            ? '${AppRouter.checkout}?from=seller-browse'
                            : AppRouter.checkout;
                        context.push(checkout);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? AppColors.darkMuted : AppColors.muted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buyerCheckoutBlocked
                      ? 'Awaiting account approval'
                      : cart.selectedItems.isEmpty
                          ? 'Select items to checkout'
                          : 'Checkout (${cart.selectedItemCount})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.2, duration: 300.ms, delay: 150.ms);
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
            'Your cart is empty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white : AppColors.foreground,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppRouter.home),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }
}

/// Seller section widget - groups items by seller
class _SellerSection extends ConsumerWidget {
  final String sellerId;
  final String sellerName;
  final List<CartItem> items;
  final bool isDark;
  final int delay;

  const _SellerSection({
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.isDark,
    required this.delay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shop name bar — full card width
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary.withValues(alpha: 0.9) : AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: StoreNameLink(
              name: sellerName,
              storeId: sellerId,
              expandWidth: true,
              leadingIcon: Icons.store_outlined,
              iconSize: 18,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: Duration(milliseconds: delay ~/ 2))
              .slideX(begin: -0.2, duration: 300.ms, delay: Duration(milliseconds: delay ~/ 2)),

          // Items in this seller
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _CartItemCard(
              item: item,
              index: index,
              delay: delay + 100 + (index * 50),
              isDark: isDark,
              isLastItem: index == items.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  final CartItem item;
  final int index;
  final int delay;
  final bool isDark;
  final bool isLastItem;

  const _CartItemCard({
    required this.item,
    required this.index,
    required this.delay,
    required this.isDark,
    this.isLastItem = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final isSelected = cart.isSelected(item.id);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.destructive,
          borderRadius: isLastItem
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                )
              : BorderRadius.zero,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Item'),
            content: Text('Remove "${item.productName}" from cart?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        cartNotifier.removeItem(item.id);
        AlertService.showSnackBar(
          context: context,
          message: '${item.productName} removed from cart',
          variant: AlertVariant.info,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          border: Border(
            bottom: isLastItem
                ? BorderSide.none
                : BorderSide(
                    color: isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : AppColors.border.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          borderRadius: isLastItem
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                )
              : BorderRadius.zero,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    cartNotifier.toggleItemSelection(item.id);
                  },
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Product Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMuted : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.productImage != null
                    ? CachedNetworkImage(
                        imageUrl: ApiClient.resolveImageUrl(item.productImage) ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: isDark ? AppColors.darkMuted : const Color(0xFFF5F5F5),
                          highlightColor: isDark ? AppColors.darkCard : Colors.white,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) {
                          return Icon(
                            Icons.image_not_supported_outlined,
                            color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                            size: 32,
                          );
                        },
                      )
                    : Icon(
                        Icons.image_not_supported_outlined,
                        color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : AppColors.foreground,
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Size and Color in one row
                  Row(
                    children: [
                      if (item.size != null) ...[
                        Text(
                          item.size!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : AppColors.foreground,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (item.color != null) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getColorFromString(item.color!),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.color!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : AppColors.foreground,
                              ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Quantity Controls and Price (Stacked vertically)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity Controls
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: isDark ? Colors.white : AppColors.foreground,
                                ),
                                onPressed: () {
                                  cartNotifier.updateQuantity(
                                    item.id,
                                    item.quantity - 1,
                                  );
                                },
                              ),
                            ),
                            Container(
                              width: 50,
                              alignment: Alignment.center,
                              child: TextFormField(
                                initialValue: '${item.quantity}',
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isDark ? Colors.white : AppColors.foreground,
                                      fontWeight: FontWeight.w500,
                                    ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onFieldSubmitted: (value) {
                                  final newQuantity = int.tryParse(value) ?? item.quantity;
                                  if (newQuantity > 0 && newQuantity != item.quantity) {
                                    cartNotifier.updateQuantity(item.id, newQuantity);
                                  }
                                },
                                onTapOutside: (event) {
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: isDark ? Colors.white : AppColors.foreground,
                                ),
                                onPressed: () {
                                  cartNotifier.updateQuantity(
                                    item.id,
                                    item.quantity + 1,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Price below quantity
                      Text(
                        '${FormatUtils.peso((item.salePrice ?? item.productPrice) * item.quantity)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms, delay: Duration(milliseconds: delay ~/ 2))
          .slideX(begin: 0.1, duration: 300.ms, delay: Duration(milliseconds: delay ~/ 2)),
    );
  }

  Color _getColorFromString(String color) {
    switch (color.toLowerCase()) {
      case 'pink':
        return AppColors.primary;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'navy':
        return AppColors.navy;
      case 'gray':
        return Colors.grey;
      case 'gold':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
