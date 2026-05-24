import 'package:flutter/material.dart';
import '../seller_analytics_constants.dart';

class AnalyticsTimeRangeBar extends StatelessWidget {
  final String timeRange;
  final bool isLoading;
  final bool isDownloading;
  final ValueChanged<String> onRangeSelected;
  final VoidCallback onDownload;

  const AnalyticsTimeRangeBar({
    super.key,
    required this.timeRange,
    required this.isLoading,
    required this.isDownloading,
    required this.onRangeSelected,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SellerAnalyticsConstants.timeRanges.map((range) {
            final selected = timeRange == range.key;
            return FilterChip(
              label: Text(range.label),
              selected: selected,
              showCheckmark: false,
              onSelected: isLoading ? null : (_) => onRangeSelected(range.key),
              selectedColor:
                  SellerAnalyticsConstants.accent.withValues(alpha: 0.18),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? SellerAnalyticsConstants.accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              side: BorderSide(
                color: selected
                    ? SellerAnalyticsConstants.accent
                    : Theme.of(context).dividerColor,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLoading || isDownloading ? null : onDownload,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: isDownloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 20),
          label: Text(isDownloading ? 'Downloading…' : 'Download PDF Report'),
        ),
      ],
    );
  }
}
