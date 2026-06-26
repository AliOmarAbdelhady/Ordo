import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

class PollsPage extends ConsumerWidget {
  final String groupId;
  const PollsPage({super.key, required this.groupId});

  Future<void> _vote(BuildContext context, WidgetRef ref, Poll poll, PollOptionResult opt) async {
    try {
      // Single-choice: replace; multi: toggle.
      final selected = poll.multiple
          ? (poll.viewerVotes.contains(opt.id) ? poll.viewerVotes.where((e) => e != opt.id).toList() : [...poll.viewerVotes, opt.id])
          : [opt.id];
      await ref.read(apiClientProvider).votePoll(poll.id, selected);
      ref.invalidate(pollsProvider(groupId));
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polls = ref.watch(pollsProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreate(context, ref),
        child: const Icon(Icons.add),
      ),
      body: polls.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Couldn’t load polls', subtitle: '$e', action: TextButton(onPressed: () => ref.invalidate(pollsProvider(groupId)), child: const Text('Retry'))),
        data: (list) {
          if (list.isEmpty) return const OEmptyState(icon: Icons.poll_outlined, title: 'No polls yet', subtitle: 'Create one to gather the group’s vote.');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pollsProvider(groupId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(OrdoSpacing.lg),
              itemCount: list.length,
              itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: OrdoSpacing.md), child: _PollCard(poll: list[i], onVote: (opt) => _vote(context, ref, list[i], opt), onDelete: () async {
                final ok = await confirm(context, title: 'Delete poll?', danger: true);
                if (!ok) return;
                try {
                  await ref.read(apiClientProvider).deletePoll(list[i].id);
                  ref.invalidate(pollsProvider(groupId));
                } on ApiException catch (e) {
                  if (context.mounted) toast(context, e.message, error: true);
                }
              })),
            ),
          );
        },
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    final q = TextEditingController();
    final opts = <TextEditingController>[TextEditingController(), TextEditingController()];
    bool multiple = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.lg, MediaQuery.of(ctx).viewInsets.bottom + OrdoSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New poll', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: OrdoSpacing.md),
                TextField(controller: q, decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder())),
                const SizedBox(height: OrdoSpacing.sm),
                for (var i = 0; i < opts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Expanded(child: TextField(controller: opts[i], decoration: InputDecoration(labelText: 'Option ${i + 1}', border: const OutlineInputBorder()))),
                      if (opts.length > 2) IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setS(() => opts.removeAt(i))),
                    ]),
                  ),
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setS(() => opts.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Add option'))),
                SwitchListTile(value: multiple, onChanged: (v) => setS(() => multiple = v), title: const Text('Allow multiple choices')),
                FilledButton(
                  onPressed: () async {
                    final question = q.text.trim();
                    final options = opts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                    if (question.isEmpty || options.length < 2) { toast(ctx, 'Add a question and 2+ options', error: true); return; }
                    try {
                      await ref.read(apiClientProvider).createPoll(groupId, question, options, multiple: multiple);
                      if (ctx.mounted) Navigator.pop(ctx);
                      ref.invalidate(pollsProvider(groupId));
                    } on ApiException catch (e) {
                      if (ctx.mounted) toast(ctx, e.message, error: true);
                    }
                  },
                  child: const Text('Create poll'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final Poll poll;
  final void Function(PollOptionResult) onVote;
  final VoidCallback onDelete;
  const _PollCard({required this.poll, required this.onVote, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(poll.question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: onDelete),
          ]),
          if (poll.closed) OBadge(label: 'closed', color: cs.error) else if (poll.multiple) OBadge(label: 'multi', color: cs.primary),
          const SizedBox(height: OrdoSpacing.sm),
          for (final o in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _optionTile(o, cs),
            ),
          const SizedBox(height: 4),
          Text('${poll.totalVoters} voter${poll.totalVoters == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
        ],
      ),
    );
  }

  Widget _optionTile(PollOptionResult o, ColorScheme cs) {
    final chosen = poll.viewerVotes.contains(o.id);
    final pct = o.percent.clamp(0, 100);
    return InkWell(
      onTap: poll.closed ? null : () => onVote(o),
      borderRadius: BorderRadius.circular(OrdoRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(OrdoRadius.md), color: cs.surfaceContainer),
        child: Stack(
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct / 100,
              child: Container(color: (chosen ? cs.primary : cs.outline).withValues(alpha: 0.18), height: 40),
            ),
            Row(
              children: [
                Icon(chosen ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: chosen ? cs.primary : cs.onSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(o.text, style: TextStyle(fontWeight: chosen ? FontWeight.w700 : FontWeight.w500))),
                Text('${o.percent.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
