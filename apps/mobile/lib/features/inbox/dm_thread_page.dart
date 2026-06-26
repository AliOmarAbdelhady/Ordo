import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

class DmThreadPage extends ConsumerStatefulWidget {
  final String threadId;
  const DmThreadPage({super.key, required this.threadId});

  @override
  ConsumerState<DmThreadPage> createState() => _DmThreadPageState();
}

class _DmThreadPageState extends ConsumerState<DmThreadPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<DmMessage> _messages = [];
  String? _title;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).dmMessages(widget.threadId);
      _messages = res.messages;
      // Title = the OTHER participant, not the sender of the oldest message
      // (which is often the user themselves). Fall back to a generic label.
      final me = ref.read(authControllerProvider).valueOrNull?.id;
      String? otherName;
      for (final m in res.messages) {
        if (m.senderId != me) {
          otherName = m.senderName;
          break;
        }
      }
      _title = (otherName != null && otherName.isNotEmpty) ? otherName : 'Direct message';
      await ref.read(apiClientProvider).markDmRead(widget.threadId);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _sending = true);
    try {
      final msg = await ref.read(apiClientProvider).sendDm(widget.threadId, text);
      setState(() => _messages = [..._messages, msg]);
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 60, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_title ?? 'Direct message')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const OEmptyState(icon: Icons.chat_bubble_outline, title: 'Say hello')
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(OrdoSpacing.lg),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final mine = m.senderId == me?.id;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: OrdoSpacing.sm),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm + 2),
                              decoration: BoxDecoration(
                                color: mine ? cs.primary : cs.surface,
                                borderRadius: BorderRadius.circular(OrdoRadius.lg),
                                border: mine ? null : Border.all(color: cs.outline),
                              ),
                              child: Text(m.body, style: TextStyle(color: mine ? cs.onPrimary : cs.onSurface)),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.md),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrdoRadius.pill), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: cs.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.md),
                    ),
                  ),
                ),
                const SizedBox(width: OrdoSpacing.sm),
                IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
