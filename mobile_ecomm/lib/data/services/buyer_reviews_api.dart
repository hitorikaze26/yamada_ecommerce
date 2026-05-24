import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../models/product_review_model.dart';

class BuyerReviewsApi {
  static Future<({List<ProductReview> reviews, int total})> getMyReviews({
    int page = 1,
    int perPage = 20,
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get(
        '/accounts/buyer/reviews',
        queryParameters: {'page': page, 'per_page': perPage},
      );
      final list = (response.data['reviews'] as List? ?? [])
          .map((e) => ProductReview.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = (response.data['total'] as num?)?.toInt() ?? list.length;
      return (reviews: list, total: total);
    } on DioException catch (e) {
      throw Exception(e.response?.data['msg'] ?? 'Failed to load reviews');
    }
  }
}
