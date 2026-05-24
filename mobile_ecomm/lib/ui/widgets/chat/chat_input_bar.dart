import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/chat_message_model.dart';
import '../../../data/models/pending_order_share.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/chat_notifier.dart';
import '../../../data/services/chat_api.dart';
import 'chat_actions_sheet.dart';
import 'chat_image_url.dart';
import 'chat_theme.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final int conversationId;
  final bool isDark;
  final int? storeId;

  const ChatInputBar({
    super.key,
    required this.conversationId,
    required this.isDark,
    this.storeId,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  UserRole? get _role => ref.read(authProvider).user?.role;

  bool get _showProduct {
    final r = _role;
    return r == UserRole.buyer || r == UserRole.seller;
  }

  bool get _showOrder {
    final r = _role;
    return r == UserRole.buyer || r == UserRole.seller || r == UserRole.rider;
  }

  Future<void> _send() async {
    final text = _controller.text;
    final thread = ref.read(chatThreadProvider(widget.conversationId));
    final hasText = text.trim().isNotEmpty;
    final hasPendingOrder = thread.pendingOrderShare != null;
    if (!hasText && !hasPendingOrder) return;

    _controller.clear();
    final notifier = ref.read(chatProvider.notifier);
    if (hasText) {
      await notifier.sendText(widget.conversationId, text);
    }
    if (hasPendingOrder) {
      await notifier.sendPendingOrderShare(widget.conversationId);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    await ref
        .read(chatProvider.notifier)
        .uploadAndSend(widget.conversationId, File(picked.path));
  }

  Future<void> _shareProduct() async {
    final items = await ChatApi.shareProducts(storeId: widget.storeId);
    if (!mounted || items.isEmpty) return;
    final picked = await showModalBottomSheet<ShareProductItem>(
      context: context,
      backgroundColor: ChatTheme.cardBg(widget.isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PickerSheet(
        title: 'Share product',
        isDark: widget.isDark,
        children: items
            .map(
              (p) => _ShareProductPickerTile(
                product: p,
                isDark: widget.isDark,
                onTap: () => Navigator.pop(ctx, p),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null) return;
    await ref.read(chatProvider.notifier).sendRich(
          widget.conversationId,
          messageType: 'product',
          metadata: {'productId': picked.id},
        );
  }

  Future<void> _shareOrder() async {
    final items = await ChatApi.shareOrders();
    if (!mounted || items.isEmpty) return;
    final picked = await showModalBottomSheet<ShareOrderItem>(
      context: context,
      backgroundColor: ChatTheme.cardBg(widget.isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PickerSheet(
        title: 'Share order',
        isDark: widget.isDark,
        children: items
            .map(
              (o) => _ShareOrderPickerTile(
                order: o,
                isDark: widget.isDark,
                onTap: () => Navigator.pop(ctx, o),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null) return;
    await ref.read(chatProvider.notifier).sendRich(
          widget.conversationId,
          messageType: 'order',
          metadata: {'orderId': picked.orderId},
        );
  }

  void _openMoreActions() {
    ChatInputActionsSheet.show(
      context,
      isDark: widget.isDark,
      showProduct: _showProduct,
      showOrder: _showOrder,
      onAttach: _pickImage,
      onShareProduct: _showProduct ? _shareProduct : null,
      onShareOrder: _showOrder ? _shareOrder : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(widget.isDark);
    final thread = ref.watch(chatThreadProvider(widget.conversationId));
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 8),
      decoration: BoxDecoration(
        color: p.inputBarBg,
        border: Border(top: BorderSide(color: p.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thread.replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: p.accent, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying: ${thread.replyTo!.body}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p.caption(context).copyWith(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: p.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => ref
                        .read(chatProvider.notifier)
                        .setReplyTo(widget.conversationId, null),
                  ),
                ],
              ),
            ),
          if (thread.pendingOrderShare != null)
            _PendingOrderShareStrip(
              pending: thread.pendingOrderShare!,
              isDark: widget.isDark,
              onClear: () => ref
                  .read(chatProvider.notifier)
                  .clearPendingOrderShare(widget.conversationId),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.more_horiz_rounded, color: p.accent),
                tooltip: 'More',
                onPressed: _openMoreActions,
              ),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: p.inputFieldBg,
                    borderRadius:
                        BorderRadius.circular(ChatTheme.inputRadius),
                    border: Border.all(
                      color: _focused ? p.accent : p.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: p.bodyMedium(context).copyWith(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Write a message…',
                      hintStyle: TextStyle(color: p.textHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: p.accent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: thread.isSending ? null : _send,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: thread.isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingOrderShareStrip extends StatelessWidget {
  final PendingOrderShare pending;
  final bool isDark;
  final VoidCallback onClear;

  const _PendingOrderShareStrip({
    required this.pending,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final imageUrl = chatResolveImageUrl(pending.productImageUrl);
    final status = pending.status.toString().replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _icon(p),
              ),
            )
          else
            _icon(p),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order to share',
                  style: p.caption(context).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  pending.previewLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.bodyMedium(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: p.caption(context).copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: p.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }

  Widget _icon(ChatPalette p) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.receipt_long_outlined, color: p.accent, size: 20),
    );
  }
}

class _ShareProductPickerTile extends StatelessWidget {
  final ShareProductItem product;
  final bool isDark;
  final VoidCallback onTap;

  const _ShareProductPickerTile({
    required this.product,
    required this.isDark,
    required this.onTap,
  });

  String get _title {
    final name = product.name.trim();
    return name.isNotEmpty ? name : 'Product';
  }

  String get _subtitle {
    return '₱${product.price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final imageUrl = chatResolveImageUrl(product.imageUrl);

    return ListTile(
      leading: _SharePickerThumb(
        palette: p,
        imageUrl: imageUrl,
        icon: Icons.shopping_bag_outlined,
      ),
      title: Text(
        _title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: p.bodyMedium(context).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_subtitle, style: p.caption(context)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ShareOrderPickerTile extends StatelessWidget {
  final ShareOrderItem order;
  final bool isDark;
  final VoidCallback onTap;

  const _ShareOrderPickerTile({
    required this.order,
    required this.isDark,
    required this.onTap,
  });

  String get _title {
    final name = order.productName.trim();
    return name.isNotEmpty ? name : 'Order #${order.orderNumber}';
  }

  String get _subtitle {
    final status = order.status.replaceAll('_', ' ');
    if (order.totalAmount > 0) {
      return '$status · ₱${order.totalAmount.toStringAsFixed(2)}';
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final imageUrl = chatResolveImageUrl(order.productImageUrl);

    return ListTile(
      leading: _SharePickerThumb(
        palette: p,
        imageUrl: imageUrl,
        icon: Icons.receipt_long_outlined,
      ),
      title: Text(
        _title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: p.bodyMedium(context).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_subtitle, style: p.caption(context)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SharePickerThumb extends StatelessWidget {
  final ChatPalette palette;
  final String? imageUrl;
  final IconData icon;

  const _SharePickerThumb({
    required this.palette,
    required this.imageUrl,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: palette.accent, size: 22),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final bool isDark;
  final List<Widget> children;

  const _PickerSheet({
    required this.title,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(title, style: p.titleMedium(context)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(shrinkWrap: true, children: children),
          ),
        ],
      ),
    );
  }
}
