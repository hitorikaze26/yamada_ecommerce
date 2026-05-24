import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../data/models/chat_message_model.dart';
import 'chat_attachment_cards.dart';
import 'chat_theme.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isDark;
  final ChatMessageModel? replyTo;
  final VoidCallback? onReply;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isDark,
    this.replyTo,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    final align = message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final time = message.createdAt != null
        ? DateFormat('h:mm a').format(message.createdAt!.toLocal())
        : '';
    final textColor = ChatTheme.bubbleTextColor(
      senderRole: message.senderRole,
      isMine: message.isMine,
      isDark: isDark,
    );

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: onReply,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (replyTo != null) _replyStrip(replyTo!, p),
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: ChatTheme.bubbleDecoration(
                  senderRole: message.senderRole,
                  isMine: message.isMine,
                  isDark: isDark,
                ),
                child: _content(isDark, textColor),
              )
                  .animate()
                  .fadeIn(duration: 220.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: p.caption(context).copyWith(fontSize: 10)),
                  if (message.isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: p.accent.withValues(alpha: 0.85),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyStrip(ChatMessageModel reply, ChatPalette p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: p.accent, width: 3)),
      ),
      child: Text(
        reply.body.isNotEmpty ? reply.body : _typeLabel(reply.messageType),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: p.textSecondary, height: 1.3),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'product':
        return 'Product';
      case 'order':
        return 'Order';
      case 'image':
        return 'Photo';
      default:
        return 'Message';
    }
  }

  Widget _content(bool isDark, Color textColor) {
    switch (message.messageType) {
      case 'product':
        return ChatProductCard(meta: message.metadata, isDark: isDark);
      case 'order':
        return ChatOrderCard(meta: message.metadata, isDark: isDark);
      case 'image':
        return ChatImageCard(message: message);
      case 'file':
        final p = ChatPalette(isDark);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, color: p.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.metadata['fileName']?.toString() ?? message.body,
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        );
      default:
        return Text(
          message.body,
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: textColor,
          ),
        );
    }
  }
}
