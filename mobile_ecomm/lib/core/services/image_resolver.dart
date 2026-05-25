import '../config/env_config.dart';

/// Centralized image URL resolver.
///
/// The backend already resolves stored paths to absolute HTTPS URLs
/// (Supabase public URLs or Flask static URLs) via `public_url_for_stored_path`.
/// This resolver handles edge cases and provides fallback logic.
class ImageResolver {
  ImageResolver._();

  /// Resolve an image URL to an absolute HTTPS URL.
  ///
  /// Resolution order:
  /// 1. null / empty → null
  /// 2. Absolute URL → pass through (Supabase public URL from backend)
  /// 3. `/static/...` → prepend API base origin (legacy local dev)
  /// 4. Relative path like `product_images/uuid.jpg` → Supabase bucket URL or fallback
  static String? resolve(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.contains('placeholder.svg') || url.contains('placeholder')) {
      return null;
    }

    final trimmed = url.trim();

    // Already absolute
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    String normalized = trimmed.replaceAll('\\', '/');

    // Legacy development /static/ path
    if (normalized.startsWith('/static/')) {
      return '${EnvConfig.baseOrigin}$normalized';
    }

    // Supabase Storage direct resolution for stored relative paths
    // Format: "product_images/uuid_1234567890.jpg"
    final storageUrl = EnvConfig.supabaseStorageUrl;
    if (storageUrl != null && storageUrl.isNotEmpty) {
      final bucket = _inferBucket(normalized);
      if (bucket != null) {
        return '$storageUrl/$bucket/$normalized';
      }
      return '$storageUrl/$normalized';
    }

    // Fallback: relative path via /static/
    if (normalized.contains('/') && !normalized.startsWith('/')) {
      return '${EnvConfig.baseOrigin}/static/$normalized';
    }

    // Simple filename — legacy fallback
    if (!normalized.startsWith('/')) {
      return '${EnvConfig.baseOrigin}/static/product_images/$normalized';
    }

    return normalized;
  }

  /// Resolve avatar URL (with cache-busting support).
  static String? resolveAvatar(String? url, {int? version}) {
    final resolved = resolve(url);
    if (resolved == null) return null;
    if (version != null && !resolved.contains('?')) {
      return '$resolved?v=$version';
    }
    return resolved;
  }

  /// Resolve product image with fallback.
  static String resolveProductImage(String? url, {String? fallback}) {
    return resolve(url) ?? fallback ?? '';
  }

  static String? _inferBucket(String path) {
    final folder = path.split('/').first;
    switch (folder) {
      case 'product_images':
      case 'product_videos':
        return 'product-images';
      case 'seller_avatars':
      case 'rider_avatars':
      case 'avatars':
      case 'seller_banners':
        return 'avatars';
      case 'chat_uploads':
        return 'chat';
      case 'buyer_ids':
      case 'seller_ids':
      case 'seller_dti':
      case 'seller_permits':
      case 'seller_bir':
      case 'rider_docs':
      case 'report_evidence':
      case 'proof_photos':
        return 'docs';
      default:
        return 'misc';
    }
  }
}
