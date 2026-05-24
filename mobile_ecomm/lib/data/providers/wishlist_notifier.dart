import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../services/wishlist_api.dart';

class WishlistState {
  final List<Product> items;
  final bool isLoading;
  final String? error;

  const WishlistState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  WishlistState copyWith({
    List<Product>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WishlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  WishlistNotifier() : super(const WishlistState());

  bool isWishlisted(String productId) {
    return state.items.any((p) => p.id == productId);
  }

  Future<void> fetchWishlist() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await WishlistApi.getWishlist();
      state = WishlistState(items: items, isLoading: false);
    } catch (e) {
      developer.log('fetchWishlist: $e', name: 'WishlistNotifier');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> toggle(Product product) async {
    final id = int.tryParse(product.id);
    if (id == null) return false;

    if (isWishlisted(product.id)) {
      await remove(product);
      return false;
    }
    await add(product);
    return true;
  }

  Future<void> add(Product product) async {
    final id = int.tryParse(product.id);
    if (id == null) return;
    if (isWishlisted(product.id)) return;

    final previous = state.items;
    state = state.copyWith(items: [...previous, product], clearError: true);
    try {
      await WishlistApi.addToWishlist(id);
    } catch (e) {
      state = state.copyWith(items: previous, error: e.toString());
      rethrow;
    }
  }

  Future<void> remove(Product product) async {
    final id = int.tryParse(product.id);
    if (id == null) return;

    final previous = state.items;
    state = state.copyWith(
      items: previous.where((p) => p.id != product.id).toList(),
      clearError: true,
    );
    try {
      await WishlistApi.removeFromWishlist(id);
    } catch (e) {
      state = state.copyWith(items: previous, error: e.toString());
      rethrow;
    }
  }

  Future<void> clearAll() async {
    final previous = state.items;
    state = state.copyWith(items: [], isLoading: true, clearError: true);
    try {
      await WishlistApi.clearWishlist();
      state = const WishlistState();
    } catch (e) {
      state = state.copyWith(
        items: previous,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  void clear() {
    state = const WishlistState();
  }
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, WishlistState>((ref) {
  return WishlistNotifier();
});
