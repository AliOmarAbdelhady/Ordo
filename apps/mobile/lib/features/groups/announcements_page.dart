import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

class AnnouncementsPage extends ConsumerWidget {
  final String groupId;
  const AnnouncementsPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreate(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Couldn’t load', subtitle: '$e', action: TextButton(onPressed: () => ref.invalidate(announcementsProvider(groupId)), child: const Text('Retry'))),
        data: (list) {
          if (list.isEmpty) return const OEmptyState(icon: Icons.campaign_outlined, title: 'No announcements', subtitle: 'Pin an important update for the group.');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(announcementsProvider(groupId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(OrdoSpacing.lg),
              itemCount: list.length,
              itemBuilder: (_, i) => _Card(a: list[i], onDelete: () async {
                final ok = await confirm(context, title: 'Delete announcement?', danger: true);
                if (!ok) return;
                try {
                  await ref.read(apiClientProvider).deleteAnnouncement(list[i].id);
                  ref.invalidate(announcementsProvider(groupId));
                } on ApiException catch (e) {
                  if (context.mounted) toast(context, e.message, error: true);
                }
              }),
            ),
          );
        },
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    final title = TextEditingController();
    final body = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.lg, MediaQuery.of(ctx).viewInsets.bottom + OrdoSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('New announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: OrdoSpacing.md),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: OrdoSpacing.sm),
              TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder())),
              const SizedBox(height: OrdoSpacing.sm),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty || body.text.trim().isEmpty) { toast(ctx, 'Title and body are required', error: true); return; }
                  try {
                    await ref.read(apiClientProvider).createAnnouncement(groupId, title.text.trim(), body.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(announcementsProvider(groupId));
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
}

class _Card extends StatelessWidget {
  final Announcement a;
  final VoidCallback onDelete;
  const _Card({required this.a, required this.onDelete});

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
