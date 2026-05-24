import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/store_profile_model.dart';
import '../services/store_follow_api.dart';

class FollowingStoresState {
  final Set<String> followedIds;
  final List<StoreProfile> stores;
  final bool isLoading;
  final String? error;

  const FollowingStoresState({
    this.followedIds = const {},
    this.stores = const [],
    this.isLoading = false,
    this.error,
  });

  FollowingStoresState copyWith({
    Set<String>? followedIds,
    List<StoreProfile>? stores,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FollowingStoresState(
      followedIds: followedIds ?? this.followedIds,
      stores: stores ?? this.stores,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FollowingStoresNotifier extends StateNotifier<FollowingStoresState> {
  FollowingStoresNotifier() : super(const FollowingStoresState());

  bool isFollowing(String storeId) => state.followedIds.contains(storeId);

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final stores = await StoreFollowApi.getFollowingStores();
      state = FollowingStoresState(
        stores: stores,
        followedIds: stores.map((s) => s.id).toSet(),
        isLoading: false,
      );
    } catch (e) {
      developer.log('fetch following: $e', name: 'FollowingStoresNotifier');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> checkFollowing(String storeId) async {
    final id = int.tryParse(storeId);
    if (id == null) return false;
    try {
      final following = await StoreFollowApi.isFollowing(id);
      if (following) {
        state = state.copyWith(
          followedIds: {...state.followedIds, storeId},
        );
      } else {
        final next = {...state.followedIds}..remove(storeId);
        state = state.copyWith(followedIds: next);
      }
      return following;
    } catch (_) {
      return isFollowing(storeId);
    }
  }

  Future<bool> toggleFollow(String storeId) async {
    final id = int.tryParse(storeId);
    if (id == null) return false;

    if (isFollowing(storeId)) {
      await unfollow(storeId);
      return false;
    }
    await follow(storeId);
    return true;
  }

  Future<void> follow(String storeId) async {
    final id = int.tryParse(storeId);
    if (id == null) return;
    final previous = state.followedIds;
    state = state.copyWith(
      followedIds: {...previous, storeId},
      clearError: true,
    );
    try {
      await StoreFollowApi.followStore(id);
    } catch (e) {
      state = state.copyWith(followedIds: previous, error: e.toString());
      rethrow;
    }
  }

  Future<void> unfollow(String storeId) async {
    final id = int.tryParse(storeId);
    if (id == null) return;
    final previousIds = state.followedIds;
    final previousStores = state.stores;
    state = state.copyWith(
      followedIds: {...previousIds}..remove(storeId),
      stores: previousStores.where((s) => s.id != storeId).toList(),
      clearError: true,
    );
    try {
      await StoreFollowApi.unfollowStore(id);
    } catch (e) {
      state = state.copyWith(
        followedIds: previousIds,
        stores: previousStores,
        error: e.toString(),
      );
      rethrow;
    }
  }

  void clear() {
    state = const FollowingStoresState();
  }
}

final followingStoresProvider =
    StateNotifierProvider<FollowingStoresNotifier, FollowingStoresState>((ref) {
  return FollowingStoresNotifier();
});
