import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/seller_products_api.dart';

/// Seller Products State
class SellerProductsState {
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final String? error;

  const SellerProductsState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isInitialLoading => isLoading && products.isEmpty;
  bool get isRefreshing => isLoading && products.isNotEmpty;

  int get totalProducts => products.length;
  int get activeProducts =>
      products.where((p) => p['visibility'] == true).length;
  int get inactiveProducts =>
      products.where((p) => p['visibility'] == false).length;
  int get totalSold =>
      products.fold<int>(0, (sum, p) => sum + (p['sold'] as int? ?? 0));

  SellerProductsState copyWith({
    List<Map<String, dynamic>>? products,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SellerProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Seller Products Notifier
class SellerProductsNotifier extends StateNotifier<SellerProductsState> {
  SellerProductsNotifier() : super(const SellerProductsState());

  /// Fetch seller products. Keeps the list visible when refreshing.
  Future<void> fetchProducts({bool silent = false}) async {
    final hasData = state.products.isNotEmpty;
    state = state.copyWith(
      isLoading: !silent || !hasData,
      clearError: true,
    );
    developer.log('Starting to fetch seller products',
        name: 'SellerProductsNotifier');

    try {
      final products = await SellerProductsApi.getSellerProducts();
      developer.log('Successfully fetched ${products.length} products',
          name: 'SellerProductsNotifier');
      state = state.copyWith(
        products: products,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      developer.log('Error fetching seller products: $e',
          name: 'SellerProductsNotifier');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Pull-to-refresh — keeps products on screen while reloading.
  Future<void> refreshProducts() => fetchProducts(silent: true);

  Future<bool> deleteProduct(String productId) async {
    try {
      await SellerProductsApi.deleteProduct(productId);

      // Remove the product from the state
      final updatedProducts =
          state.products.where((p) => p['id'].toString() != productId).toList();
      state = state.copyWith(products: updatedProducts);

      return true;
    } catch (e) {
      developer.log('Error deleting product: $e',
          name: 'SellerProductsNotifier');
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Create a new product and refresh the list on success.
  Future<bool> createProduct({
    required String name,
    required String brand,
    required String description,
    required String category,
    String? subcategory,
    required double price,
    double? salePrice,
    double? costPrice,
    required String condition,
    double? weightKg,
    String? material,
    String? careInstructions,
    String? tags,
    String? lowStockThreshold,
    required List<Map<String, dynamic>> variations,
    required List<File> imageFiles,
    List<File> videoFiles = const [],
    Map<String, dynamic>? sizeChart,
  }) async {
    try {
      await SellerProductsApi.createProduct(
        name: name,
        brand: brand,
        description: description,
        category: category,
        subcategory: subcategory,
        price: price,
        salePrice: salePrice,
        costPrice: costPrice,
        condition: condition,
        weightKg: weightKg,
        material: material,
        careInstructions: careInstructions,
        tags: tags,
        lowStockThreshold: lowStockThreshold,
        variations: variations,
        imageFiles: imageFiles,
        videoFiles: videoFiles,
        sizeChart: sizeChart,
      );
      // Refresh the product list so the new item appears immediately
      await fetchProducts();
      return true;
    } catch (e) {
      developer.log('Error creating product: $e',
          name: 'SellerProductsNotifier');
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }
}

/// Riverpod provider for seller products
final sellerProductsProvider =
    StateNotifierProvider<SellerProductsNotifier, SellerProductsState>((ref) {
  return SellerProductsNotifier();
});
