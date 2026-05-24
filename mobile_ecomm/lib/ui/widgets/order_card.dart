import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/order_model.dart';
import '../screens/order/order_ui_widgets.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final bool isDetailed;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.isDetailed = false,
    this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (normalizeOrderStatus(status)) {
      case 'pending':
        return Colors.orange;
      case 'processing':
      case 'preparing':
      case 'confirmed':
      case 'packed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.deepPurple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (normalizeOrderStatus(status)) {
      case 'pending':
        return Icons.schedule;
      case 'processing':
      case 'preparing':
      case 'confirmed':
      case 'packed':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'out_for_delivery':
        return Icons.delivery_dining_outlined;
      case 'delivered':
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Group items by seller
  Map<String, List<OrderItem>> _getItemsBySeller() {
    final grouped = <String, List<OrderItem>>{};
    for (final item in order.items) {
      if (!grouped.containsKey(item.sellerId)) {
        grouped[item.sellerId] = [];
      }
      grouped[item.sellerId]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(order.status);
    final totalItems = order.items.length;
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final orderNumber = order.orderNumber.isNotEmpty
        ? order.orderNumber
        : order.id.substring(0, 8).toUpperCase();
    final shopName = firstItem?.sellerName ?? order.store?.name ?? 'Shop';
    final previewText = _getPreviewText(firstItem, totalItems);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$orderNumber',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatOrderStatusLabel(order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLargeThumbnail(firstItem, isDark),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  shopName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.foreground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            previewText,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: isDark ? AppColors.darkBorder : Colors.grey[200],
                height: 1,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Total: ${FormatUtils.peso(order.total)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isDetailed && onTap != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
  }

  String _getPreviewText(OrderItem? item, int totalItems) {
    if (item == null) return 'No item details available';

    final variantParts = <String>[];
    if (item.size?.isNotEmpty ?? false) {
      variantParts.add('Size: ${item.size}');
    }
    if (item.color?.isNotEmpty ?? false) {
      variantParts.add('Color: ${item.color}');
    }

    final variantText =
        variantParts.isNotEmpty ? ' • ${variantParts.join(', ')}' : '';
    final extraItems = totalItems > 1 ? ' +${totalItems - 1} more' : '';

    return '${item.quantity}x ${item.productName}$variantText$extraItems';
  }

  Widget _buildLargeThumbnail(OrderItem? item, bool isDark) {
    final imageUrl = item?.productImage;

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkMuted : Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey, size: 28),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.grey, size: 28),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, color: Colors.grey, size: 28),
              ),
      ),
    );
  }

  Widget _buildSellerSection({
    required BuildContext context,
    required String sellerName,
    required List<OrderItem> items,
    required bool isDark,
  }) {
    final displayItems = items.take(2).toList();
    final remainingCount = items.length - 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop/Store Name Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.store_outlined,
                  color: AppColors.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sellerName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Product Images Row
          Row(
            children: [
              ...displayItems.map((item) => _buildProductThumbnail(item)),
              if (remainingCount > 0)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark ? AppColors.darkMuted : Colors.grey[200],
                  ),
                  child: Center(
                    child: Text(
                      '+$remainingCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Product Names
          Text(
            displayItems
                    .map((i) => '${i.quantity}x ${i.productName}')
                    .join(', ') +
                (remainingCount > 0 ? ' and $remainingCount more' : ''),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(OrderItem item) {
    final imageUrl = ApiClient.resolveImageUrl(item.productImage);

    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey, size: 20),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.grey, size: 20),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, color: Colors.grey, size: 20),
              ),
      ),
    );
  }
}
