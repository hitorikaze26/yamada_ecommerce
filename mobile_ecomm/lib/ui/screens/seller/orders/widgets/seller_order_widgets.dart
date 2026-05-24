import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../seller_order_status.dart';

class SellerOrderStatusBadge extends StatelessWidget {
  final String status;
  final bool isDark;

  const SellerOrderStatusBadge({
    super.key,
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: sellerOrderStatusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        sellerOrderStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: sellerOrderStatusColor(status, isDark),
        ),
      ),
    );
  }
}

class SellerOrderProductThumb extends StatelessWidget {
  final String? imageUrl;
  final bool isDark;
  final double size;

  const SellerOrderProductThumb({
    super.key,
    required this.imageUrl,
    required this.isDark,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBorder : AppColors.warmBeige,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: AppColors.mutedForeground,
              ),
            )
          : const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: AppColors.mutedForeground,
            ),
    );
  }
}

class SellerOrderSmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool isDark;

  const SellerOrderSmallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: sellerOrderAccent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class SellerOrderSectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final IconData? icon;

  const SellerOrderSectionHeader({
    super.key,
    required this.title,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: sellerOrderAccent),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}

class SellerOrderInfoCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const SellerOrderInfoCard({
    super.key,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        children: children
            .expand((w) => [w, if (w != children.last) const SizedBox(height: 8)])
            .toList(),
      ),
    );
  }
}

class SellerOrderInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool bold;

  const SellerOrderInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.isDark,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.white : AppColors.charcoal,
            ),
          ),
        ),
      ],
    );
  }
}

class SellerOrderStatChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isDark;

  static const _chipHeight = 92.0;

  const SellerOrderStatChip({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _chipHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.1,
                color: isDark ? Colors.grey[400] : AppColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
