import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/providers/chat_notifier.dart';
import '../../widgets/chat/chat_actions_sheet.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/chat_message_bubble.dart';
import '../../widgets/chat/chat_skeleton.dart';
import '../../widgets/chat/chat_thread_header.dart';
import '../../widgets/chat/chat_theme.dart';

class ChatThreadPage extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatThreadPage({super.key, required this.conversationId});

  int get convId => int.tryParse(conversationId) ?? 0;

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _scroll = ScrollController();
  bool _showNewMessages = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(chatProvider.notifier).loadThread(widget.convId);
      _scrollToBottom();
    });
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom = _scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 80;
    if (atBottom && _showNewMessages) {
      setState(() => _showNewMessages = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  ChatMessageModel? _replyFor(List<ChatMessageModel> msgs, ChatMessageModel m) {
    final id = m.replyToMessageId;
    if (id == null) return null;
    for (final x in msgs) {
      if (x.id == id) return x;
    }
    return null;
  }

  Future<void> _confirmArchive(bool currentlyArchived) async {
    final p = ChatPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(
          currentlyArchived ? 'Unarchive?' : 'Archive conversation?',
          style: TextStyle(color: p.textPrimary),
        ),
        content: Text(
          currentlyArchived
              ? 'This chat will return to your inbox.'
              : 'It will be hidden from your inbox. You can find it under Archived.',
          style: TextStyle(color: p.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              currentlyArchived ? 'Unarchive' : 'Archive',
              style: TextStyle(color: p.accent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref.read(chatProvider.notifier).archiveConversation(
          widget.convId,
          archive: !currentlyArchived,
        );
    if (!mounted) return;
    AlertService.showSnackBar(
      context: context,
      message: currentlyArchived ? 'Conversation restored' : 'Conversation archived',
      variant: AlertVariant.success,
    );
    context.pop();
  }

  Future<void> _confirmDelete() async {
    final p = ChatPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Delete conversation?', style: TextStyle(color: p.textPrimary)),
        content: Text(
          'This removes the chat from your list. The other person may still see it.',
          style: TextStyle(color: p.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref.read(chatProvider.notifier).deleteConversation(widget.convId);
    if (!mounted) return;
    AlertService.showSnackBar(
      context: context,
      message: 'Conversation deleted',
      variant: AlertVariant.success,
    );
    context.pop();
  }

  void _openThreadMenu(bool isArchived) {
    ChatThreadMenuSheet.show(
      context,
      isDark: Theme.of(context).brightness == Brightness.dark,
      isArchived: isArchived,
      onArchive: () => _confirmArchive(isArchived),
      onDelete: _confirmDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette.of(context);
    final thread = ref.watch(chatThreadProvider(widget.convId));
    final peer = thread.peer ?? thread.conversation?.peer;
    final title = thread.conversation?.title ?? peer?.name ?? 'Chat';
    final storeId = thread.conversation?.storeId;
    final isArchived = thread.conversation?.isArchived ?? false;

    ref.listen(chatThreadProvider(widget.convId), (prev, next) {
      if (prev != null &&
          next.messages.length > prev.messages.length &&
          _scroll.hasClients &&
          _scroll.position.pixels <
              _scroll.position.maxScrollExtent - 120) {
        setState(() => _showNewMessages = true);
      } else if (next.messages.length > (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: p.screenBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            ChatThreadHeader(
              isDark: p.isDark,
              title: title,
              peer: peer,
              isArchived: isArchived,
              onMenu: () => _openThreadMenu(isArchived),
            ),
            Expanded(
              child: thread.isLoading
                  ? ChatThreadSkeleton(isDark: p.isDark)
                  : DecoratedBox(
                      decoration: BoxDecoration(color: p.threadBg),
                      child: Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n is ScrollUpdateNotification &&
                                  _scroll.hasClients &&
                                  _scroll.position.pixels <= 80 &&
                                  thread.hasMore &&
                                  !thread.isLoading) {
                                ref
                                    .read(chatProvider.notifier)
                                    .loadMoreMessages(widget.convId);
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scroll,
                              padding: ChatTheme.listPadding,
                              itemCount: thread.messages.length,
                              itemBuilder: (context, index) {
                                final m = thread.messages[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ChatMessageBubble(
                                    message: m,
                                    isDark: p.isDark,
                                    replyTo: _replyFor(thread.messages, m),
                                    onReply: () => ref
                                        .read(chatProvider.notifier)
                                        .setReplyTo(widget.convId, m),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_showNewMessages)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Material(
                                  color: p.accent,
                                  elevation: p.isDark ? 0 : 2,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    onTap: _scrollToBottom,
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'New messages',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            ChatInputBar(
              conversationId: widget.convId,
              isDark: p.isDark,
              storeId: storeId,
            ),
          ],
        ),
      ),
    );
  }
}
