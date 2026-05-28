import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/auth_api.dart';
import '../services/cart_api.dart';
import '../services/shipping_api.dart';

class OwnStoreProductException implements Exception {
  final String message;
  const OwnStoreProductException([
    this.message = 'You cannot purchase products from your own store.',
  ]);
  @override
  String toString() => message;
}

Future<void> _guardOwnStorePurchase(Product product) async {
  if (product.sellerId.isEmpty) return;
  try {
    final profile = await AuthApi.getSellerProfile();
    final storeId = (profile['storeId'] as num?)?.toInt();
    if (storeId == null) return;
    final productStoreId = product.sellerId.trim();
    if (productStoreId == storeId.toString() ||
        productStoreId == '${profile['storeId']}') {
      throw const OwnStoreProductException();
    }
  } catch (e) {
    if (e is OwnStoreProductException) rethrow;
    developer.log('_guardOwnStorePurchase: $e', name: 'CartNotifier');
  }
}

/// Cart state
class CartState {
  final List<CartItem> items;
  final Set<String> selectedItemIds;
  final List<CartItem>? buyNowItems;
  final Map<String, double> shippingFeeBySeller;
  final bool isCalculatingShipping;
  final String? shippingError;

  const CartState({
    this.items = const [],
    this.selectedItemIds = const {},
    this.buyNowItems,
    this.shippingFeeBySeller = const {},
    this.isCalculatingShipping = false,
    this.shippingError,
  });

  bool get isBuyNowCheckout => buyNowItems != null && buyNowItems!.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    Set<String>? selectedItemIds,
    List<CartItem>? buyNowItems,
    bool clearBuyNowItems = false,
    Map<String, double>? shippingFeeBySeller,
    bool? isCalculatingShipping,
    String? shippingError,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      buyNowItems: clearBuyNowItems ? null : (buyNowItems ?? this.buyNowItems),
      shippingFeeBySeller: shippingFeeBySeller ?? this.shippingFeeBySeller,
      isCalculatingShipping: isCalculatingShipping ?? this.isCalculatingShipping,
      shippingError: shippingError ?? this.shippingError,
    );
  }

  int get itemCount => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get shipping => selectedShipping;
  double get total => subtotal + shipping;

  // Cart selection (always from persisted cart items)
  List<CartItem> get selectedItems =>
      items.where((item) => selectedItemIds.contains(item.id)).toList();

  /// Items to show on checkout: buy-now snapshot or selected cart lines.
  List<CartItem> get checkoutItems {
    if (isBuyNowCheckout) return buyNowItems!;
    return selectedItems;
  }

  int get selectedItemCount => selectedItems.length;

  int get selectedQuantity => selectedItems.fold(0, (sum, item) => sum + item.quantity);

  double get selectedSubtotal =>
      selectedItems.fold(0, (sum, item) => sum + item.total);

  // Group selected items by seller for shipping calculation
  Map<String, List<CartItem>> get selectedItemsBySeller {
    final map = <String, List<CartItem>>{};
    for (final item in selectedItems) {
      map.putIfAbsent(item.sellerId, () => []).add(item);
    }
    return map;
  }

  // Calculate subtotal per seller
  Map<String, double> get selectedSubtotalBySeller {
    final map = <String, double>{};
    for (final entry in selectedItemsBySeller.entries) {
      map[entry.key] = entry.value.fold(0, (sum, item) => sum + item.total);
    }
    return map;
  }

  // Calculate shipping per seller using cached API results or fallback
  double get selectedShipping {
    double totalShipping = 0;
    for (final entry in selectedSubtotalBySeller.entries) {
      final sellerId = entry.key;
      final subtotal = entry.value;
      // Use cached shipping fee if available, otherwise use fallback
      final shippingFee = shippingFeeBySeller[sellerId];
      if (shippingFee != null) {
        totalShipping += shippingFee;
      } else {
        // Fallback: free shipping over ₱10000, else ₱100 per seller
        totalShipping += subtotal >= 10000 ? 0 : 100;
      }
    }
    return totalShipping;
  }

  // Check if any seller qualifies for free shipping
  Map<String, bool> get freeShippingBySeller {
    final map = <String, bool>{};
    for (final entry in selectedSubtotalBySeller.entries) {
      final sellerId = entry.key;
      final subtotal = entry.value;
      final shippingFee = shippingFeeBySeller[sellerId];
      map[sellerId] = shippingFee != null ? shippingFee == 0 : subtotal >= 10000;
    }
    return map;
  }

  double get selectedTotal => selectedSubtotal + selectedShipping;

  Map<String, List<CartItem>> get checkoutItemsBySeller {
    final map = <String, List<CartItem>>{};
    for (final item in checkoutItems) {
      map.putIfAbsent(item.sellerId, () => []).add(item);
    }
    return map;
  }

  double get checkoutSubtotal =>
      checkoutItems.fold(0, (sum, item) => sum + item.total);

  double get checkoutShipping {
    double totalShipping = 0;
    for (final entry in checkoutItemsBySeller.entries) {
      final sellerId = entry.key;
      final subtotal =
          entry.value.fold(0.0, (sum, item) => sum + item.total);
      final shippingFee = shippingFeeBySeller[sellerId];
      if (shippingFee != null) {
        totalShipping += shippingFee;
      } else {
        totalShipping += subtotal >= 10000 ? 0 : 100;
      }
    }
    return totalShipping;
  }

  double get checkoutTotal => checkoutSubtotal + checkoutShipping;

  bool get isAllSelected =>
      items.isNotEmpty && items.every((item) => selectedItemIds.contains(item.id));

  bool isSelected(String itemId) => selectedItemIds.contains(itemId);
}

/// Cart Notifier using Riverpod
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState()) {
    // Load cart from database on initialization
    loadCart();
  }

  /// Load cart from database
  Future<void> loadCart() async {
    try {
      state = state.copyWith(isCalculatingShipping: true);
      final items = await CartApi.getCart();
      state = state.copyWith(
        items: items,
        selectedItemIds: items.map((i) => i.id).toSet(),
        clearBuyNowItems: true,
        isCalculatingShipping: false,
      );
      developer.log('Cart loaded: ${items.length} items', name: 'CartNotifier');
    } catch (e) {
      developer.log('Error loading cart: $e', name: 'CartNotifier');
      state = state.copyWith(isCalculatingShipping: false);
    }
  }

  /// Add to cart - sync with database
  Future<void> addToCart(
    Product product,
    int quantity,
    ProductVariation variation,
  ) async {
    try {
      await _guardOwnStorePurchase(product);
      // First update locally for responsiveness
      final items = List<CartItem>.from(state.items);
      final existingIndex = items.indexWhere(
        (item) =>
            item.productId == product.id &&
            item.size == variation.size &&
            item.color == variation.color,
      );

      if (existingIndex >= 0) {
        final existing = items[existingIndex];
        final newQuantity = existing.quantity + quantity;
        items[existingIndex] = existing.copyWith(quantity: newQuantity);
        // Update in database
        if (existing.id.isNotEmpty && int.tryParse(existing.id) != null) {
          await CartApi.updateQuantity(
            itemId: int.parse(existing.id),
            quantity: newQuantity,
          );
        }
      } else {
        items.add(CartItem(
          id: '${product.id}_${variation.id}_${DateTime.now().millisecondsSinceEpoch}',
          productId: product.id,
          productName: product.name,
          productImage: product.images.isNotEmpty ? product.images.first : null,
          productPrice: product.price,
          salePrice: variation.price ?? product.salePrice,
          quantity: quantity,
          size: variation.size,
          color: variation.color,
          sku: variation.sku,
          productSlug: product.slug,
          sellerId: product.sellerId,
          sellerName: product.sellerName,
        ));
        // Add to database
        await CartApi.addToCart(
          productId: product.id,
          variationId: variation.id,
          quantity: quantity,
        );
      }

      state = state.copyWith(items: items);
      
      // Reload to get proper IDs from database
      await loadCart();
    } catch (e) {
      developer.log('Error adding to cart: $e', name: 'CartNotifier');
      throw Exception('Failed to add to cart: $e');
    }
  }

  Future<void> addToCartSimple(Product product, int quantity) async {
    await _guardOwnStorePurchase(product);
    final variation = product.variations.isNotEmpty ? product.variations.first : null;
    if (variation == null) return;
    await addToCart(product, quantity, variation);
  }

  /// Update quantity - sync with database
  Future<void> updateQuantity(String itemId, int quantity) async {
    try {
      // Update locally first for responsiveness
      final items = List<CartItem>.from(state.items);
      final index = items.indexWhere((item) => item.id == itemId);
      if (index >= 0) {
        final item = items[index];
        
        if (quantity <= 0) {
          items.removeAt(index);
        } else {
          items[index] = item.copyWith(quantity: quantity);
        }
        state = state.copyWith(items: items);

        // Sync with database
        if (item.id.isNotEmpty && int.tryParse(item.id) != null) {
          if (quantity <= 0) {
            await CartApi.removeItem(int.parse(item.id));
          } else {
            await CartApi.updateQuantity(
              itemId: int.parse(item.id),
              quantity: quantity,
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error updating quantity: $e', name: 'CartNotifier');
      throw Exception('Failed to update quantity: $e');
    }
  }

  /// Remove item - sync with database
  Future<void> removeItem(String itemId) async {
    try {
      // Update locally first
      final items = List<CartItem>.from(state.items);
      final item = items.firstWhere((item) => item.id == itemId);
      items.removeWhere((item) => item.id == itemId);
      
      // Also remove from selected items
      final selectedIds = Set<String>.from(state.selectedItemIds);
      selectedIds.remove(itemId);
      state = state.copyWith(items: items, selectedItemIds: selectedIds);

      // Sync with database
      if (item.id.isNotEmpty && int.tryParse(item.id) != null) {
        await CartApi.removeItem(int.parse(item.id));
      }
    } catch (e) {
      developer.log('Error removing item: $e', name: 'CartNotifier');
      throw Exception('Failed to remove item: $e');
    }
  }

  /// Remove all selected items - sync with database
  Future<void> removeSelectedItems() async {
    try {
      final selectedIds = List<String>.from(state.selectedItemIds);
      
      for (final itemId in selectedIds) {
        await removeItem(itemId);
      }
    } catch (e) {
      developer.log('Error removing selected items: $e', name: 'CartNotifier');
      throw Exception('Failed to remove selected items: $e');
    }
  }

  /// Remove specific cart line ids (e.g. after partial multi-store checkout).
  Future<void> removeItemsWithIds(Iterable<String> itemIds) async {
    for (final itemId in itemIds) {
      if (state.items.any((i) => i.id == itemId)) {
        await removeItem(itemId);
      }
    }
  }

  /// Clear cart in memory only (e.g. after logout when API session is gone).
  void clearCartLocal() {
    state = const CartState();
    developer.log('Cart cleared locally', name: 'CartNotifier');
  }

  /// Clear cart - sync with database
  Future<void> clearCart() async {
    try {
      state = const CartState();
      await CartApi.clearCart();
      developer.log('Cart cleared', name: 'CartNotifier');
    } catch (e) {
      developer.log('Error clearing cart: $e', name: 'CartNotifier');
      throw Exception('Failed to clear cart: $e');
    }
  }

  /// Buy Now: checkout only this product (does not add to cart).
  Future<void> startBuyNowCheckout(
    Product product,
    int quantity,
    ProductVariation variation,
  ) async {
    await _guardOwnStorePurchase(product);
    final itemId =
        'buy-now-${product.id}_${variation.id}_${DateTime.now().millisecondsSinceEpoch}';
    final item = CartItem(
      id: itemId,
      productId: product.id,
      productName: product.name,
      productImage: product.images.isNotEmpty ? product.images.first : null,
      productPrice: product.price,
      salePrice: variation.price ?? product.salePrice,
      quantity: quantity,
      size: variation.size,
      color: variation.color,
      sku: variation.sku,
      productSlug: product.slug,
      sellerId: product.sellerId,
      sellerName: product.sellerName,
    );
  // Do not touch selectedItemIds — cart selection must stay independent of buy-now.
    state = state.copyWith(buyNowItems: [item]);
    developer.log('Buy now checkout started for ${product.name}', name: 'CartNotifier');
  }

  void clearBuyNowCheckout() {
    if (!state.isBuyNowCheckout) return;
    // Restore cart line selection after leaving buy-now checkout.
    final restoredSelection = state.items.isEmpty
        ? const <String>{}
        : state.items.map((i) => i.id).toSet();
    state = state.copyWith(
      clearBuyNowItems: true,
      selectedItemIds: restoredSelection,
    );
  }

  /// Calculate shipping fees from API for cart selected lines.
  Future<void> calculateShipping({
    String? buyerRegion,
    String? buyerProvince,
    String? buyerMunicipality,
    String? buyerRegionCode,
    String? buyerProvinceCode,
    String? buyerMunicipalityCode,
  }) {
    return _calculateShippingForLines(
      state.selectedItems,
      buyerRegion: buyerRegion,
      buyerProvince: buyerProvince,
      buyerMunicipality: buyerMunicipality,
      buyerRegionCode: buyerRegionCode,
      buyerProvinceCode: buyerProvinceCode,
      buyerMunicipalityCode: buyerMunicipalityCode,
    );
  }

  /// Calculate shipping for checkout (buy-now snapshot or selected cart lines).
  Future<void> calculateCheckoutShipping({
    String? buyerRegion,
    String? buyerProvince,
    String? buyerMunicipality,
    String? buyerRegionCode,
    String? buyerProvinceCode,
    String? buyerMunicipalityCode,
  }) {
    return _calculateShippingForLines(
      state.checkoutItems,
      buyerRegion: buyerRegion,
      buyerProvince: buyerProvince,
      buyerMunicipality: buyerMunicipality,
      buyerRegionCode: buyerRegionCode,
      buyerProvinceCode: buyerProvinceCode,
      buyerMunicipalityCode: buyerMunicipalityCode,
    );
  }

  Future<void> _calculateShippingForLines(
    List<CartItem> itemsToShip, {
    String? buyerRegion,
    String? buyerProvince,
    String? buyerMunicipality,
    String? buyerRegionCode,
    String? buyerProvinceCode,
    String? buyerMunicipalityCode,
  }) async {
    if (itemsToShip.isEmpty) {
      state = state.copyWith(shippingFeeBySeller: {}, shippingError: null);
      return;
    }

    state = state.copyWith(isCalculatingShipping: true, shippingError: null);

    try {
      final itemsBySeller = <String, List<CartItem>>{};
      for (final item in itemsToShip) {
        itemsBySeller.putIfAbsent(item.sellerId, () => []).add(item);
      }

      final shopTotals = <int, double>{};
      for (final entry in itemsBySeller.entries) {
        final sellerId = entry.key;
        final items = entry.value;
        final total = items.fold(0.0, (sum, item) => sum + item.total);
        final parsed = int.tryParse(sellerId);
        if (parsed != null) {
          shopTotals[parsed] = total;
        }
      }

      if (shopTotals.isEmpty) {
        state = state.copyWith(isCalculatingShipping: false);
        return;
      }

      final results = await ShippingApi.calculateShippingForShops(
        shopTotals: shopTotals,
        buyerRegion: buyerRegion,
        buyerProvince: buyerProvince,
        buyerMunicipality: buyerMunicipality,
        buyerRegionCode: buyerRegionCode,
        buyerProvinceCode: buyerProvinceCode,
        buyerMunicipalityCode: buyerMunicipalityCode,
      );

      final shippingMap = <String, double>{};
      for (final entry in results.entries) {
        shippingMap[entry.key.toString()] = entry.value.shippingFee;
      }

      state = state.copyWith(
        shippingFeeBySeller: shippingMap,
        isCalculatingShipping: false,
      );

      developer.log('Shipping calculated: $shippingMap', name: 'CartNotifier');
    } catch (e) {
      developer.log('Error calculating shipping: $e', name: 'CartNotifier');
      state = state.copyWith(
        isCalculatingShipping: false,
        shippingError: 'Failed to calculate shipping: $e',
      );
    }
  }

  /// Clear calculated shipping (use fallback)
  void clearCalculatedShipping() {
    state = state.copyWith(shippingFeeBySeller: {}, shippingError: null);
  }

  void toggleItemSelection(String itemId) {
    final selectedIds = Set<String>.from(state.selectedItemIds);
    if (selectedIds.contains(itemId)) {
      selectedIds.remove(itemId);
    } else {
      selectedIds.add(itemId);
    }
    state = state.copyWith(selectedItemIds: selectedIds);
  }

  void selectAll() {
    final allIds = state.items.map((item) => item.id).toSet();
    state = state.copyWith(selectedItemIds: allIds);
  }

  void deselectAll() {
    state = state.copyWith(selectedItemIds: {});
  }

  void toggleSelectAll() {
    if (state.isAllSelected) {
      deselectAll();
    } else {
      selectAll();
    }
  }

  bool isInCart(String productId, {String? size, String? color}) {
    return state.items.any((item) =>
        item.productId == productId &&
        (size == null || item.size == size) &&
        (color == null || item.color == color));
  }
}

/// Riverpod provider for cart
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
