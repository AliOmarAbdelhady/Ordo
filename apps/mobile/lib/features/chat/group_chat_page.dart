import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/providers.dart';
import '../../core/realtime.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Realtime group chat for a single group.
class GroupChatPage extends ConsumerStatefulWidget {
  final String groupId;
  const GroupChatPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _loadError;

  /// Message currently being replied to (preview above composer).
  ChatMessage? _replyTo;
  /// Message being edited inline.
  ChatMessage? _editing;
  bool _sending = false;

  /// userIds (other than me) who are currently typing.
  Set<String> _typingUsers = {};

  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _typingDebounce;
  bool _selfTyping = false;

  String? get _meId => ref.read(authControllerProvider).valueOrNull?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _typingDebounce?.cancel();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.messages(widget.groupId, limit: 40);
      if (!mounted) return;
      setState(() {
        _messages = res.messages;
        _loading = false;
      });
      _jumpToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load messages.';
        _loading = false;
      });
    }
  }

  Future<void> _markRead() async {
    try {
      await ref.read(apiClientProvider).markRead(widget.groupId);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(groupsProvider);
    } catch (_) {
      // best-effort
    }
  }

  void _subscribeRealtime() {
    _sub = ref.read(realtimeProvider).events.listen((e) {
      switch (e.name) {
        case 'chat:message':
          _onChatMessage(e);
          break;
        case 'chat:update':
          _onChatUpdate(e);
          break;
        case 'chat:delete':
          _onChatDelete(e);
          break;
        case 'chat:reaction':
          _onChatReaction(e);
          break;
        case 'chat:typing':
          _onChatTyping(e);
          break;
      }
    });
  }

  Map<String, dynamic>? _payload(RealtimeEvent e) {
    final d = e.data;
    if (d is Map<String, dynamic>) return d;
    return null;
  }

  void _onChatMessage(RealtimeEvent e) {
    final p = _payload(e);
    if (p == null) return;
    final msg = ChatMessage.fromJson(p);
    if (msg.groupId != widget.groupId) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
    _jumpToBottom(animate: msg.senderId == _meId);
  }

  void _onChatUpdate(RealtimeEvent e) {
    final p = _payload(e);
    if (p == null) return;
    final updated = ChatMessage.fromJson(p);
    setState(() {
      final i = _messages.indexWhere((m) => m.id == updated.id);
      if (i >= 0) _messages[i] = updated;
    });
  }

  void _onChatDelete(RealtimeEvent e) {
    final p = _payload(e);
    final id = p?['id']?.toString();
    if (id == null) return;
    setState(() {
      final i = _messages.indexWhere((m) => m.id == id);
      if (i >= 0) {
        // Mark deleted if the server marks it, otherwise remove.
        _messages[i] = _messages[i].copyWith(deleted: true, body: '');
      }
    });
  }

  void _onChatReaction(RealtimeEvent e) {
    final p = _payload(e);
    if (p == null) return;
    final id = p['id']?.toString();
    if (id == null) return;
    final reactions = (p['reactions'] as List?)
            ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
            .toList() ??
        const <MessageReaction>[];
    setState(() {
      final i = _messages.indexWhere((m) => m.id == id);
      if (i >= 0) _messages[i] = _messages[i].copyWith(reactions: reactions);
    });
  }

  void _onChatTyping(RealtimeEvent e) {
    final p = _payload(e);
    if (p == null) return;
    if (p['groupId'] != widget.groupId) return;
    final userId = p['userId']?.toString();
    final isTyping = p['isTyping'] == true;
    final me = _meId;
    if (userId == null || userId == me) return;
    setState(() {
      if (isTyping) {
        _typingUsers = {..._typingUsers, userId};
      } else {
        _typingUsers = _typingUsers.where((u) => u != userId).toSet();
      }
    });
  }

  void _emitTyping(bool isTyping) {
    ref.read(realtimeProvider).emit('chat:typing', {
      'groupId': widget.groupId,
      'isTyping': isTyping,
    });
  }

  void _onInputChanged() {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();
    if (!_selfTyping) {
      _selfTyping = true;
      _emitTyping(true);
    }
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _selfTyping = false;
      _emitTyping(false);
    });
  }

  void _jumpToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (animate) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final api = ref.read(apiClientProvider);
    setState(() => _sending = true);
    try {
      final replyId = _editing == null ? _replyTo?.id : null;
      if (_editing != null) {
        final updated = await api.editMessage(_editing!.id, text);
        final i = _messages.indexWhere((m) => m.id == updated.id);
        setState(() {
          if (i >= 0) {
            _messages[i] = updated;
          } else {
            _messages.add(updated);
          }
        });
      } else {
        final sent = await api.sendMessage(widget.groupId, text, replyToId: replyId);
        // Insert if not already present via realtime.
        if (!_messages.any((m) => m.id == sent.id)) {
          setState(() => _messages.add(sent));
        }
      }
      _input.clear();
      _emitTyping(false);
      _selfTyping = false;
      setState(() {
        _replyTo = null;
        _editing = null;
      });
      _jumpToBottom();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not send message.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startReply(ChatMessage m) {
    setState(() {
      _replyTo = m;
      _editing = null;
    });
    _focus.requestFocus();
  }

  void _startEdit(ChatMessage m) {
    setState(() {
      _editing = m;
      _replyTo = null;
      _input.text = m.body ?? '';
    });
    _focus.requestFocus();
  }

  void _cancelCompose() {
    setState(() {
      _replyTo = null;
      _editing = null;
    });
    _input.clear();
  }

  Future<void> _confirmDelete(ChatMessage m) async {
    final ok = await confirm(
      context,
      title: 'Delete message?',
      message: 'This message will be removed for everyone.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiClientProvider).deleteMessage(m.id);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not delete message.', error: true);
    }
  }

  Future<void> _toggleReaction(ChatMessage m, String emoji) async {
    try {
      await ref.read(apiClientProvider).reactMessage(m.id, emoji);
      // Optimistic local update until the server echoes the event.
      final me = _meId;
      setState(() {
        final i = _messages.indexWhere((x) => x.id == m.id);
        if (i >= 0) {
          final reactions = List<MessageReaction>.from(_messages[i].reactions);
          final idx = reactions.indexWhere((r) => r.emoji == emoji);
          if (idx >= 0) {
            final r = reactions[idx];
            final has = me != null && r.userIds.contains(me);
            reactions[idx] = MessageReaction(
              emoji: r.emoji,
              count: has ? r.count - 1 : r.count + 1,
              userIds: has
                  ? r.userIds.where((u) => u != me).toList()
                  : [...r.userIds, ?me],
            );
            _messages[i] = _messages[i].copyWith(reactions: reactions);
          } else if (me != null) {
            reactions.add(MessageReaction(emoji: emoji, count: 1, userIds: [me]));
            _messages[i] = _messages[i].copyWith(reactions: reactions);
          }
        }
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final groupName = groupAsync.valueOrNull?.name ?? 'Chat';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/groups/${widget.groupId}');
            }
          },
        ),
        title: GestureDetector(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.push('/groups/${widget.groupId}');
            }
          },
          child: Row(
            children: [
              OGroupAvatar(
                name: groupName,
                accent: groupAsync.valueOrNull?.accentColor ?? 'blue',
                size: 34,
              ),
              const SizedBox(width: OrdoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(groupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (_typingUsers.isNotEmpty)
                      Text(
                        'typing…',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (groupAsync.valueOrNull != null)
                      Text(
                        '${groupAsync.valueOrNull!.memberCount} members',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildList(context, isDark)),
            if (_replyTo != null || _editing != null) _buildComposePreview(context),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(OrdoSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: OrdoSpacing.md),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: OrdoSpacing.md),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const OEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No messages yet',
        subtitle: 'Say hello to start the conversation.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final prev = i > 0 ? _messages[i - 1] : null;
        final showHeader = prev == null ||
            prev.senderId != m.senderId ||
            m.createdAt.difference(prev.createdAt).inMinutes.abs() > 5;
        return _MessageBubble(
          message: m,
          isMine: m.senderId == _meId,
          showHeader: showHeader,
          onReply: () => _startReply(m),
          onEdit: m.senderId == _meId && !m.deleted ? () => _startEdit(m) : null,
          onDelete: m.senderId == _meId ? () => _confirmDelete(m) : null,
          onReact: (emoji) => _toggleReaction(m, emoji),
        );
      },
    );
  }

  Widget _buildComposePreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = _editing != null;
    final label = isEdit ? 'Editing' : 'Replying to';
    final sender = _editing?.senderName ?? _replyTo?.senderName ?? '';
    final body = _editing?.body ?? _replyTo?.body ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.md, OrdoSpacing.sm, OrdoSpacing.md, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          Icon(isEdit ? Icons.edit_outlined : Icons.reply, size: 18, color: cs.primary),
          const SizedBox(width: OrdoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$label $sender',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: _cancelCompose,
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OrdoSpacing.md,
        OrdoSpacing.sm,
        OrdoSpacing.sm,
        MediaQuery.of(context).viewInsets.bottom + OrdoSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _onInputChanged(),
              decoration: InputDecoration(
                hintText: _editing != null ? 'Edit message' : 'Message',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(OrdoRadius.xl),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainer,
              ),
            ),
          ),
          const SizedBox(width: OrdoSpacing.sm),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_editing != null ? Icons.check : Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}

const _quickEmojis = ['👍', '❤️', '😂'];

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showHeader;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(String emoji) onReact;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showHeader,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bubbleColor = isMine ? cs.primary : cs.surface;
    final textColor = isMine ? cs.onPrimary : cs.onSurface;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: EdgeInsets.only(top: showHeader ? OrdoSpacing.md : 2),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && showHeader)
            Padding(
              padding: const EdgeInsets.only(right: OrdoSpacing.sm),
              child: OAvatar(name: message.senderName, imageUrl: message.senderAvatar, radius: 14),
            )
          else if (!isMine)
            const SizedBox(width: 32),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActions(context),
              child: Column(
                crossAxisAlignment: align,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine && showHeader)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(colorFromString(message.senderName)),
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.74,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: 8),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(OrdoRadius.lg),
                        topRight: const Radius.circular(OrdoRadius.lg),
                        bottomLeft: isMine ? const Radius.circular(OrdoRadius.lg) : Radius.zero,
                        bottomRight: isMine ? Radius.zero : const Radius.circular(OrdoRadius.lg),
                      ),
                      border: isMine ? null : Border.all(color: cs.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: align,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.replyToBody != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.sm, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMine ? Colors.white.withValues(alpha: 0.18) : cs.surfaceContainer,
                              borderRadius: BorderRadius.circular(OrdoRadius.sm),
                              border: Border(left: BorderSide(color: cs.primary, width: 2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.replyToSender != null)
                                  Text(
                                    message.replyToSender!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isMine ? cs.onPrimary : cs.primary,
                                    ),
                                  ),
                                Text(
                                  message.replyToBody!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          message.deleted ? 'Message deleted' : (message.body ?? ''),
                          style: TextStyle(
                            fontSize: 15,
                            color: message.deleted ? textColor.withValues(alpha: 0.6) : textColor,
                            fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fmtTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.65),
                              ),
                            ),
                            if (message.editedAt != null && !message.deleted) ...[
                              const SizedBox(width: 4),
                              Text(
                                'edited',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textColor.withValues(alpha: 0.55),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final r in message.reactions)
                            _ReactionChip(
                              emoji: r.emoji,
                              count: r.count,
                              highlight: false,
                              onTap: () => onReact(r.emoji),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'reply', child: Text('Reply')),
      PopupMenuItem(
        enabled: false,
        child: Wrap(
          spacing: 4,
          children: [
            for (final e in _quickEmojis)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onReact(e);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
      ),
      if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
      if (onDelete != null)
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ];

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 0, 0, 0),
      items: items,
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'reply':
          onReply();
          break;
        case 'edit':
          onEdit?.call();
          break;
        case 'delete':
          onDelete?.call();
          break;
      }
    });
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool highlight;
  final VoidCallback onTap;
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: highlight ? cs.primaryContainer : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(OrdoRadius.pill),
          border: Border.all(color: highlight ? cs.primary : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 2),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: highlight ? cs.primary : cs.onSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
