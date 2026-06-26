import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Single-scroll group creation form.
class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});
  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

/// Editable module entries (label, json key, initial value).
class _ModuleEntry {
  final String key;
  final String label;
  final IconData icon;
  const _ModuleEntry(this.key, this.label, this.icon);
}

const _moduleEntries = <_ModuleEntry>[
  _ModuleEntry('timeline', 'Timeline', Icons.view_timeline_outlined),
  _ModuleEntry('calendar', 'Calendar', Icons.calendar_month_outlined),
  _ModuleEntry('tasks', 'Tasks', Icons.task_outlined),
  _ModuleEntry('todo', 'To-do', Icons.checklist),
  _ModuleEntry('chat', 'Chat', Icons.chat_bubble_outline),
  _ModuleEntry('files', 'Files', Icons.folder_outlined),
  _ModuleEntry('location', 'Location', Icons.place_outlined),
  _ModuleEntry('announcements', 'Announcements', Icons.campaign_outlined),
  _ModuleEntry('media', 'Media', Icons.photo_outlined),
  _ModuleEntry('availability', 'Availability', Icons.event_available_outlined),
];

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  TemplateInfo? _template;
  String _accentColor = OrdoAccent.blue.name;
  final Map<String, bool> _modules = {for (final m in _moduleEntries) m.key: false};

  bool _saving = false;
  bool _appliedDefault = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _applyTemplate(TemplateInfo t) {
    setState(() {
      _template = t;
      _accentColor = t.accentColor;
      _modules
        ..['timeline'] = t.modules.timeline
        ..['calendar'] = t.modules.calendar
        ..['tasks'] = t.modules.tasks
        ..['todo'] = t.modules.todo
        ..['chat'] = t.modules.chat
        ..['files'] = t.modules.files
        ..['location'] = t.modules.location
        ..['announcements'] = t.modules.announcements
        ..['media'] = t.modules.media
        ..['availability'] = t.modules.availability;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Add a group name', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'type': _template?.type ?? 'CUSTOM',
        'accentColor': _accentColor,
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
        'modules': {
          'timeline': _modules['timeline'] ?? false,
          'calendar': _modules['calendar'] ?? false,
          'tasks': _modules['tasks'] ?? false,
          'todo': _modules['todo'] ?? false,
          'chat': _modules['chat'] ?? false,
          'files': _modules['files'] ?? false,
          'location': _modules['location'] ?? false,
          'members': true,
          'announcements': _modules['announcements'] ?? false,
          'polls': false,
          'media': _modules['media'] ?? false,
          'availability': _modules['availability'] ?? false,
        },
      };
      final group = await ref.read(apiClientProvider).createGroup(body);
      ref.invalidate(groupsProvider);
      if (mounted) context.go('/groups/${group.id}');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not create group. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesAsync = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/groups'),
        ),
        title: const Text('New group'),
      ),
      body: SafeArea(
        child: templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => OEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load templates',
            subtitle: e.toString(),
            action: FilledButton.icon(
              onPressed: () => ref.invalidate(templatesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
          data: (templates) {
            if (!_appliedDefault && templates.isNotEmpty) {
              _appliedDefault = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_template == null && mounted) _applyTemplate(templates.first);
              });
            }
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.md, OrdoSpacing.lg, OrdoSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Templates
                        OSectionHeader(title: 'Start from a template'),
                        SizedBox(
                          height: 108,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: templates.length,
                            separatorBuilder: (_, _) => const SizedBox(width: OrdoSpacing.sm),
                            itemBuilder: (_, i) {
                              final t = templates[i];
                              final selected = _template?.type == t.type;
                              final a = OrdoAccent.byName(t.accentColor);
                              return GestureDetector(
                                onTap: () => _applyTemplate(t),
                                child: Container(
                                  width: 132,
                                  padding: const EdgeInsets.all(OrdoSpacing.md),
                                  decoration: BoxDecoration(
                                    color: selected ? a.soft(isDark) : cs.surface,
                                    borderRadius: BorderRadius.circular(OrdoRadius.lg),
                                    border: Border.all(
                                      color: selected ? a.primary(isDark) : cs.outline,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.emoji, style: const TextStyle(fontSize: 26)),
                                      const Spacer(),
                                      Text(
                                        t.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: selected ? a.primary(isDark) : cs.onSurface),
                                      ),
                                      Text(
                                        t.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: cs.onSecondary, height: 1.25),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: OrdoSpacing.md),

                        OField(
                          label: 'Name',
                          child: TextField(
                            controller: _name,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(hintText: 'Group name'),
                          ),
                        ),
                        const SizedBox(height: OrdoSpacing.md),

                        OField(
                          label: 'Description (optional)',
                          child: TextField(
                            controller: _description,
                            minLines: 1,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(hintText: 'What is this group about?'),
                          ),
                        ),
                        const SizedBox(height: OrdoSpacing.lg),

                        // Accent color
                        OSectionHeader(title: 'Accent color'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.sm),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final a in OrdoAccent.all)
                                GestureDetector(
                                  onTap: () => setState(() => _accentColor = a.name),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: a.primary(isDark),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _accentColor == a.name ? cs.onSurface : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: _accentColor == a.name ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: OrdoSpacing.lg),

                        // Modules
                        OSectionHeader(title: 'Modules'),
                        for (final m in _moduleEntries)
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.sm),
                            dense: true,
                            title: Row(
                              children: [
                                Icon(m.icon, size: 20, color: cs.onSecondary),
                                const SizedBox(width: OrdoSpacing.md),
                                Text(m.label),
                              ],
                            ),
                            value: _modules[m.key] ?? false,
                            onChanged: (v) => setState(() => _modules[m.key] = v),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.lg),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create group'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
