import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../../core/utils/file_utils.dart';

/// Seller Products API Service
/// Handles fetching, creating, and deleting seller-specific products.
class SellerProductsApi {
  /// Fetch products for the currently authenticated seller.
  static Future<List<Map<String, dynamic>>> getSellerProducts() async {
    try {
      final dio = await ApiClient.getInstance();
      developer.log('Fetching seller products from /seller/products',
          name: 'SellerProductsApi');
      final response = await dio.get('/seller/products');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['products'] ?? [];
        developer.log('Fetched ${data.length} seller products',
            name: 'SellerProductsApi');
        return data.map((json) => json as Map<String, dynamic>).toList();
      } else {
        throw Exception(
            'Failed to fetch seller products: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching seller products: $e',
          name: 'SellerProductsApi');
      throw Exception('Failed to fetch seller products: $e');
    }
  }

  /// Delete a product by ID.
  static Future<bool> deleteProduct(String productId) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.delete('/products/delete/$productId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        developer.log('Deleted product $productId', name: 'SellerProductsApi');
        return true;
      } else {
        throw Exception('Failed to delete product: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error deleting product: $e', name: 'SellerProductsApi');
      throw Exception('Failed to delete product: $e');
    }
  }

  /// Create a new product via multipart/form-data (mirrors the web client).
  static Future<void> createProduct({
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
      final dio = await ApiClient.getInstance();
      final formData = FormData();

      // ── Basic fields ──────────────────────────────────────────────────
      formData.fields.addAll([
        MapEntry('name', name),
        MapEntry('brand', brand),
        MapEntry('description', description),
        MapEntry('category', category),
        MapEntry('product_condition', condition),
        MapEntry('price', price.toStringAsFixed(0)),
      ]);

      if (subcategory != null && subcategory.isNotEmpty) {
        formData.fields.add(MapEntry('subcategory', subcategory));
      }
      if (salePrice != null) {
        formData.fields
            .add(MapEntry('sale_price', salePrice.toStringAsFixed(0)));
      }
      if (costPrice != null) {
        formData.fields.add(MapEntry('cost_price', costPrice.toString()));
      }
      if (weightKg != null) {
        formData.fields.add(MapEntry('weight_kg', weightKg.toString()));
      }
      if (material != null && material.isNotEmpty) {
        formData.fields.add(MapEntry('material', material));
      }
      if (careInstructions != null && careInstructions.isNotEmpty) {
        formData.fields.add(MapEntry('care_instructions', careInstructions));
      }
      if (tags != null && tags.isNotEmpty) {
        formData.fields.add(MapEntry('tags', tags));
      }
      if (lowStockThreshold != null && lowStockThreshold.isNotEmpty) {
        formData.fields.add(MapEntry('low_stock_threshold', lowStockThreshold));
      }

      // ── Total stock (sum of all variation stocks) ─────────────────────
      final totalStock = variations.fold<int>(
        0,
        (sum, v) => sum + ((v['stock'] as int?) ?? 0),
      );
      formData.fields.add(MapEntry('quantity', totalStock.toString()));

      // ── Variations JSON ───────────────────────────────────────────────
      if (variations.isNotEmpty) {
        formData.fields.add(MapEntry('variations', jsonEncode(variations)));
      }

      // ── Size chart JSON (mirrors web client) ─────────────────────────
      if (sizeChart != null) {
        formData.fields.add(MapEntry('size_chart', jsonEncode(sizeChart)));
      }

      // ── Images ────────────────────────────────────────────────────────
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        final fileName = multipartFilename(file.path);
        final key = i == 0 ? 'main_image' : 'additional_images';
        formData.files.add(MapEntry(
          key,
          await MultipartFile.fromFile(file.path, filename: fileName),
        ));
      }

      // ── Videos ────────────────────────────────────────────────────────
      for (final video in videoFiles) {
        final fileName = multipartFilename(video.path);
        formData.files.add(MapEntry(
          'videos',
          await MultipartFile.fromFile(video.path, filename: fileName),
        ));
      }

      final response = await dio.post(
        '/products/create',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        final msg = response.data?['msg'] ?? 'Unknown error';
        throw Exception('Failed to create product: $msg');
      }

      developer.log('Product created successfully', name: 'SellerProductsApi');
    } catch (e) {
      developer.log('Error creating product: $e', name: 'SellerProductsApi');
      rethrow;
    }
  }

  /// Update product fields (JSON body).
  static Future<void> updateProduct({
    required int productId,
    String? name,
    String? description,
    double? price,
    int? quantity,
    List<Map<String, dynamic>>? variations,
    bool? isLive,
  }) async {
    final dio = await ApiClient.getInstance();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (price != null) body['price'] = price;
    if (quantity != null) body['quantity'] = quantity;
    if (variations != null) body['variations'] = variations;
    if (isLive != null) body['is_live'] = isLive;

    final response = await dio.put('/products/edit/$productId', data: body);
    if (response.statusCode != 200) {
      throw Exception(response.data?['msg']?.toString() ?? 'Update failed');
    }
  }
}
