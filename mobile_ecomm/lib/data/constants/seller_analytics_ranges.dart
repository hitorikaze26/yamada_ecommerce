/// Time-range keys for seller analytics API (`?days=`).
abstract final class SellerAnalyticsRanges {
  static const defaultKey = '30d';

  static const Map<String, int> daysByKey = {
    '7d': 7,
    '30d': 30,
    '90d': 90,
    '1y': 365,
  };

  static int daysFor(String key) => daysByKey[key] ?? 30;
}
