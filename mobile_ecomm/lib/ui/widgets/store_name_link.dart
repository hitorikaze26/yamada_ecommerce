import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Tappable boutique name that opens the public store profile.
class StoreNameLink extends StatelessWidget {
  final String name;
  final String? storeId;
  final TextStyle? style;
  final int? maxLines;
  final IconData? leadingIcon;
  final double iconSize;
  /// When true, the tap target spans the full width of the parent (e.g. cart shop header).
  final bool expandWidth;

  const StoreNameLink({
    super.key,
    required this.name,
    required this.storeId,
    this.style,
    this.maxLines = 1,
    this.leadingIcon,
    this.iconSize = 16,
    this.expandWidth = false,
  });

  bool get _canNavigate => storeId != null && storeId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    if (!_canNavigate) {
      return leadingIcon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(leadingIcon, size: iconSize),
                const SizedBox(width: 6),
                Flexible(child: text),
              ],
            )
          : text;
    }

    final row = Row(
      mainAxisSize: expandWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: iconSize, color: style?.color),
          const SizedBox(width: 6),
        ],
        if (expandWidth) Expanded(child: text) else Flexible(child: text),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          size: iconSize + 2,
          color: style?.color ?? AppColors.primary,
        ),
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: row,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRouter.storePath(storeId!)),
        borderRadius: BorderRadius.circular(8),
        child: expandWidth ? SizedBox(width: double.infinity, child: content) : content,
      ),
    );
  }
}
