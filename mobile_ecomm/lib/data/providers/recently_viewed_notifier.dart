import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../services/recently_viewed_api.dart';

class RecentlyViewedState {
  final List<RecentlyViewedItem> items;
  final bool isLoading;
  final String? error;

  const RecentlyViewedState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  RecentlyViewedState copyWith({
    List<RecentlyViewedItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RecentlyViewedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RecentlyViewedNotifier extends StateNotifier<RecentlyViewedState> {
  RecentlyViewedNotifier() : super(const RecentlyViewedState());

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await RecentlyViewedApi.getRecentlyViewed();
      state = RecentlyViewedState(items: items, isLoading: false);
    } catch (e) {
      developer.log('fetch recently viewed: $e', name: 'RecentlyViewedNotifier');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> recordView(Product product) async {
    final id = int.tryParse(product.id);
    if (id == null) return;
    try {
      await RecentlyViewedApi.recordView(id);
    } catch (e) {
      developer.log('recordView: $e', name: 'RecentlyViewedNotifier');
    }
  }

  Future<void> clearAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await RecentlyViewedApi.clearAll();
      state = const RecentlyViewedState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  void clear() {
    state = const RecentlyViewedState();
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, RecentlyViewedState>((ref) {
  return RecentlyViewedNotifier();
});
