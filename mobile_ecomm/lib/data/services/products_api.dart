import 'dart:developer' as developer;
import '../../core/services/api_client.dart';
import '../models/product_model.dart';
import '../models/product_review_model.dart';
import 'store_api.dart';

/// Products API Service
/// Handles fetching products from the backend
class ProductsApi {
  /// Fetch all products with optional query parameters
  static Future<List<Product>> getProducts({
    int? limit,
    String? category,
    String? sort,
    bool? isNew,
    bool? isBestSeller,
    /// Substring match on name, description, subcategory (see server `listProducts`).
    String? search,
    /// Alias for [search] (server accepts `q`).
    String? q,
    /// Filter by store id (`seller` query param on server).
    String? seller,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      
      // Build query parameters
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (category != null) queryParams['category'] = category;
      if (sort != null) queryParams['sort'] = sort;
      if (isNew != null) queryParams['is_new'] = isNew;
      if (isBestSeller != null) queryParams['is_best_seller'] = isBestSeller;
      final sq = (search ?? q)?.trim();
      if (sq != null && sq.isNotEmpty) {
        queryParams['search'] = sq;
      }
      if (seller != null && seller.isNotEmpty) {
        queryParams['seller'] = int.tryParse(seller) ?? seller;
      }
      
      final response = await dio.get('/products', queryParameters: queryParams.isEmpty ? null : queryParams);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['products'] ?? response.data ?? [];
        final products = data.map((json) => Product.fromJson(json)).toList();
        developer.log('Fetched ${products.length} products', name: 'ProductsApi');
        return products;
      } else {
        throw Exception('Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching products: $e', name: 'ProductsApi');
      throw Exception('Failed to fetch products: $e');
    }
  }
  
  /// Fetch new arrivals (latest products)
  static Future<List<Product>> getNewArrivals({int limit = 8}) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/products', queryParameters: {
        'limit': limit,
        'sort': 'newest',
      });
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['products'] ?? response.data ?? [];
        developer.log('Fetched ${data.length} new arrivals', name: 'ProductsApi');
        
        // Debug: Log first product image data
        if (data.isNotEmpty) {
          final first = data.first as Map<String, dynamic>;
          developer.log('First product images: ${first['images'] ?? first['image_url'] ?? first['media']}', name: 'ProductsApi');
        }
        
        return data.map((json) => Product.fromJson(json)).toList().cast<Product>();
      } else {
        throw Exception('Failed to fetch new arrivals: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching new arrivals: $e', name: 'ProductsApi');
      throw Exception('Failed to fetch new arrivals: $e');
    }
  }
  
  /// Fetch best sellers (most popular products)
  static Future<List<Product>> getBestSellers({int limit = 8}) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/products', queryParameters: {
        'limit': limit,
        'sort': 'popular',
      });
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['products'] ?? response.data ?? [];
        return data.map((json) => Product.fromJson(json)).toList().cast<Product>();
      } else {
        throw Exception('Failed to fetch best sellers: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching best sellers: $e', name: 'ProductsApi');
      throw Exception('Failed to fetch best sellers: $e');
    }
  }
  
  /// Fetch product by ID
  static Future<Product> getProductById(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/products/product/$id');

      if (response.statusCode == 200) {
        // Server returns { "product": { ... } }
        final productData = response.data['product'] ?? response.data;
        return Product.fromJson(productData);
      } else {
        throw Exception('Failed to fetch product: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching product: $e', name: 'ProductsApi');
      throw Exception('Failed to fetch product: $e');
    }
  }

  /// Fetch product by slug
  /// Since backend doesn't have a slug endpoint, we try ID first if numeric,
  /// then fall back to fetching all products and filtering by slug
  static Future<Product> getProductBySlug(String slug) async {
    // If slug looks like an ID, try ID endpoint first
    final numericId = int.tryParse(slug);
    if (numericId != null) {
      try {
        return await getProductById(numericId.toString());
      } catch (e) {
        developer.log('Failed to fetch by ID, falling back to slug search: $e', name: 'ProductsApi');
      }
    }

    // Search by slug/name before loading the full catalog
    try {
      final results = await searchProducts(slug, limit: 24);
      for (final p in results) {
        if (p.slug == slug) return p;
      }
      if (results.length == 1) return results.first;
    } catch (e) {
      developer.log('Slug search failed, trying catalog: $e', name: 'ProductsApi');
    }

    try {
      final products = await getProducts(limit: 200);
      return products.firstWhere(
        (p) => p.slug == slug,
        orElse: () => throw Exception('Product not found'),
      );
    } catch (e) {
      developer.log('Error fetching product by slug: $e', name: 'ProductsApi');
      throw Exception('Product not found');
    }
  }
  
  /// Search products via `GET /products?search=…` (SQL ilike on server).
  static Future<List<Product>> searchProducts(
    String query, {
    int limit = 48,
    String? sort,
    String? category,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    return getProducts(
      limit: limit,
      search: trimmed,
      sort: sort,
      category: category,
    );
  }
  
  /// Fetch featured stores/sellers
  static Future<List<Map<String, dynamic>>> getFeaturedStores({int limit = 6}) async {
    return StoreApi.getFeaturedStores(limit: limit);
  }

  /// GET /api/products/{id}/reviews
  static Future<({List<ProductReview> reviews, Map<String, double> dimensionAverages, Map<String, int> ratingBreakdown})>
      getProductReviews(int productId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/products/$productId/reviews');
    final data = response.data as Map<String, dynamic>? ?? {};
    final reviews = (data['reviews'] as List?)
            ?.map((e) => ProductReview.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final dimAvg = <String, double>{};
    final dimRaw = data['dimensionAverages'];
    if (dimRaw is Map) {
      dimRaw.forEach((k, v) {
        if (v is num) dimAvg[k.toString()] = v.toDouble();
      });
    }
    final breakdown = <String, int>{};
    final brRaw = data['ratingBreakdown'];
    if (brRaw is Map) {
      brRaw.forEach((k, v) {
        if (v is num) breakdown[k.toString()] = v.toInt();
      });
    }
    return (reviews: reviews, dimensionAverages: dimAvg, ratingBreakdown: breakdown);
  }
}
