import '../../../core/services/api_client.dart';

/// Resolves backend image paths for chat avatars and attachment cards.
String? chatResolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.contains('placeholder.svg')) return null;
  return ApiClient.resolveImageUrl(url);
}
