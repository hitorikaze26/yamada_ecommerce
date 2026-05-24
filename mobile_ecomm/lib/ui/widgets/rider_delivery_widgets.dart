import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum DeliveryLocationType { pickup, dropoff }

class DeliveryStatusStyle {
  final Color background;
  final Color foreground;

  const DeliveryStatusStyle({
    required this.background,
    required this.foreground,
  });

  static DeliveryStatusStyle forStatus(String status, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    switch (status.toLowerCase()) {
      case 'pending':
        return DeliveryStatusStyle(
          background: isDark
              ? AppColors.pending.withOpacity(0.2)
              : AppColors.pendingBg,
          foreground: isDark ? AppColors.pendingTextDark : const Color(0xFFB45309),
        );
      case 'pickup':
        return DeliveryStatusStyle(
          background: isDark
              ? AppColors.processing.withOpacity(0.2)
              : AppColors.processingBg,
          foreground: isDark ? AppColors.processingTextDark : const Color(0xFF1D4ED8),
        );
      case 'transit':
        return DeliveryStatusStyle(
          background: isDark
              ? AppColors.shipped.withOpacity(0.2)
              : AppColors.shippedBg,
          foreground: isDark ? AppColors.shippedTextDark : const Color(0xFF6D28D9),
        );
      case 'delivered':
        return DeliveryStatusStyle(
          background: isDark
              ? AppColors.delivered.withOpacity(0.2)
              : AppColors.deliveredBg,
          foreground: isDark ? AppColors.deliveredTextDark : const Color(0xFF15803D),
        );
      default:
        return DeliveryStatusStyle(
          background: isDark
              ? AppColors.darkMuted
              : AppColors.muted,
          foreground: isDark
              ? AppColors.darkMutedForeground
              : AppColors.mutedForeground,
        );
    }
  }
}

class RiderDeliveryStatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const RiderDeliveryStatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final style = DeliveryStatusStyle.forStatus(
      status,
      Theme.of(context).brightness,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
  }
}

class RiderDeliveryNewBadge extends StatelessWidget {
  const RiderDeliveryNewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.pending.withOpacity(0.2)
            : AppColors.pendingBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.pending.withOpacity(isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 12,
            color: isDark ? AppColors.pendingTextDark : const Color(0xFFB45309),
          ),
          const SizedBox(width: 4),
          Text(
            'New in your area',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.pendingTextDark : const Color(0xFFB45309),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RiderDeliveryLocationBlock extends StatelessWidget {
  final DeliveryLocationType type;
  final String subtitle;
  final String? meta;
  /// When false on dropoff, use in-progress styling (not completed green).
  final bool isDeliveryComplete;

  const RiderDeliveryLocationBlock({
    super.key,
    required this.type,
    required this.subtitle,
    this.meta,
    this.isDeliveryComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPickup = type == DeliveryLocationType.pickup;

    final Color background;
    final Color borderColor;
    final Color iconBackground;
    final Color iconColor;
    final Color labelColor;

    if (isPickup) {
      background = isDark
          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.35)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.55);
      borderColor = theme.colorScheme.outline.withOpacity(0.25);
      iconBackground = theme.colorScheme.primaryContainer;
      iconColor = theme.colorScheme.primary;
      labelColor = theme.colorScheme.onSurfaceVariant;
    } else if (isDeliveryComplete) {
      background = isDark
          ? AppColors.delivered.withOpacity(0.12)
          : AppColors.deliveredBg;
      borderColor = AppColors.delivered.withOpacity(isDark ? 0.28 : 0.22);
      iconBackground = AppColors.delivered.withOpacity(isDark ? 0.22 : 0.16);
      iconColor = isDark ? AppColors.deliveredTextDark : AppColors.delivered;
      labelColor = isDark ? AppColors.deliveredTextDark : const Color(0xFF15803D);
    } else {
      background = isDark
          ? AppColors.shipped.withOpacity(0.12)
          : AppColors.shippedBg;
      borderColor = AppColors.shipped.withOpacity(isDark ? 0.28 : 0.22);
      iconBackground = AppColors.shipped.withOpacity(isDark ? 0.22 : 0.16);
      iconColor = isDark ? AppColors.shippedTextDark : AppColors.shipped;
      labelColor = isDark ? AppColors.shippedTextDark : const Color(0xFF6D28D9);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPickup ? Icons.store_outlined : Icons.location_on_outlined,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPickup ? 'PICKUP' : 'DROPOFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          meta!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

class RiderDeliveryRoute extends StatelessWidget {
  final Widget pickup;
  final Widget dropoff;

  const RiderDeliveryRoute({
    super.key,
    required this.pickup,
    required this.dropoff,
  });

  @override
  Widget build(BuildContext context) {
    final connectorColor = Theme.of(context).colorScheme.outline.withOpacity(0.35);

    return Column(
      children: [
        pickup,
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: connectorColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
        dropoff,
      ],
    );
  }
}

class RiderDeliveryFilterBar extends StatelessWidget {
  final List<String> tabs;
  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;
  final String? selectedMunicipality;
  final List<String> municipalities;
  final ValueChanged<String?> onMunicipalityChanged;

  const RiderDeliveryFilterBar({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.onTabChanged,
    required this.selectedMunicipality,
    required this.municipalities,
    required this.onMunicipalityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final isActive = activeTabIndex == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_capitalize(entry.value)),
                  selected: isActive,
                  showCheckmark: false,
                  onSelected: (_) => onTabChanged(entry.key),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? (isDark ? AppColors.navy : Colors.white)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: isDark
                      ? AppColors.darkMuted
                      : theme.colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkMuted.withOpacity(0.6)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.25),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: selectedMunicipality ?? 'all',
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              dropdownColor: theme.colorScheme.surface,
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('All areas'),
                ),
                ...municipalities.map(
                  (name) => DropdownMenuItem(
                    value: name,
                    child: Text(name),
                  ),
                ),
              ],
              onChanged: onMunicipalityChanged,
            ),
          ),
        ),
      ],
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class RiderDeliveriesEmptyState extends StatelessWidget {
  final String tabLabel;

  const RiderDeliveriesEmptyState({
    super.key,
    required this.tabLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No deliveries',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No $tabLabel deliveries at the moment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderDeliveryModal extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onClose;
  final List<Widget>? actions;

  const RiderDeliveryModal({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onClose,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.black54,
      child: GestureDetector(
        onTap: onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.25),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    child,
                    if (actions != null) ...[
                      const SizedBox(height: 24),
                      ...actions!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RiderProofPhotoPreview extends StatelessWidget {
  final String imageUrl;
  final double height;
  final bool expandWidth;

  const RiderProofPhotoPreview({
    super.key,
    required this.imageUrl,
    this.height = 120,
    this.expandWidth = true,
  });

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.defaultRadius),
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          height: height,
          width: expandWidth ? double.infinity : height,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: height,
            color: isDark ? AppColors.darkMuted : AppColors.muted,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: height,
            padding: const EdgeInsets.all(12),
            color: isDark ? AppColors.darkMuted : AppColors.muted,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  'Photo unavailable',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RiderProofOfDeliverySection extends StatelessWidget {
  final String? photoUrl;
  final String? note;

  const RiderProofOfDeliverySection({
    super.key,
    this.photoUrl,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null && (note == null || note!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.processing.withOpacity(0.12)
            : AppColors.processingBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.processing.withOpacity(isDark ? 0.28 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.processing.withOpacity(isDark ? 0.22 : 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 16,
                  color: isDark
                      ? AppColors.processingTextDark
                      : AppColors.processing,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Proof of delivery',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.processingTextDark
                      : const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          if (photoUrl != null) ...[
            const SizedBox(height: 10),
            RiderProofPhotoPreview(imageUrl: photoUrl!),
          ],
          if (note != null && note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RiderHistoryEmptyState extends StatelessWidget {
  const RiderHistoryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No history yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed deliveries will appear here once you start delivering.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class RiderVerificationNotice extends StatelessWidget {
  const RiderVerificationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.pending.withOpacity(0.12)
            : AppColors.pendingBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.pending.withOpacity(isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDark ? AppColors.pendingTextDark : const Color(0xFFB45309),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Account awaiting approval',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.pendingTextDark : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your rider account is not yet verified. Completed deliveries will appear here once an admin approves your account.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

