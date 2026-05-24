import 'dart:convert';
import '../services/ph_geo_api.dart';

/// Address data model matching Next.js client AddressData
class AddressData {
  final String regionCode;
  final String regionName;
  final String provinceCode;
  final String provinceName;
  final String municipalityCode;
  final String municipalityName;
  final String barangayCode;
  final String barangayName;
  final String? streetAddress;
  final String? postalCode;

  AddressData({
    required this.regionCode,
    required this.regionName,
    required this.provinceCode,
    required this.provinceName,
    required this.municipalityCode,
    required this.municipalityName,
    required this.barangayCode,
    required this.barangayName,
    this.streetAddress,
    this.postalCode,
  });

  /// Create from JSON
  factory AddressData.fromJson(Map<String, dynamic> json) {
    return AddressData(
      regionCode: json['regionCode'] ?? '',
      regionName: json['regionName'] ?? '',
      provinceCode: json['provinceCode'] ?? '',
      provinceName: json['provinceName'] ?? '',
      municipalityCode: json['municipalityCode'] ?? '',
      municipalityName: json['municipalityName'] ?? '',
      barangayCode: json['barangayCode'] ?? '',
      barangayName: json['barangayName'] ?? '',
      streetAddress: json['streetAddress'],
      postalCode: json['postalCode'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'regionCode': regionCode,
      'regionName': regionName,
      'provinceCode': provinceCode,
      'provinceName': provinceName,
      'municipalityCode': municipalityCode,
      'municipalityName': municipalityName,
      'barangayCode': barangayCode,
      'barangayName': barangayName,
      'streetAddress': streetAddress,
      'postalCode': postalCode,
    };
  }

  /// Convert to JSON string for FormData
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Check if address is complete (province optional for NCR).
  bool get isComplete {
    final needsProvince = !isNCRRegion(regionCode);
    return regionCode.isNotEmpty &&
        municipalityCode.isNotEmpty &&
        barangayCode.isNotEmpty &&
        (!needsProvince || provinceCode.isNotEmpty);
  }

  /// Get formatted address string
  String get formattedAddress {
    final showProvince = provinceName.isNotEmpty &&
        !provinceName.toLowerCase().contains('n/a');
    final parts = <String>[
      if (streetAddress?.isNotEmpty == true) streetAddress!,
      barangayName,
      municipalityName,
      if (showProvince) provinceName,
      regionName,
      if (postalCode?.isNotEmpty == true) postalCode!,
    ];
    return parts.where((p) => p.isNotEmpty).join(', ');
  }

  /// Create a copy with updated fields
  AddressData copyWith({
    String? regionCode,
    String? regionName,
    String? provinceCode,
    String? provinceName,
    String? municipalityCode,
    String? municipalityName,
    String? barangayCode,
    String? barangayName,
    String? streetAddress,
    String? postalCode,
  }) {
    return AddressData(
      regionCode: regionCode ?? this.regionCode,
      regionName: regionName ?? this.regionName,
      provinceCode: provinceCode ?? this.provinceCode,
      provinceName: provinceName ?? this.provinceName,
      municipalityCode: municipalityCode ?? this.municipalityCode,
      municipalityName: municipalityName ?? this.municipalityName,
      barangayCode: barangayCode ?? this.barangayCode,
      barangayName: barangayName ?? this.barangayName,
      streetAddress: streetAddress ?? this.streetAddress,
      postalCode: postalCode ?? this.postalCode,
    );
  }
}
