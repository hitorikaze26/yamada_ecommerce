import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/conversation_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/chat_notifier.dart';
import '../../widgets/chat/chat_empty_state.dart';
import '../../widgets/chat/chat_filter_chips.dart';
import '../../widgets/chat/chat_list_tile.dart';
import '../../widgets/chat/chat_section_label.dart';
import '../../widgets/chat/chat_skeleton.dart';
import '../../widgets/chat/chat_theme.dart';

enum ChatListFilter { all, unread, buyer, seller, support, rider, archived }

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  String _query = '';
  ChatListFilter _filter = ChatListFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(_reloadList);
  }

  Future<void> _reloadList() async {
    await ref.read(chatProvider.notifier).loadConversations(
          archived: _filter == ChatListFilter.archived,
        );
  }

  List<ChatListFilter> _filtersForRole(UserRole? role) {
    switch (role) {
      case UserRole.seller:
        return [
          ChatListFilter.all,
          ChatListFilter.unread,
          ChatListFilter.buyer,
          ChatListFilter.rider,
          ChatListFilter.support,
          ChatListFilter.archived,
        ];
      case UserRole.rider:
        return [
          ChatListFilter.all,
          ChatListFilter.unread,
          ChatListFilter.seller,
          ChatListFilter.archived,
        ];
      case UserRole.buyer:
        return [
          ChatListFilter.all,
          ChatListFilter.unread,
          ChatListFilter.seller,
          ChatListFilter.support,
          ChatListFilter.archived,
        ];
      default:
        return [
          ChatListFilter.all,
          ChatListFilter.unread,
          ChatListFilter.archived,
        ];
    }
  }

  bool _matchesFilter(ConversationModel c) {
    if (_filter == ChatListFilter.archived) return true;
    switch (_filter) {
      case ChatListFilter.unread:
        return c.unreadCount > 0;
      case ChatListFilter.buyer:
        return c.peer.role == 'buyer';
      case ChatListFilter.seller:
        return c.peer.role == 'seller';
      case ChatListFilter.support:
        return c.kind.contains('admin') || c.peer.role == 'admin';
      case ChatListFilter.rider:
        return c.peer.role == 'rider';
      default:
        return true;
    }
  }

  List<ConversationModel> _filtered(List<ConversationModel> all) {
    return all.where((c) {
      if (!_matchesFilter(c)) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.title.toLowerCase().contains(q) ||
          c.lastMessagePreview.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmArchive(ConversationModel c) async {
    final p = ChatPalette.of(context);
    final archived = c.isArchived;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(
          archived ? 'Unarchive?' : 'Archive conversation?',
          style: TextStyle(color: p.textPrimary),
        ),
        content: Text(
          archived
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
              archived ? 'Unarchive' : 'Archive',
              style: TextStyle(color: p.accent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(chatProvider.notifier).archiveConversation(
          c.id,
          archive: !archived,
        );
    if (!mounted) return;
    AlertService.showSnackBar(
      context: context,
      message: archived ? 'Conversation restored' : 'Conversation archived',
      variant: AlertVariant.success,
    );
  }

  Future<void> _confirmDelete(ConversationModel c) async {
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
    await ref.read(chatProvider.notifier).deleteConversation(c.id);
    if (!mounted) return;
    AlertService.showSnackBar(
      context: context,
      message: 'Conversation deleted',
      variant: AlertVariant.success,
    );
  }

  String _filterLabel(ChatListFilter f) {
    switch (f) {
      case ChatListFilter.unread:
        return 'Unread';
      case ChatListFilter.buyer:
        return 'Buyers';
      case ChatListFilter.seller:
        return 'Sellers';
      case ChatListFilter.support:
        return 'Support';
      case ChatListFilter.rider:
        return 'Riders';
      case ChatListFilter.archived:
        return 'Archived';
      default:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette.of(context);
    final chatState = ref.watch(chatProvider);
    final role = ref.watch(authProvider).user?.role;
    final filtered = _filtered(chatState.conversations);
    final showPinned = _filter != ChatListFilter.archived;
    final pinned =
        showPinned ? filtered.where((c) => c.isPinned).toList() : <ConversationModel>[];
    final rest = showPinned
        ? filtered.where((c) => !c.isPinned).toList()
        : filtered;

    return Scaffold(
      backgroundColor: p.screenBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChatListHeader(
              palette: p,
              role: role,
              onSupport: () async {
                final conv =
                    await ref.read(chatProvider.notifier).openSupport();
                if (context.mounted) context.push('/chat/${conv.id}');
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: p.bodyMedium(context),
                decoration: p.searchDecoration(),
              ),
            ),
            ChatFilterChips<ChatListFilter>(
              isDark: p.isDark,
              filters: _filtersForRole(role),
              selected: _filter,
              labelFor: _filterLabel,
              onSelected: (f) {
                setState(() => _filter = f);
                _reloadList();
              },
            ),
            Expanded(
              child: chatState.isLoadingList
                  ? ChatListSkeleton(isDark: p.isDark)
                  : filtered.isEmpty
                      ? ChatEmptyState(
                          isDark: p.isDark,
                          icon: _filter == ChatListFilter.archived
                              ? Icons.archive_outlined
                              : Icons.chat_bubble_outline_rounded,
                          title: _filter == ChatListFilter.archived
                              ? 'No archived chats'
                              : 'No conversations yet',
                          subtitle: _filter == ChatListFilter.archived
                              ? 'Archived conversations will appear here.'
                              : 'Start chatting with a boutique or support.',
                        )
                      : RefreshIndicator(
                          color: p.accent,
                          backgroundColor: p.surface,
                          onRefresh: _reloadList,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [
                              if (pinned.isNotEmpty) ...[
                                ChatSectionLabel(
                                    text: 'Pinned', isDark: p.isDark),
                                ...pinned.map(
                                  (c) => ChatConversationTile(
                                    conversation: c,
                                    isDark: p.isDark,
                                    onTap: () => context.push('/chat/${c.id}'),
                                    onLongPress: () => ref
                                        .read(chatProvider.notifier)
                                        .togglePin(c),
                                    onArchive: () => _confirmArchive(c),
                                    onDelete: () => _confirmDelete(c),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (rest.isNotEmpty && pinned.isNotEmpty)
                                ChatSectionLabel(
                                    text: 'Messages', isDark: p.isDark),
                              ...rest.map(
                                (c) => ChatConversationTile(
                                  conversation: c,
                                  isDark: p.isDark,
                                  onTap: () => context.push('/chat/${c.id}'),
                                  onLongPress: () => ref
                                      .read(chatProvider.notifier)
                                      .togglePin(c),
                                  onArchive: () => _confirmArchive(c),
                                  onDelete: () => _confirmDelete(c),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatListHeader extends StatelessWidget {
  final ChatPalette palette;
  final UserRole? role;
  final VoidCallback onSupport;

  const _ChatListHeader({
    required this.palette,
    required this.role,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: palette.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Messages', style: palette.titleLarge(context)),
                Text(
                  'Your boutique conversations',
                  style: palette.caption(context),
                ),
              ],
            ),
          ),
          if (role == UserRole.buyer || role == UserRole.seller)
            IconButton(
              tooltip: 'Support',
              icon: Icon(Icons.support_agent_rounded, color: palette.accent),
              onPressed: onSupport,
            ),
        ],
      ),
    );
  }
}
