import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

/// Launchpad for the secondary group modules (polls, announcements, files,
/// location) plus the group-scoped AI assistant. Each module only appears when
/// the group has it enabled.
class GroupMorePage extends ConsumerWidget {
  final String groupId;
  const GroupMorePage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Couldn’t load', subtitle: '$e'),
        data: (g) {
          final entries = <_Entry>[
            if (g.modules.polls) _Entry('Polls', Icons.poll_outlined, '/groups/$groupId/polls'),
            if (g.modules.announcements) _Entry('Announcements', Icons.campaign_outlined, '/groups/$groupId/announcements'),
            if (g.modules.files) _Entry('Files', Icons.folder_outlined, '/groups/$groupId/files'),
            if (g.modules.location) _Entry('Location', Icons.location_on_outlined, '/groups/$groupId/location'),
            _Entry('Ordo Copilot', Icons.auto_awesome_outlined, '/assistant?groupId=$groupId'),
            _Entry('Group settings', Icons.settings_outlined, '/groups/$groupId/settings'),
          ];
          return ListView.builder(
            padding: const EdgeInsets.all(OrdoSpacing.lg),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
                child: _Card(title: e.title, icon: e.icon, onTap: () => context.push(e.route)),
              );
            },
          );
        },
      ),
    );
  }
}

class _Entry {
  final String title;
  final IconData icon;
  final String route;
  _Entry(this.title, this.icon, this.route);
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _Card({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(OrdoRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OrdoRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(OrdoSpacing.md),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(OrdoRadius.lg), border: Border.all(color: Theme.of(context).colorScheme.outline)),
          child: Row(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}
