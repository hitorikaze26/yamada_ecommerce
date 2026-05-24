import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'chat_theme.dart';

/// Bottom sheet for extra chat input actions (attach, product, order).
class ChatInputActionsSheet extends StatelessWidget {
  final bool isDark;
  final bool showProduct;
  final bool showOrder;
  final VoidCallback onAttach;
  final VoidCallback? onShareProduct;
  final VoidCallback? onShareOrder;

  const ChatInputActionsSheet({
    super.key,
    required this.isDark,
    required this.showProduct,
    required this.showOrder,
    required this.onAttach,
    this.onShareProduct,
    this.onShareOrder,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isDark,
    required bool showProduct,
    required bool showOrder,
    required VoidCallback onAttach,
    VoidCallback? onShareProduct,
    VoidCallback? onShareOrder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: ChatTheme.cardBg(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChatInputActionsSheet(
        isDark: isDark,
        showProduct: showProduct,
        showOrder: showOrder,
        onAttach: () {
          Navigator.pop(ctx);
          onAttach();
        },
        onShareProduct: onShareProduct == null
            ? null
            : () {
                Navigator.pop(ctx);
                onShareProduct();
              },
        onShareOrder: onShareOrder == null
            ? null
            : () {
                Navigator.pop(ctx);
                onShareOrder();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.warmGray.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'More options',
              style: ChatPalette(isDark).titleMedium(context),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.image_outlined,
              label: 'Photo',
              subtitle: 'Attach from gallery',
              isDark: isDark,
              onTap: onAttach,
            ),
            if (showProduct && onShareProduct != null)
              _ActionTile(
                icon: Icons.local_offer_outlined,
                label: 'Share product',
                subtitle: 'Send a boutique item',
                isDark: isDark,
                onTap: onShareProduct!,
              ),
            if (showOrder && onShareOrder != null)
              _ActionTile(
                icon: Icons.receipt_long_outlined,
                label: 'Share order',
                subtitle: 'Send order details',
                isDark: isDark,
                onTap: onShareOrder!,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: p.accent),
      ),
      title: Text(
        label,
        style: p.titleMedium(context).copyWith(fontSize: 15),
      ),
      subtitle: Text(subtitle, style: p.caption(context)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

/// List tile overflow menu: archive / delete.
class ChatConversationListMenuSheet extends StatelessWidget {
  final bool isDark;
  final bool isArchived;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const ChatConversationListMenuSheet({
    super.key,
    required this.isDark,
    required this.isArchived,
    required this.onArchive,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isDark,
    required bool isArchived,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: ChatTheme.cardBg(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChatConversationListMenuSheet(
        isDark: isDark,
        isArchived: isArchived,
        onArchive: () {
          Navigator.pop(ctx);
          onArchive();
        },
        onDelete: () {
          Navigator.pop(ctx);
          onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.warmGray.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              label: isArchived ? 'Unarchive' : 'Archive',
              subtitle: isArchived
                  ? 'Move back to your inbox'
                  : 'Hide from your inbox',
              isDark: isDark,
              onTap: onArchive,
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              subtitle: 'Remove from your messages',
              isDark: isDark,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Thread header overflow menu: archive / delete.
class ChatThreadMenuSheet extends StatelessWidget {
  final bool isDark;
  final bool isArchived;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const ChatThreadMenuSheet({
    super.key,
    required this.isDark,
    required this.isArchived,
    required this.onArchive,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isDark,
    required bool isArchived,
    required VoidCallback onArchive,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: ChatTheme.cardBg(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChatThreadMenuSheet(
        isDark: isDark,
        isArchived: isArchived,
        onArchive: () {
          Navigator.pop(ctx);
          onArchive();
        },
        onDelete: () {
          Navigator.pop(ctx);
          onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.warmGray.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              label: isArchived ? 'Unarchive' : 'Archive',
              subtitle: isArchived
                  ? 'Move back to your inbox'
                  : 'Hide from inbox, keep messages',
              isDark: isDark,
              onTap: onArchive,
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              subtitle: 'Remove from your messages',
              isDark: isDark,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
