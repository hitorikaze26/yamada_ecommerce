import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// NCR region codes — NCR has no provinces; cities are under the region.
const ncrRegionCodes = [
  '13',
  '130000000',
  '1300000000',
  'NCR',
  'Metro Manila',
  'National Capital Region',
];

bool isNCRRegion(String? regionCode) {
  if (regionCode == null || regionCode.trim().isEmpty) return false;
  final normalized = regionCode.trim();
  return ncrRegionCodes.any(
    (code) => normalized == code || normalized.startsWith(code),
  );
}

String normalizePsgcCode(String code) {
  var normalized = code.trim();
  if (normalized.length > 9) {
    normalized = normalized.substring(0, 9);
  } else if (normalized.length < 9) {
    normalized = normalized.padRight(9, '0');
  }
  return normalized;
}

/// Philippine Geographic API Service
/// Uses PSGC (Philippine Standard Geographic Code) API
/// Maps to Next.js client phGeoApi
class PhGeoApi {
  static Dio? _dio;
  
  static Dio get _dioInstance {
    if (_dio != null) return _dio!;
    
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );
    
    // Add logging interceptor for debugging
    _dio!.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (object) => developer.log(object.toString(), name: 'PhGeoApi.Dio'),
    ));
    
    return _dio!;
  }

  static String get _baseUrl {
    // Fallback to PSGC API if env variable not set
    final url = dotenv.env['PH_SGG_BASE_URL'];
    if (url != null && url.isNotEmpty) {
      developer.log('Using PH_SGG_BASE_URL from env: $url', name: 'PhGeoApi');
      return url;
    }
    developer.log('Using default PSGC API URL', name: 'PhGeoApi');
    return 'https://psgc.gitlab.io/api';
  }

  /// Get all regions
  static Future<List<Map<String, dynamic>>> getRegions() async {
    final url = '$_baseUrl/regions';
    developer.log('Fetching regions from: $url', name: 'PhGeoApi');
    try {
      final response = await _dioInstance.get(url);
      developer.log('Regions response type: ${response.data.runtimeType}', name: 'PhGeoApi');
      
      // Handle different response formats
      dynamic data = response.data;
      if (data is String) {
        // API returns JSON as String - parse it
        data = jsonDecode(data);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      throw Exception('Unexpected response format: ${data.runtimeType}');
    } on DioException catch (e) {
      developer.log('DioException: ${e.type} - ${e.message}', name: 'PhGeoApi', error: e);
      throw Exception('Failed to load regions. Check your connection and try again.');
    } catch (e) {
      developer.log('Unexpected error: $e', name: 'PhGeoApi', error: e);
      throw Exception('Failed to load regions: $e');
    }
  }

  /// Get provinces for a region (empty for NCR).
  static Future<List<Map<String, dynamic>>> getProvinces(String regionCode) async {
    if (isNCRRegion(regionCode)) {
      developer.log('NCR selected — no provinces', name: 'PhGeoApi');
      return [];
    }
    developer.log('Fetching provinces for region: $regionCode', name: 'PhGeoApi');
    try {
      final response = await _dioInstance.get(
        '$_baseUrl/regions/${normalizePsgcCode(regionCode)}/provinces',
      );
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      throw Exception('Unexpected format: ${data.runtimeType}');
    } on DioException catch (e) {
      throw Exception('Failed to load provinces: ${e.message}');
    }
  }

  /// Cities/municipalities for NCR — loaded directly from region (no province).
  static Future<List<Map<String, dynamic>>> getMunicipalitiesByRegion(
    String regionCode,
  ) async {
    final code = normalizePsgcCode(regionCode);
    developer.log('Fetching NCR cities for region: $code', name: 'PhGeoApi');
    try {
      final response = await _dioInstance.get(
        '$_baseUrl/regions/$code/cities-municipalities',
      );
      dynamic data = response.data;
      if (data is Map && data['value'] is List) {
        data = data['value'];
      }
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      throw Exception('Unexpected format: ${data.runtimeType}');
    } on DioException catch (e) {
      developer.log('NCR cities fetch failed, using fallback: $e', name: 'PhGeoApi');
      return _fallbackNcrCities;
    }
  }

  static const _fallbackNcrCities = [
    {'code': '137400000', 'name': 'Caloocan City'},
    {'code': '137500000', 'name': 'Las Piñas City'},
    {'code': '137600000', 'name': 'Makati City'},
    {'code': '137700000', 'name': 'Malabon City'},
    {'code': '137800000', 'name': 'Mandaluyong City'},
    {'code': '137900000', 'name': 'Manila City'},
    {'code': '138000000', 'name': 'Marikina City'},
    {'code': '138100000', 'name': 'Muntinlupa City'},
    {'code': '138200000', 'name': 'Navotas City'},
    {'code': '138300000', 'name': 'Parañaque City'},
    {'code': '138400000', 'name': 'Pasay City'},
    {'code': '138500000', 'name': 'Pasig City'},
    {'code': '138600000', 'name': 'Pateros Municipality'},
    {'code': '138700000', 'name': 'Quezon City'},
    {'code': '138800000', 'name': 'San Juan City'},
    {'code': '138900000', 'name': 'Taguig City'},
    {'code': '139000000', 'name': 'Valenzuela City'},
  ];

  /// Get municipalities/cities for a province (non-NCR).
  static Future<List<Map<String, dynamic>>> getMunicipalities(
    String provinceCode,
  ) async {
    developer.log('Fetching municipalities for province: $provinceCode', name: 'PhGeoApi');
    try {
      final response = await _dioInstance.get(
        '$_baseUrl/provinces/$provinceCode/cities-municipalities',
      );
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      throw Exception('Unexpected format: ${data.runtimeType}');
    } on DioException catch (e) {
      throw Exception('Failed to load municipalities: ${e.message}');
    }
  }

  /// Get barangays for a municipality
  static Future<List<Map<String, dynamic>>> getBarangays(String municipalityCode) async {
    developer.log('Fetching barangays for municipality: $municipalityCode', name: 'PhGeoApi');
    try {
      final response = await _dioInstance.get(
        '$_baseUrl/cities-municipalities/$municipalityCode/barangays',
      );
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      throw Exception('Unexpected format: ${data.runtimeType}');
    } on DioException catch (e) {
      throw Exception('Failed to load barangays: ${e.message}');
    }
  }
}

/// Region data model
class Region {
  final String code;
  final String name;
  final String? regionName;

  Region({
    required this.code,
    required this.name,
    this.regionName,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      regionName: json['regionName']?.toString(),
    );
  }

  String get displayName => regionName ?? name;
}

/// Province data model
class Province {
  final String code;
  final String name;

  Province({
    required this.code,
    required this.name,
  });

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Municipality/City data model
class Municipality {
  final String code;
  final String name;

  Municipality({
    required this.code,
    required this.name,
  });

  factory Municipality.fromJson(Map<String, dynamic> json) {
    return Municipality(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Barangay data model
class Barangay {
  final String code;
  final String name;

  Barangay({
    required this.code,
    required this.name,
  });

  factory Barangay.fromJson(Map<String, dynamic> json) {
    return Barangay(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
