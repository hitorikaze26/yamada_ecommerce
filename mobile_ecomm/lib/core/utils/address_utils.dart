import 'dart:convert';

/// Utilities for parsing and formatting shipping addresses returned by the API.
class AddressUtils {
  AddressUtils._();

  static const _addressFields = [
    'streetAddress',
    'street_address',
    'barangayName',
    'barangay_name',
    'municipalityName',
    'municipality_name',
    'provinceName',
    'province_name',
    'regionName',
    'region_name',
    'postalCode',
    'postal_code',
  ];

  static const _displayOrder = [
    'streetAddress',
    'barangayName',
    'municipalityName',
    'provinceName',
    'regionName',
    'postalCode',
  ];

  /// Formats a shipping address for display, parsing JSON/Python-dict strings.
  static String formatShippingAddress({
    String? shippingAddress,
    String? municipalityName,
  }) {
    final parsedParts = _parseAddressParts(shippingAddress);
    if (parsedParts != null) {
      final readable = _joinAddressParts(parsedParts);
      if (readable.isNotEmpty) return readable;
    }

    final cleaned = _cleanPlainText(shippingAddress);
    if (municipalityName != null && cleaned != null && cleaned.isNotEmpty) {
      if (cleaned.toLowerCase().contains(municipalityName.toLowerCase())) {
        return cleaned;
      }
      return '$municipalityName — $cleaned';
    }

    return municipalityName ?? cleaned ?? 'Customer address';
  }

  static Map<String, String>? _parseAddressParts(String? shippingAddress) {
    if (shippingAddress == null || shippingAddress.trim().isEmpty) {
      return null;
    }

    final text = shippingAddress.trim();
    if (!_looksLikeDict(text)) return null;

    final fromJson = _parseMapFromJson(text);
    if (fromJson != null) {
      return _mapToNormalizedParts(fromJson);
    }

    final parts = <String, String>{};
    for (final field in _addressFields) {
      final value = _extractField(text, field);
      if (value == null || _isEmptyValue(value)) continue;
      final normalizedKey = _normalizeFieldKey(field);
      parts.putIfAbsent(normalizedKey, () => value);
    }

    return parts.isEmpty ? null : parts;
  }

  static Map<String, dynamic>? _parseMapFromJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    try {
      final normalized = text.replaceAllMapped(
        RegExp(r"'([^']*)'"),
        (m) => '"${m.group(1)?.replaceAll('"', '\\"') ?? ''}"',
      );
      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Map<String, String> _mapToNormalizedParts(Map<String, dynamic> m) {
    final parts = <String, String>{};
    for (final field in _addressFields) {
      final raw = m[field];
      if (raw == null) continue;
      final value = raw.toString().trim();
      if (_isEmptyValue(value)) continue;
      parts[_normalizeFieldKey(field)] = value;
    }
    return parts;
  }

  static String _joinAddressParts(Map<String, String> parts) {
    final values = <String>[];
    for (final key in _displayOrder) {
      final value = parts[key];
      if (value != null && !_isEmptyValue(value)) {
        values.add(value);
      }
    }
    return values.join(', ');
  }

  static bool _looksLikeDict(String text) {
    return text.startsWith('{') && text.endsWith('}');
  }

  static String? _extractField(String source, String fieldName) {
    final pattern = RegExp(
      "['\"]?$fieldName['\"]?\\s*:\\s*['\"]([^'\"]*)['\"]",
    );
    return pattern.firstMatch(source)?.group(1)?.trim();
  }

  static String _normalizeFieldKey(String field) {
    switch (field) {
      case 'street_address':
        return 'streetAddress';
      case 'barangay_name':
        return 'barangayName';
      case 'municipality_name':
        return 'municipalityName';
      case 'province_name':
        return 'provinceName';
      case 'region_name':
        return 'regionName';
      case 'postal_code':
        return 'postalCode';
      default:
        return field;
    }
  }

  static bool _isEmptyValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'none' || normalized == 'null';
  }

  static String? _cleanPlainText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || _looksLikeDict(trimmed)) return null;
    return trimmed;
  }

  /// Label/value rows for order detail cards (seller, rider, etc.).
  static List<Map<String, String>> addressLabelRows(String? shippingAddress) {
    final parts = _parseAddressParts(shippingAddress);
    if (parts != null && parts.isNotEmpty) {
      final rows = <Map<String, String>>[];
      void add(String label, String key) {
        final v = parts[key];
        if (v != null && !_isEmptyValue(v)) {
          rows.add({'label': label, 'value': v});
        }
      }

      add('Street', 'streetAddress');
      add('Barangay', 'barangayName');
      add('City / Municipality', 'municipalityName');
      add('Province', 'provinceName');
      add('Region', 'regionName');
      add('Postal code', 'postalCode');
      if (rows.isNotEmpty) return rows;
    }

    final line = formatShippingAddress(shippingAddress: shippingAddress);
    if (line.isNotEmpty && line != 'Customer address') {
      return [{'label': 'Address', 'value': line}];
    }
    return [];
  }
}
