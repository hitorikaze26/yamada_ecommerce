import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../models/store_profile_model.dart';

class StoreFollowApi {
  static Future<List<StoreProfile>> getFollowingStores() async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get('/accounts/buyer/following-stores');
      if (response.statusCode == 200) {
        final data = response.data['stores'] as List? ?? [];
        return data
            .map((json) => StoreProfile.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load following stores: ${response.statusCode}');
    } on DioException catch (e) {
      developer.log('StoreFollowApi.getFollowingStores: $e', name: 'StoreFollowApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to load following stores');
    }
  }

  static Future<bool> isFollowing(int storeId) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get('/accounts/buyer/following-stores/$storeId');
      if (response.statusCode == 200) {
        return response.data['following'] == true;
      }
      return false;
    } on DioException catch (e) {
      developer.log('StoreFollowApi.isFollowing: $e', name: 'StoreFollowApi');
      return false;
    }
  }

  static Future<void> followStore(int storeId) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.post(
        '/accounts/buyer/following-stores',
        data: {'storeId': storeId},
      );
    } on DioException catch (e) {
      developer.log('StoreFollowApi.followStore: $e', name: 'StoreFollowApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to follow store');
    }
  }

  static Future<void> unfollowStore(int storeId) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.delete('/accounts/buyer/following-stores/$storeId');
    } on DioException catch (e) {
      developer.log('StoreFollowApi.unfollowStore: $e', name: 'StoreFollowApi');
      final msg = e.response?.data?['msg']?.toString();
      throw Exception(msg ?? 'Failed to unfollow store');
    }
  }
}
