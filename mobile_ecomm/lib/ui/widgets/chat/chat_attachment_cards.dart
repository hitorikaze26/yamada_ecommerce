import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message_model.dart';
import 'chat_image_url.dart';
import 'chat_theme.dart';

class ChatProductCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final bool isDark;

  const ChatProductCard({super.key, required this.meta, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final name = meta['name']?.toString() ?? 'Product';
    final price = (meta['price'] as num?)?.toDouble() ?? 0;
    final image = chatResolveImageUrl(meta['imageUrl']?.toString());

    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Row(
        children: [
          _Thumb(imageUrl: image, isDark: isDark, icon: Icons.shopping_bag_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product',
                  style: p.caption(context).copyWith(
                        fontSize: 10,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: p.bodyMedium(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatOrderCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final bool isDark;

  const ChatOrderCard({super.key, required this.meta, required this.isDark});

  String _formatStatus(String raw) {
    return raw.replaceAll('_', ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final product = meta['productName']?.toString().trim() ?? '';
    final title = product.isNotEmpty ? product : 'Order';
    final status = _formatStatus(meta['status']?.toString() ?? '');
    final total = (meta['totalAmount'] as num?)?.toDouble();
    final image = chatResolveImageUrl(
      meta['productImageUrl']?.toString() ?? meta['imageUrl']?.toString(),
    );

    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(imageUrl: image, isDark: isDark, icon: Icons.receipt_long_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shared order',
                  style: p.caption(context).copyWith(
                        fontSize: 10,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: p.titleMedium(context).copyWith(fontSize: 13),
                ),
                if (total != null && total > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '₱${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                ],
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lilac.withValues(alpha: isDark ? 0.25 : 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;
  final bool isDark;
  final IconData icon;

  const _Thumb({
    required this.imageUrl,
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    const size = 52.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(p, size),
              errorWidget: (_, __, ___) => _placeholder(p, size),
            )
          : _placeholder(p, size),
    );
  }

  Widget _placeholder(ChatPalette p, double size) {
    return Container(
      width: size,
      height: size,
      color: p.surfaceMuted,
      child: Icon(icon, color: p.accent, size: 24),
    );
  }
}

class ChatImageCard extends StatelessWidget {
  final ChatMessageModel message;

  const ChatImageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final url = chatResolveImageUrl(
      message.metadata['fileUrl']?.toString() ??
          message.metadata['url']?.toString(),
    );
    if (url == null || url.isEmpty) {
      return const Icon(Icons.image_outlined, size: 120);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 200,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox(
          width: 200,
          height: 140,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, size: 48),
      ),
    );
  }
}
