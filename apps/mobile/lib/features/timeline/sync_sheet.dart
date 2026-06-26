import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

const _visLabels = {'BUSY_ONLY': 'Busy only', 'TITLE_ONLY': 'Title only', 'FULL': 'Full details'};

/// A row that lets the owner pick how a group sees a self block.
/// `visibility` null means "do not sync".
class SyncRow extends StatelessWidget {
  final String name;
  final String accent;
  final String? visibility;
  final void Function(String? visibility) onToggle;
  const SyncRow({super.key, required this.name, required this.accent, required this.visibility, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = visibility != null;
    return Container(
      margin: const EdgeInsets.only(bottom: OrdoSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(OrdoRadius.md),
        border: Border.all(color: on ? OrdoAccent.byName(accent).primary(Theme.of(context).brightness == Brightness.dark) : cs.outline),
      ),
      child: Row(
        children: [
          OGroupAvatar(name: name, accent: accent, size: 34),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (on)
                  Text(_visLabels[visibility] ?? visibility!, style: TextStyle(fontSize: 12, color: OrdoAccent.byName(accent).primary(Theme.of(context).brightness == Brightness.dark), fontWeight: FontWeight.w600))
                else
                  Text('Do not sync', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
              ],
            ),
          ),
          PopupMenuButton<String?>(
            tooltip: 'Visibility',
            icon: Icon(on ? Icons.shield_outlined : Icons.shield_moon_outlined, color: on ? OrdoAccent.byName(accent).primary(Theme.of(context).brightness == Brightness.dark) : cs.onSecondary),
            onSelected: (v) => onToggle(v == '__off' ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '__off', child: Text('Do not sync')),
              for (final e in _visLabels.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Manage sync settings for an existing self block.
Future<void> showSyncSheet(BuildContext context, WidgetRef ref, String blockId) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SyncSheet(blockId: blockId, ref: ref),
  );
}

class _SyncSheet extends ConsumerStatefulWidget {
  final String blockId;
  final WidgetRef ref;
  const _SyncSheet({required this.blockId, required this.ref});

  @override
  ConsumerState<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends ConsumerState<_SyncSheet> {
  Map<String, String> _draft = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = widget.ref.read(groupsProvider).valueOrNull ?? [];
    final syncs = await widget.ref.read(apiClientProvider).syncs(widget.blockId);
    if (!mounted) return;
    setState(() {
      _draft = {for (final s in syncs) s.groupId: s.visibility};
      _loaded = true;
    });
    // ensure groups are loaded
    if (groups.isEmpty) widget.ref.invalidate(groupsProvider);
  }

  Future<void> _save() async {
    final api = widget.ref.read(apiClientProvider);
    final entries = _draft.entries.map((e) => SyncEntry(groupId: e.key, visibility: e.value)).toList();
    try {
      // Remove groups that were turned off, set the rest.
      final active = entries.map((e) => e.groupId).toSet();
      final existing = (await api.syncs(widget.blockId));
      for (final s in existing) {
        if (!active.contains(s.groupId)) {
          await api.removeSync(widget.blockId, s.groupId);
        }
      }
      if (entries.isNotEmpty) await api.setSyncs(widget.blockId, entries);
      widget.ref.invalidate(blockSyncsProvider);
      widget.ref.invalidate(groupsProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.ref.watch(groupsProvider).valueOrNull ?? [];
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OrdoSpacing.xl, 0, OrdoSpacing.xl, OrdoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sync to groups', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: OrdoSpacing.sm),
            Text('Control what each group can see. Your private details stay private.',
                style: TextStyle(color: cs.onSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: OrdoSpacing.lg),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (!_loaded || groups.isEmpty)
                    const Padding(padding: EdgeInsets.all(OrdoSpacing.xl), child: Center(child: CircularProgressIndicator()))
                  else
                    for (final g in groups)
                      SyncRow(
                        name: g.name,
                        accent: g.accentColor,
                        visibility: _draft[g.id],
                        onToggle: (vis) => setState(() {
                          if (vis == null) {
                            _draft.remove(g.id);
                          } else {
                            _draft[g.id] = vis;
                          }
                        }),
                      ),
                ],
              ),
            ),
            const SizedBox(height: OrdoSpacing.lg),
            FilledButton(onPressed: _save, child: const Text('Save sync settings')),
          ],
        ),
      ),
    );
  }
}
