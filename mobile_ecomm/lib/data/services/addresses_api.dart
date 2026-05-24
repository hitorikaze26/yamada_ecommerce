import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../models/address_model.dart';
import 'auth_api.dart';

/// Saved Address model with ID and label
class SavedAddress {
  final String id;
  final String label;
  final AddressData addressData;
  final bool isDefault;
  final DateTime? createdAt;

  SavedAddress({
    required this.id,
    required this.label,
    required this.addressData,
    this.isDefault = false,
    this.createdAt,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    // Server returns flat structure with all address fields directly in the response
    return SavedAddress(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Address',
      addressData: AddressData(
        regionCode: json['regionCode']?.toString() ?? '',
        regionName: json['regionName']?.toString() ?? '',
        provinceCode: json['provinceCode']?.toString() ?? '',
        provinceName: json['provinceName']?.toString() ?? '',
        municipalityCode: json['municipalityCode']?.toString() ?? '',
        municipalityName: json['municipalityName']?.toString() ?? '',
        barangayCode: json['barangayCode']?.toString() ?? '',
        barangayName: json['barangayName']?.toString() ?? '',
        streetAddress: json['streetAddress']?.toString(),
        postalCode: json['postalCode']?.toString(),
      ),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    // Server expects flat structure with all address fields
    return {
      'id': id,
      'label': label,
      'regionCode': addressData.regionCode,
      'regionName': addressData.regionName,
      'provinceCode': addressData.provinceCode,
      'provinceName': addressData.provinceName,
      'municipalityCode': addressData.municipalityCode,
      'municipalityName': addressData.municipalityName,
      'barangayCode': addressData.barangayCode,
      'barangayName': addressData.barangayName,
      'streetAddress': addressData.streetAddress,
      'postalCode': addressData.postalCode,
      'isDefault': isDefault,
    };
  }
}

/// Addresses API Service
/// Manages user's saved addresses
class AddressesApi {
  /// Build a display-only address from buyer profile registration data.
  static SavedAddress? fromProfileAddress(Map<String, dynamic> address) {
    final regionName = address['regionName']?.toString() ?? '';
    if (regionName.isEmpty) return null;
    return SavedAddress(
      id: 'profile',
      label: 'Home',
      addressData: AddressData(
        regionCode: address['regionCode']?.toString() ?? '',
        regionName: regionName,
        provinceCode: address['provinceCode']?.toString() ?? '',
        provinceName: address['provinceName']?.toString() ?? '',
        municipalityCode: address['municipalityCode']?.toString() ?? '',
        municipalityName: address['municipalityName']?.toString() ?? '',
        barangayCode: address['barangayCode']?.toString() ?? '',
        barangayName: address['barangayName']?.toString() ?? '',
        streetAddress: address['streetAddress']?.toString(),
        postalCode: address['postalCode']?.toString(),
      ),
      isDefault: true,
    );
  }

  /// Fetch saved addresses; fall back to registration profile address when empty.
  static Future<List<SavedAddress>> loadAddresses() async {
    final list = await getAddresses();
    if (list.isNotEmpty) return list;

    try {
      final profile = await AuthApi.getBuyerProfile();
      final address = profile['address'] as Map<String, dynamic>?;
      if (address == null) return [];
      final fromProfile = fromProfileAddress(address);
      return fromProfile != null ? [fromProfile] : [];
    } catch (e) {
      developer.log('Profile address fallback failed: $e', name: 'AddressesApi');
      return [];
    }
  }

  /// Fetch all saved addresses for the current user
  static Future<List<SavedAddress>> getAddresses() async {
    try {
      final dio = await ApiClient.getInstance();
      developer.log('GET /user/addresses', name: 'AddressesApi');
      final response = await dio.get('/user/addresses');

      developer.log('Response status: ${response.statusCode}', name: 'AddressesApi');
      developer.log('Response data: ${response.data}', name: 'AddressesApi');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> addresses = data['addresses'] ?? [];
        developer.log('Parsed ${addresses.length} addresses from response', name: 'AddressesApi');
        return addresses.map((a) => SavedAddress.fromJson(a as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e, stackTrace) {
      developer.log('Error fetching addresses: $e', name: 'AddressesApi', error: e, stackTrace: stackTrace);
      if (e is DioException) {
        final status = e.response?.statusCode;
        // Let loadAddresses() fall back to buyer profile when the server errors.
        if (status != null && status >= 500) return [];
        final data = e.response?.data;
        final msg = data is Map
            ? (data['msg'] ?? data['error'])?.toString()
            : null;
        throw Exception(msg ?? 'Failed to load addresses');
      }
      rethrow;
    }
  }

  /// Add a new address
  static Future<SavedAddress?> addAddress({
    required String label,
    required AddressData addressData,
    bool isDefault = false,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post('/user/addresses', data: {
        'label': label,
        'isDefault': isDefault,
        ...addressData.toJson(),
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        return SavedAddress.fromJson(response.data);
      }
      return null;
    } catch (e) {
      developer.log('Error adding address: $e', name: 'AddressesApi');
      return null;
    }
  }

  /// Update an existing address
  static Future<SavedAddress?> updateAddress({
    required String id,
    String? label,
    AddressData? addressData,
    bool? isDefault,
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      final data = <String, dynamic>{};
      if (label != null) data['label'] = label;
      if (addressData != null) data.addAll(addressData.toJson());
      if (isDefault != null) data['isDefault'] = isDefault;

      final response = await dio.put('/user/addresses/$id', data: data);

      if (response.statusCode == 200) {
        return SavedAddress.fromJson(response.data);
      }
      return null;
    } catch (e) {
      developer.log('Error updating address: $e', name: 'AddressesApi');
      return null;
    }
  }

  /// Delete an address
  static Future<bool> deleteAddress(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.delete('/user/addresses/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      developer.log('Error deleting address: $e', name: 'AddressesApi');
      return false;
    }
  }

  /// Set an address as default
  static Future<bool> setDefaultAddress(String id) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.patch('/user/addresses/$id/default');
      return response.statusCode == 200;
    } catch (e) {
      developer.log('Error setting default address: $e', name: 'AddressesApi');
      return false;
    }
  }
}
