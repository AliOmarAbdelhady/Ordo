import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Full group settings: identity (name/description/accent), enabled modules,
/// invite sharing, and the danger zone (leave / delete). Replaces the previous
/// "Coming soon" placeholder. Only admins can save identity changes; the owner
/// can delete.
class GroupSettingsPage extends ConsumerStatefulWidget {
  final String groupId;
  const GroupSettingsPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  bool _saving = false;

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
      await ref.read(apiClientProvider).updateGroup(widget.groupId, {
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
      });
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
      await ref.read(apiClientProvider).updateGroup(widget.groupId, {
        'modules': {key: value},
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Couldn’t load', subtitle: '$e', action: TextButton(onPressed: () => ref.invalidate(groupDetailProvider(widget.groupId)), child: const Text('Retry'))),
        data: (g) {
          if (_name.text.isEmpty) {
            _name.text = g.name;
            _desc.text = g.description ?? '';
          }
          return ListView(
            padding: const EdgeInsets.all(OrdoSpacing.lg),
            children: [
              _sectionLabel('Identity'),
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
              _sectionLabel('Members & invites'),
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
              _sectionLabel('Modules'),
              OCard(
                padding: const EdgeInsets.symmetric(vertical: OrdoSpacing.sm),
                child: Column(children: _moduleTiles(g)),
              ),
              const SizedBox(height: OrdoSpacing.xl),
              _sectionLabel('Danger zone'),
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
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
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
