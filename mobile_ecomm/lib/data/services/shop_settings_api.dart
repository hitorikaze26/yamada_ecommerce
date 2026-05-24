import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/utils/file_utils.dart';

/// Shop Settings API — mirrors the web client's sellerShopApi
class ShopSettingsApi {
  // ── Load all settings in one call ────────────────────────────────────────

  static Future<Map<String, dynamic>> getAllSettings() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/seller/settings/all');
    return (res.data['settings'] as Map<String, dynamic>?) ?? {};
  }

  // ── Seller profile (shop name, tagline, description) ─────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/accounts/seller/profile');
    return (res.data['profile'] as Map<String, dynamic>?) ?? {};
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    await dio.put('/accounts/seller/profile', data: data);
  }

  /// Shop profile photo (store logo) — POST /accounts/seller/avatar
  static Future<String> uploadSellerAvatar(File file) async {
    final dio = await ApiClient.getInstance();
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        file.path,
        filename: multipartFilename(file.path),
      ),
    });
    final res = await dio.post(
      '/accounts/seller/avatar',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data['avatarUrl']?.toString() ?? '';
  }

  /// Storefront banner — POST /accounts/seller/banner
  static Future<String> uploadSellerBanner(File file) async {
    final dio = await ApiClient.getInstance();
    final formData = FormData.fromMap({
      'banner': await MultipartFile.fromFile(
        file.path,
        filename: multipartFilename(file.path),
      ),
    });
    final res = await dio.post(
      '/accounts/seller/banner',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data['bannerUrl']?.toString() ?? '';
  }

  // ── Shipping ──────────────────────────────────────────────────────────────

  static Future<void> createShipping(Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/seller/settings/shipping', data: data);
  }

  static Future<void> updateShipping(int id, Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    await dio.put('/seller/settings/shipping/$id', data: data);
  }

  static Future<void> deleteShipping(int id) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('/seller/settings/shipping/$id');
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  static Future<void> updatePayment({required bool codEnabled}) async {
    final dio = await ApiClient.getInstance();
    await dio.put('/seller/settings/payment', data: {'codEnabled': codEnabled});
  }

  // ── Order ─────────────────────────────────────────────────────────────────

  static Future<void> updateOrder(Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    await dio.put('/seller/settings/order', data: data);
  }

  // ── Customization ─────────────────────────────────────────────────────────

  static Future<void> updateCustomization(Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    await dio.put('/seller/settings/customization', data: data);
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  static Future<void> updateChat(Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    await dio.put('/seller/settings/chat', data: data);
  }
}
