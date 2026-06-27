import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Shared, embeddable bodies for every group module. Each view is the content
/// of its module WITHOUT a Scaffold, so it can live either as a swipeable tab
/// inside [GroupHomePage] or inside a thin standalone page (deep-link route).
/// The create flows are lifted to top-level functions so both the host FAB and
/// the standalone pages can invoke them without duplicating logic.

// ════════════════════════════════════════════════════════════════════════════
// POLLS
// ════════════════════════════════════════════════════════════════════════════

class PollsView extends ConsumerWidget {
  final String groupId;
  const PollsView({super.key, required this.groupId});

  Future<void> _vote(BuildContext context, WidgetRef ref, Poll poll, PollOptionResult opt) async {
    try {
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
    return polls.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => OEmptyState(
        icon: Icons.error_outline,
        title: 'Couldn’t load polls',
        subtitle: e is ApiException ? e.message : '$e',
        action: TextButton(onPressed: () => ref.invalidate(pollsProvider(groupId)), child: const Text('Retry')),
      ),
      data: (list) {
        if (list.isEmpty) {
          return OEmptyState(
            icon: Icons.poll_outlined,
            title: 'No polls yet',
            subtitle: 'Tap + to gather the group’s vote.',
            action: FilledButton.icon(
              onPressed: () => showCreatePollSheet(context, ref, groupId),
              icon: const Icon(Icons.add),
              label: const Text('New poll'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pollsProvider(groupId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
            itemCount: list.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: OrdoSpacing.md),
              child: _PollCard(
                poll: list[i],
                onVote: (opt) => _vote(context, ref, list[i], opt),
                onDelete: () async {
                  final ok = await confirm(context, title: 'Delete poll?', danger: true);
                  if (!ok) return;
                  try {
                    await ref.read(apiClientProvider).deletePoll(list[i].id);
                    ref.invalidate(pollsProvider(groupId));
                  } on ApiException catch (e) {
                    if (context.mounted) toast(context, e.message, error: true);
                  }
                },
              ),
            ),
          ),
        );
      },
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
          if (poll.closed)
            OBadge(label: 'closed', color: cs.error)
          else if (poll.multiple)
            OBadge(label: 'multi', color: cs.primary),
          const SizedBox(height: OrdoSpacing.sm),
          for (final o in poll.options)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: _optionTile(o, cs)),
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

Future<void> showCreatePollSheet(BuildContext context, WidgetRef ref, String groupId) {
  final q = TextEditingController();
  final opts = <TextEditingController>[TextEditingController(), TextEditingController()];
  bool multiple = false;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(OrdoSpacing.lg, 0, OrdoSpacing.lg, MediaQuery.of(ctx).viewInsets.bottom + OrdoSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New poll', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: OrdoSpacing.md),
              TextField(controller: q, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder())),
              const SizedBox(height: OrdoSpacing.sm),
              for (var i = 0; i < opts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(child: TextField(controller: opts[i], decoration: InputDecoration(labelText: 'Option ${i + 1}', border: const OutlineInputBorder()))),
                    if (opts.length > 2)
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setS(() => opts.removeAt(i))),
                  ]),
                ),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setS(() => opts.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Add option'))),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: multiple,
                onChanged: (v) => setS(() => multiple = v),
                title: const Text('Allow multiple choices'),
              ),
              FilledButton(
                onPressed: () async {
                  final question = q.text.trim();
                  final options = opts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                  if (question.isEmpty || options.length < 2) {
                    toast(ctx, 'Add a question and 2+ options', error: true);
                    return;
                  }
                  try {
                    await ref.read(apiClientProvider).createPoll(groupId, question, options, multiple: multiple);
                    ref.invalidate(pollsProvider(groupId));
                    if (ctx.mounted) Navigator.pop(ctx);
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

// ════════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENTS
// ════════════════════════════════════════════════════════════════════════════

class AnnouncementsView extends ConsumerWidget {
  final String groupId;
  const AnnouncementsView({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider(groupId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => OEmptyState(
        icon: Icons.error_outline,
        title: 'Couldn’t load',
        subtitle: e is ApiException ? e.message : '$e',
        action: TextButton(onPressed: () => ref.invalidate(announcementsProvider(groupId)), child: const Text('Retry')),
      ),
      data: (list) {
        if (list.isEmpty) {
          return OEmptyState(
            icon: Icons.campaign_outlined,
            title: 'No announcements',
            subtitle: 'Pin an important update for the group.',
            action: FilledButton.icon(
              onPressed: () => showCreateAnnouncementSheet(context, ref, groupId),
              icon: const Icon(Icons.add),
              label: const Text('New announcement'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(announcementsProvider(groupId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
            itemCount: list.length,
            itemBuilder: (_, i) => _AnnouncementCard(
              a: list[i],
              onDelete: () async {
                final ok = await confirm(context, title: 'Delete announcement?', danger: true);
                if (!ok) return;
                try {
                  await ref.read(apiClientProvider).deleteAnnouncement(list[i].id);
                  ref.invalidate(announcementsProvider(groupId));
                } on ApiException catch (e) {
                  if (context.mounted) toast(context, e.message, error: true);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final VoidCallback onDelete;
  const _AnnouncementCard({required this.a, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OrdoSpacing.md),
      child: OCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign_outlined, color: Colors.amber),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (a.pinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 14, color: Colors.amber)),
                    Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 4),
                  Text(a.body),
                  const SizedBox(height: 6),
                  Text('${a.createdByName} · ${a.createdAt.toLocal().toString().substring(0, 16)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

Future<void> showCreateAnnouncementSheet(BuildContext context, WidgetRef ref, String groupId) {
  final title = TextEditingController();
  final body = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(OrdoSpacing.lg, 0, OrdoSpacing.lg, MediaQuery.of(ctx).viewInsets.bottom + OrdoSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New announcement', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: OrdoSpacing.md),
            TextField(controller: title, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: OrdoSpacing.sm),
            TextField(controller: body, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder())),
            const SizedBox(height: OrdoSpacing.sm),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
                  toast(ctx, 'Title and body are required', error: true);
                  return;
                }
                try {
                  await ref.read(apiClientProvider).createAnnouncement(groupId, title.text.trim(), body.text.trim());
                  ref.invalidate(announcementsProvider(groupId));
                  if (ctx.mounted) Navigator.pop(ctx);
                } on ApiException catch (e) {
                  if (ctx.mounted) toast(ctx, e.message, error: true);
                }
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// FILES
// ════════════════════════════════════════════════════════════════════════════

class FilesView extends ConsumerWidget {
  final String? groupId;
  const FilesView({super.key, this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaProvider(groupId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => OEmptyState(
        icon: Icons.error_outline,
        title: 'Couldn’t load',
        subtitle: e is ApiException ? e.message : '$e',
        action: TextButton(onPressed: () => ref.invalidate(mediaProvider(groupId)), child: const Text('Retry')),
      ),
      data: (files) {
        if (files.isEmpty) {
          return OEmptyState(
            icon: Icons.folder_outlined,
            title: 'No files yet',
            subtitle: 'Upload an image, PDF or document.',
            action: FilledButton.icon(
              onPressed: () => pickGroupFile(context, ref, groupId),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload file'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(mediaProvider(groupId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
            itemCount: files.length,
            itemBuilder: (_, i) => _fileTile(context, ref, files[i]),
          ),
        );
      },
    );
  }

  Widget _fileTile(BuildContext context, WidgetRef ref, MediaFile f) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
      child: OCard(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(OrdoRadius.md)),
              child: Icon(f.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: cs.primary),
            ),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${f.uploaderName} · ${_size(f.sizeBytes)}', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final ok = await confirm(context, title: 'Delete file?', danger: true);
                if (!ok) return;
                try {
                  await ref.read(apiClientProvider).deleteMedia(f.id);
                  ref.invalidate(mediaProvider(groupId));
                } on ApiException catch (e) {
                  if (context.mounted) toast(context, e.message, error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

Future<void> pickGroupFile(BuildContext context, WidgetRef ref, String? groupId) async {
  final result = await FilePicker.platform.pickFiles(allowMultiple: false);
  if (result == null || result.files.single.path == null) return;
  final f = result.files.single;
  try {
    await ref.read(apiClientProvider).uploadMedia(f.path!, f.name, groupId: groupId);
    ref.invalidate(mediaProvider(groupId));
    if (context.mounted) toast(context, 'Uploaded');
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOCATION
// ════════════════════════════════════════════════════════════════════════════

/// Group location sharing — strictly opt-in. The [active] flag gates the
/// foreground position-pusher: when this view is hosted in a TabBarView its
/// neighbours stay mounted, so we MUST stop the periodic push when the tab is
/// offscreen (otherwise live location keeps being sent in the background).
class LocationView extends ConsumerStatefulWidget {
  final String groupId;
  final bool active;
  const LocationView({super.key, required this.groupId, required this.active});

  @override
  ConsumerState<LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends ConsumerState<LocationView> {
  Timer? _pushTimer;
  ProviderSubscription? _locSub;
  String _mode = 'OFF'; // the viewer's current share mode, synced from data

  @override
  void initState() {
    super.initState();
    // React to upstream share-mode changes (server-side expiry, another session,
    // pull-to-refresh) OUTSIDE build so the push Timer is always reconciled.
    // Otherwise build could observe mode==OFF without stopping the Timer, and
    // the app would keep broadcasting live GPS after the server says you're not
    // sharing.
    _locSub = ref.listenManual(
      locationsProvider(widget.groupId),
      (_, next) => _applyData(next.valueOrNull),
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant LocationView old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _reconcilePushing();
  }

  @override
  void dispose() {
    _locSub?.close();
    _stopPushing();
    super.dispose();
  }

  void _applyData(List<LocationMember>? list) {
    if (!mounted) return;
    final mine = list?.firstWhere((l) => l.isOwn, orElse: () => LocationMember(userId: '', name: '', mode: 'OFF', isOwn: true));
    final newMode = mine?.mode ?? 'OFF';
    if (newMode != _mode) {
      _mode = newMode;
      _reconcilePushing();
    }
  }

  void _reconcilePushing() {
    if (widget.active && _mode != 'OFF') {
      _startPushing();
    } else {
      _stopPushing();
    }
  }

  Future<void> _setMode(String mode) async {
    _mode = mode;
    try {
      await ref.read(apiClientProvider).setLocationShare(widget.groupId, mode);
      ref.invalidate(locationsProvider(widget.groupId));
      if (!mounted) return;
      if (mode == 'OFF') {
        _stopPushing();
        toast(context, 'Location sharing off');
      } else {
        toast(context, 'Sharing your location');
        await _startPushing();
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _startPushing() async {
    _stopPushing();
    if (!widget.active) return; // never push while the tab is offscreen
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) toast(context, 'Enable device location to share live', error: true);
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) toast(context, 'Location permission denied', error: true);
      return;
    }
    await _pushOnce();
    _pushTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pushOnce());
  }

  void _stopPushing() {
    _pushTimer?.cancel();
    _pushTimer = null;
  }

  Future<void> _pushOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      await ref.read(apiClientProvider).pushLocation(widget.groupId, pos.latitude, pos.longitude);
      if (mounted) ref.invalidate(locationsProvider(widget.groupId));
    } catch (_) {
      // Best-effort: a transient failure is retried on the next tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(locationsProvider(widget.groupId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => OEmptyState(
        icon: Icons.error_outline,
        title: 'Couldn’t load',
        subtitle: e is ApiException ? e.message : '$e',
        action: TextButton(onPressed: () => ref.invalidate(locationsProvider(widget.groupId)), child: const Text('Retry')),
      ),
      data: (list) {
        final mine = list.firstWhere((l) => l.isOwn, orElse: () => LocationMember(userId: '', name: '', mode: 'OFF', isOwn: true));
        final sharing = mine.mode != 'OFF';
        return ListView(
          padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
          children: [
            if (sharing)
              Container(
                padding: const EdgeInsets.all(OrdoSpacing.md),
                margin: const EdgeInsets.only(bottom: OrdoSpacing.md),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(OrdoRadius.md)),
                child: const Row(children: [
                  Icon(Icons.visibility, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Your location is visible to this group.')),
                ]),
              ),
            OCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Share my location', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Off · Approximate · Precise (temporary). Approximate fuzzes your point.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
                  const SizedBox(height: OrdoSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(label: const Text('Off'), selected: mine.mode == 'OFF', onSelected: (_) => _setMode('OFF')),
                      ChoiceChip(label: const Text('Approximate'), selected: mine.mode == 'APPROXIMATE', onSelected: (_) => _setMode('APPROXIMATE')),
                      ChoiceChip(label: const Text('Precise'), selected: mine.mode == 'PRECISE_TEMPORARY', onSelected: (_) => _setMode('PRECISE_TEMPORARY')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: OrdoSpacing.lg),
            Text('Who’s sharing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSecondary, letterSpacing: 0.4)),
            const SizedBox(height: OrdoSpacing.sm),
            if (list.isEmpty)
              const OEmptyState(icon: Icons.location_on_outlined, title: 'Nobody is sharing', subtitle: 'Be the first to opt in.')
            else
              ...list.map((l) => _LocationMemberTile(l: l)),
          ],
        );
      },
    );
  }
}

class _LocationMemberTile extends StatelessWidget {
  final LocationMember l;
  const _LocationMemberTile({required this.l});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
      child: OCard(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
        child: Row(children: [
          CircleAvatar(child: Text(initials(l.name))),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.isOwn ? 'You' : l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (l.distanceMeters != null)
                  Text('${l.distanceMeters!.toStringAsFixed(0)} m away · ${l.mode}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary))
                else if (l.lat != null)
                  Text('${l.lat!.toStringAsFixed(3)}, ${l.lng!.toStringAsFixed(3)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary))
                else
                  Text('No point yet · ${l.mode}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
              ],
            ),
          ),
          if (l.isOwn && l.mode != 'OFF') OBadge(label: 'live', color: Colors.green),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ORDO COPILOT
// ════════════════════════════════════════════════════════════════════════════

class CopilotView extends ConsumerStatefulWidget {
  final String? groupId;
  const CopilotView({super.key, this.groupId});

  @override
  ConsumerState<CopilotView> createState() => _CopilotViewState();
}

class _CopilotViewState extends ConsumerState<CopilotView> {
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
    return Column(
      children: [
        Expanded(
          child: _lines.isEmpty
              ? OEmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'How can I help you plan?',
                  subtitle: '“Family dinner tomorrow at 8pm”\n“Remind Omar to bring the projector”',
                  action: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _planDay,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Plan my day'),
                  ),
                )
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
                IconButton(
                  tooltip: 'Plan my day',
                  onPressed: _busy ? null : _planDay,
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
                const SizedBox(width: OrdoSpacing.xs),
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
        child: line.suggestion != null ? _suggestionCard(line.suggestion!, cs, isUser) : Text(line.text ?? '', style: TextStyle(color: isUser ? cs.onPrimary : (line.error ? cs.error : cs.onSurface))),
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

// ════════════════════════════════════════════════════════════════════════════
// GROUP SETTINGS
// ════════════════════════════════════════════════════════════════════════════

class GroupSettingsView extends ConsumerStatefulWidget {
  final String groupId;
  const GroupSettingsView({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsView> createState() => _GroupSettingsViewState();
}

class _GroupSettingsViewState extends ConsumerState<GroupSettingsView> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _desc = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _canManage {
    final g = ref.read(groupDetailProvider(widget.groupId)).valueOrNull;
    return g?.role == 'ADMIN' || g?.role == 'OWNER';
  }

  bool get _isOwner => ref.read(groupDetailProvider(widget.groupId)).valueOrNull?.role == 'OWNER';

  Future<void> _save(GroupDetail g) async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateGroup(widget.groupId, {'name': _name.text.trim(), 'description': _desc.text.trim()});
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(groupsProvider);
      if (mounted) toast(context, 'Saved');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareInvite(GroupDetail g) async {
    try {
      final code = await ref.read(apiClientProvider).invite(widget.groupId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(OrdoSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Invite code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: OrdoSpacing.md),
                SelectableText(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: OrdoSpacing.sm),
                const Text('Share this code so others can join the group.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleModule(GroupDetail g, String key, bool value) async {
    try {
      await ref.read(apiClientProvider).updateGroup(widget.groupId, {'modules': {key: value}});
      ref.invalidate(groupDetailProvider(widget.groupId));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _leaveOrDelete(GroupDetail g, bool delete) async {
    final ok = await confirm(
      context,
      title: delete ? 'Delete group?' : 'Leave group?',
      message: delete ? 'This permanently deletes the group for everyone.' : 'You will no longer see this group.',
      confirmText: delete ? 'Delete' : 'Leave',
      danger: true,
    );
    if (!ok) return;
    try {
      if (delete) {
        await ref.read(apiClientProvider).deleteGroup(widget.groupId);
      } else {
        await ref.read(apiClientProvider).leaveGroup(widget.groupId);
      }
      ref.invalidate(groupsProvider);
      if (mounted) context.go('/groups');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(widget.groupId));
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => OEmptyState(
        icon: Icons.error_outline,
        title: 'Couldn’t load',
        subtitle: e is ApiException ? e.message : '$e',
        action: TextButton(onPressed: () => ref.invalidate(groupDetailProvider(widget.groupId)), child: const Text('Retry')),
      ),
      data: (g) {
        // Seed the controllers exactly once (see original note in group_settings_page).
        if (!_initialized) {
          _name.text = g.name;
          _desc.text = g.description ?? '';
          _initialized = true;
        }
        return ListView(
          padding: const EdgeInsets.all(OrdoSpacing.lg),
          children: [
            _sectionLabel(context, 'Identity'),
            OCard(
              child: Column(
                children: [
                  OField(label: 'Name', child: TextField(controller: _name, enabled: _canManage, decoration: _dec)),
                  const SizedBox(height: OrdoSpacing.md),
                  OField(label: 'Description', child: TextField(controller: _desc, enabled: _canManage, maxLines: 2, decoration: _dec)),
                  if (_canManage) ...[
                    const SizedBox(height: OrdoSpacing.md),
                    FilledButton(onPressed: _saving ? null : () => _save(g), child: const Text('Save changes')),
                  ],
                ],
              ),
            ),
            const SizedBox(height: OrdoSpacing.lg),
            _sectionLabel(context, 'Members & invites'),
            OCard(
              onTap: () => _shareInvite(g),
              child: Row(children: [
                const Icon(Icons.person_add_outlined),
                const SizedBox(width: OrdoSpacing.md),
                const Expanded(child: Text('Share invite code')),
                if (g.memberCount > 0) OBadge(label: '${g.memberCount} members'),
              ]),
            ),
            const SizedBox(height: OrdoSpacing.lg),
            _sectionLabel(context, 'Modules'),
            OCard(
              padding: const EdgeInsets.symmetric(vertical: OrdoSpacing.sm),
              child: Column(children: _moduleTiles(g)),
            ),
            const SizedBox(height: OrdoSpacing.xl),
            _sectionLabel(context, 'Danger zone'),
            OCard(
              bordered: true,
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    onPressed: () => _leaveOrDelete(g, false),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Leave group', style: TextStyle(color: Colors.red)),
                  ),
                  if (_isOwner)
                    TextButton.icon(
                      onPressed: () => _leaveOrDelete(g, true),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Delete group', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSecondary, letterSpacing: 0.4)),
      );

  List<Widget> _moduleTiles(GroupDetail g) {
    const modules = [
      ('timeline', 'Timeline', Icons.schedule_outlined),
      ('tasks', 'Tasks', Icons.task_outlined),
      ('todo', 'To-dos', Icons.check_circle_outline),
      ('chat', 'Chat', Icons.chat_bubble_outline),
      ('announcements', 'Announcements', Icons.campaign_outlined),
      ('polls', 'Polls', Icons.poll_outlined),
      ('files', 'Files', Icons.folder_outlined),
      ('location', 'Location', Icons.location_on_outlined),
      ('availability', 'Availability', Icons.event_available_outlined),
    ];
    return modules.map((m) {
      final key = m.$1;
      final enabled = (key == 'timeline' && g.modules.timeline) ||
          (key == 'tasks' && g.modules.tasks) ||
          (key == 'todo' && g.modules.todo) ||
          (key == 'chat' && g.modules.chat) ||
          (key == 'announcements' && g.modules.announcements) ||
          (key == 'polls' && g.modules.polls) ||
          (key == 'files' && g.modules.files) ||
          (key == 'location' && g.modules.location) ||
          (key == 'availability' && g.modules.availability);
      return SwitchListTile(
        value: enabled,
        onChanged: _canManage ? (v) => _toggleModule(g, key, v) : null,
        title: Text(m.$2),
        secondary: Icon(m.$3),
      );
    }).toList();
  }
}

const _dec = InputDecoration(border: OutlineInputBorder(), isDense: true);

// ════════════════════════════════════════════════════════════════════════════
// TASK CREATE SHEET
// ════════════════════════════════════════════════════════════════════════════

Future<void> showCreateTaskSheet(BuildContext context, GroupDetail group) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CreateTaskSheet(group: group),
  );
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  final GroupDetail group;
  const _CreateTaskSheet({required this.group});

  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _title = TextEditingController();
  String _priority = 'MEDIUM';
  DateTime? _due;
  final Set<String> _assigneeIds = {};
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, 'Add a title', error: true);
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.createTask({
        'groupId': widget.group.id,
        'title': title,
        'priority': _priority,
        if (_due != null) 'dueAt': _due!.toUtc().toIso8601String(),
        if (_assigneeIds.isNotEmpty) 'assigneeIds': _assigneeIds.toList(),
      });
      ref.invalidate(tasksProvider((groupId: widget.group.id, tab: 'all')));
      ref.invalidate(tasksProvider((groupId: widget.group.id, tab: 'mine')));
      ref.invalidate(groupDetailProvider(widget.group.id));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(OrdoSpacing.xl, 0, OrdoSpacing.xl, OrdoSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New task', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: OrdoSpacing.lg),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Task title'),
            ),
            const SizedBox(height: OrdoSpacing.md),
            OField(
              label: 'Priority',
              child: DropdownButton<String>(
                value: _priority,
                underline: const SizedBox(),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'LOW', child: Text('Low')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                  DropdownMenuItem(value: 'HIGH', child: Text('High')),
                  DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'MEDIUM'),
              ),
            ),
            const SizedBox(height: OrdoSpacing.md),
            OField(
              label: 'Due date',
              child: InkWell(
                borderRadius: BorderRadius.circular(OrdoRadius.md),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _due ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _due = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(isDense: true),
                  child: Text(
                    _due == null ? 'No due date' : fmtDateLong(_due!),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _due == null ? cs.onSecondary : cs.onSurface),
                  ),
                ),
              ),
            ),
            const SizedBox(height: OrdoSpacing.md),
            OField(
              label: 'Assignees',
              child: widget.group.members.isEmpty
                  ? Text('No members to assign', style: TextStyle(fontSize: 13, color: cs.onSecondary))
                  : Wrap(
                      spacing: OrdoSpacing.sm,
                      runSpacing: OrdoSpacing.sm,
                      children: [
                        for (final m in widget.group.members)
                          FilterChip(
                            label: Text(m.name),
                            selected: _assigneeIds.contains(m.userId),
                            avatar: OAvatar(name: m.name, imageUrl: m.avatarUrl, radius: 12),
                            onSelected: (sel) => setState(() {
                              if (sel) {
                                _assigneeIds.add(m.userId);
                              } else {
                                _assigneeIds.remove(m.userId);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: OrdoSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create task'),
            ),
          ],
        ),
      ),
    );
  }
}
