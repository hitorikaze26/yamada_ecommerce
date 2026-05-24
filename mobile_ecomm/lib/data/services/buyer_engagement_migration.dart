import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'recently_viewed_api.dart';
import 'store_follow_api.dart';

/// One-time import of legacy local follow / recently-viewed data to the server.
class BuyerEngagementMigration {
  BuyerEngagementMigration._();

  static const _followKey = 'yamada_followed_stores';
  static const _recentKey = 'yamada_recently_viewed_v1';
  static const _migratedFlag = 'yamada_buyer_engagement_migrated_v1';

  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlag) == true) return;

    await _migrateFollows();
    await _migrateRecentlyViewed();

    await prefs.setBool(_migratedFlag, true);
  }

  static Future<void> _migrateFollows() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_followKey) ?? [];
    for (final id in ids) {
      final storeId = int.tryParse(id);
      if (storeId == null) continue;
      try {
        await StoreFollowApi.followStore(storeId);
      } catch (e) {
        developer.log('migrate follow $storeId: $e', name: 'BuyerEngagementMigration');
      }
    }
    if (ids.isNotEmpty) {
      await prefs.remove(_followKey);
    }
  }

  static Future<void> _migrateRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final list = jsonDecode(raw) as List;
      for (final item in list.reversed) {
        if (item is! Map) continue;
        final productId = int.tryParse(item['productId']?.toString() ?? '');
        if (productId == null) continue;
        try {
          await RecentlyViewedApi.recordView(productId);
        } catch (e) {
          developer.log('migrate recent $productId: $e', name: 'BuyerEngagementMigration');
        }
      }
      await prefs.remove(_recentKey);
    } catch (e) {
      developer.log('migrate recently viewed parse: $e', name: 'BuyerEngagementMigration');
    }
  }
}
