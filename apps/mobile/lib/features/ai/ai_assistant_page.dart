import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Ordo Copilot — a deterministic, on-device NL assistant. It proposes
/// structured actions (events / tasks / to-dos) and never commits them without
/// the user tapping Apply; Apply routes through the normal services, so the
/// same permission checks and side effects apply as a manual create.
class AiAssistantPage extends ConsumerStatefulWidget {
  final String? groupId;
  const AiAssistantPage({super.key, this.groupId});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatLine> _lines = [];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _push(_ChatLine line) {
    setState(() => _lines.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 60, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _parse() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _push(_ChatLine(role: _Role.user, text: text));
    setState(() => _busy = true);
    try {
      final s = await ref.read(apiClientProvider).aiParse(text, groupId: widget.groupId);
      if (s.intent == 'NONE') {
        _push(_ChatLine(role: _Role.assistant, text: "I couldn't quite understand that. Try e.g. “Family dinner tomorrow at 8pm” or “Remind Omar to bring the projector”."));
      } else {
        _push(_ChatLine(role: _Role.assistant, suggestion: s));
      }
    } on ApiException catch (e) {
      _push(_ChatLine(role: _Role.assistant, text: e.message, error: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(AiSuggestion s) async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiClientProvider).aiApply(s.raw, groupId: widget.groupId);
      final kind = res['kind'] ?? 'item';
      _push(_ChatLine(role: _Role.assistant, text: '✓ Created $kind: ${s.title.isEmpty ? (res['block']?['title'] ?? '') : s.title}'));
    } on ApiException catch (e) {
      _push(_ChatLine(role: _Role.assistant, text: e.message, error: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _planDay() async {
    _push(_ChatLine(role: _Role.user, text: 'Plan my day'));
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiClientProvider).aiPlanDay();
      _push(_ChatLine(role: _Role.assistant, text: res['plan'] as String? ?? 'No plan available.'));
    } on ApiException catch (e) {
      _push(_ChatLine(role: _Role.assistant, text: e.message, error: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ordo Copilot'), actions: [IconButton(onPressed: _busy ? null : _planDay, icon: const Icon(Icons.auto_awesome_outlined), tooltip: 'Plan my day')]),
      body: Column(
        children: [
          Expanded(
            child: _lines.isEmpty
                ? const OEmptyState(icon: Icons.auto_awesome_outlined, title: 'How can I help you plan?', subtitle: '“Family dinner tomorrow at 8pm”\n“Remind Omar to bring the projector”')
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(OrdoSpacing.lg),
                    itemCount: _lines.length,
                    itemBuilder: (_, i) => _bubble(_lines[i], cs),
                  ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _parse(),
                      decoration: InputDecoration(
                        hintText: 'Ask Copilot to plan something…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrdoRadius.pill), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: cs.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: OrdoSpacing.sm),
                  IconButton.filled(onPressed: _busy ? null : _parse, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_ChatLine line, ColorScheme cs) {
    final isUser = line.role == _Role.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: OrdoSpacing.md),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        padding: const EdgeInsets.all(OrdoSpacing.md),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(OrdoRadius.lg).copyWith(topRight: isUser ? Radius.zero : null, topLeft: !isUser ? Radius.zero : null),
          border: isUser ? null : Border.all(color: cs.outline),
        ),
        child: line.suggestion != null ? _suggestionCard(line.suggestion!, cs, isUser) : Text(
          line.text ?? '',
          style: TextStyle(color: isUser ? cs.onPrimary : (line.error ? cs.error : cs.onSurface)),
        ),
      ),
    );
  }

  Widget _suggestionCard(AiSuggestion s, ColorScheme cs, bool isUser) {
    final parts = <String>[];
    if (s.startTime != null) parts.add('Start: ${fmtDateTime(DateTime.parse(s.startTime!))}');
    if (s.endTime != null) parts.add('End: ${fmtDateTime(DateTime.parse(s.endTime!))}');
    if (s.assigneeName != null) parts.add('Assignee: ${s.assigneeName}');
    if (s.dueDate != null) parts.add('Due: ${fmtDate(DateTime.parse(s.dueDate!))}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OBadge(label: s.intent.replaceAll('_', ' '), color: isUser ? cs.onPrimary : cs.primary),
        const SizedBox(height: 8),
        Text(s.title.isEmpty ? '(no title)' : s.title, style: TextStyle(fontWeight: FontWeight.w700, color: isUser ? cs.onPrimary : cs.onSurface)),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(parts.join('\n'), style: TextStyle(fontSize: 12, color: isUser ? cs.onPrimary.withValues(alpha: 0.9) : cs.onSecondary)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(onPressed: _busy ? null : () => _apply(s), child: const Text('Apply')),
            TextButton(onPressed: () => setState(() => _lines.removeWhere((l) => l.suggestion == s)), child: const Text('Dismiss')),
          ],
        ),
      ],
    );
  }
}

enum _Role { user, assistant }

class _ChatLine {
  final _Role role;
  final String? text;
  final AiSuggestion? suggestion;
  final bool error;
  _ChatLine({required this.role, this.text, this.suggestion, this.error = false});
}
