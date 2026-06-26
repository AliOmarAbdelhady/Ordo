import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import '../timeline/add_block_sheet.dart';

/// A group's command center. Internal tabs (Home / Timeline / Tasks / Members)
/// are shown based on the group's enabled modules; Home is always present.
class GroupHomePage extends ConsumerStatefulWidget {
  final String groupId;
  const GroupHomePage({super.key, required this.groupId});

  @override
  ConsumerState<GroupHomePage> createState() => _GroupHomePageState();
}

enum _Tab { home, timeline, tasks, members }

class _GroupHomePageState extends ConsumerState<GroupHomePage> {
  _Tab _tab = _Tab.home;
  bool _mutating = false;

  String get _gid => widget.groupId;

  List<_Tab> _tabsFor(GroupDetail g) {
    final tabs = <_Tab>[_Tab.home];
    if (g.modules.timeline) tabs.add(_Tab.timeline);
    if (g.modules.tasks) tabs.add(_Tab.tasks);
    if (g.modules.members) tabs.add(_Tab.members);
    return tabs;
  }

  String _tabLabel(_Tab t) => const {
        _Tab.home: 'Home',
        _Tab.timeline: 'Timeline',
        _Tab.tasks: 'Tasks',
        _Tab.members: 'Members',
      }[t]!;

  Future<void> _refresh() async {
    ref.invalidate(groupDetailProvider(_gid));
    ref.invalidate(groupsProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh on focus / first build.
    ref.invalidate(groupDetailProvider(_gid));
  }

  Future<void> _shareInvite() async {
    setState(() => _mutating = true);
    try {
      final code = await ref.read(apiClientProvider).invite(_gid);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invite members'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share this code so others can join the group.'),
              const SizedBox(height: OrdoSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(OrdoRadius.md),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                toast(context, 'Invite code copied');
              },
              child: const Text('Copy'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _togglePin(GroupDetail g) async {
    setState(() => _mutating = true);
    try {
      await ref.read(apiClientProvider).setPinned(_gid, !g.pinned);
      ref.invalidate(groupDetailProvider(_gid));
      ref.invalidate(groupsProvider);
      if (mounted) toast(context, g.pinned ? 'Unpinned' : 'Pinned to top');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _leave(GroupDetail g) async {
    final ok = await confirm(
      context,
      title: 'Leave "${g.name}"?',
      message: 'You will no longer have access to this group. This cannot be undone.',
      confirmText: 'Leave',
      danger: true,
    );
    if (!ok) return;
    setState(() => _mutating = true);
    try {
      await ref.read(apiClientProvider).leaveGroup(_gid);
      ref.invalidate(groupsProvider);
      if (mounted) context.go('/groups');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _openMenu(GroupDetail g) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Share invite'),
              onTap: () {
                Navigator.pop(ctx);
                _shareInvite();
              },
            ),
            ListTile(
              leading: Icon(g.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(g.pinned ? 'Unpin group' : 'Pin to top'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(g);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/groups/$_gid/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.apps_outlined),
              title: const Text('More (polls, files, location, AI)'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/groups/$_gid/more');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(ctx).colorScheme.error),
              title: Text('Leave group', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _leave(g);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(_gid));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/groups');
            }
          },
        ),
        title: const Text('Group'),
        actions: [
          IconButton(
            icon: _mutating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_outlined),
            onPressed: _mutating ? null : _refresh,
          ),
        ],
      ),
      body: detail.when(
        loading: () => const _BodySkeleton(),
        error: (e, _) => OEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load group',
          subtitle: e is ApiException ? e.message : 'Try again in a moment.',
          action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
        ),
        data: (g) {
          final tabs = _tabsFor(g);
          // Clamp the selected tab to one that exists.
          if (!tabs.contains(_tab)) _tab = _Tab.home;
          return Column(
            children: [
              _Header(group: g, onMenu: () => _openMenu(g)),
              _TabBar(
                tabs: tabs,
                selected: _tab,
                label: _tabLabel,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: _buildTab(g),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTab(GroupDetail g) {
    switch (_tab) {
      case _Tab.home:
        return _HomeTab(group: g, onSwitchTab: (t) => setState(() => _tab = t));
      case _Tab.timeline:
        return _TimelineTab(groupId: _gid);
      case _Tab.tasks:
        return _TasksTab(group: g);
      case _Tab.members:
        return _MembersTab(group: g);
    }
  }
}

// ── Header card ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final GroupDetail group;
  final VoidCallback onMenu;
  const _Header({required this.group, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = OrdoAccent.byName(group.accentColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final memberNames = group.members.map((m) => m.name).toList();
    final memberImages = group.members.map((m) => m.avatarUrl).toList();

    return OCard(
      color: accent.soft(isDark),
      bordered: false,
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.md, OrdoSpacing.lg, OrdoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OGroupAvatar(name: group.name, accent: group.accentColor, size: 52),
              const SizedBox(width: OrdoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (group.description != null && group.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        group.description!,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.8), height: 1.35),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: onMenu,
                tooltip: 'Group actions',
              ),
            ],
          ),
          const SizedBox(height: OrdoSpacing.md),
          Row(
            children: [
              if (memberNames.isNotEmpty)
                OAvatarStack(names: memberNames, images: memberImages, radius: 14)
              else
                Text('No members yet', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(width: OrdoSpacing.sm),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: OrdoSpacing.sm,
                  runSpacing: 4,
                  children: [
                    OBadge(
                      label: '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                      icon: Icons.people_outline,
                    ),
                    OBadge(
                      label: group.role,
                      color: accent.primary(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab bar (segmented) ──────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final List<_Tab> tabs;
  final _Tab selected;
  final String Function(_Tab) label;
  final ValueChanged<_Tab> onChanged;
  const _TabBar({required this.tabs, required this.selected, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.sm),
      child: OSegmented<_Tab>(
        segments: tabs,
        value: selected,
        label: label,
        onChanged: onChanged,
      ),
    );
  }
}

// ── Home tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  final GroupDetail group;
  final ValueChanged<_Tab> onSwitchTab;
  const _HomeTab({required this.group, required this.onSwitchTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final from = startOfDay(now);
    final to = addDays(from, 7);
    final accent = OrdoAccent.byName(group.accentColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final timeline = ref.watch(groupTimelineProvider((groupId: group.id, from: from, to: to)));
    final nowTs = DateTime.now();
    final nextUp = [...?timeline.valueOrNull?.items]
      ..retainWhere((i) => i.startTime.isAfter(nowTs) || i.startTime.isAtSameMomentAs(nowTs))
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final TimelineItem? nearest = nextUp.isNotEmpty ? nextUp.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
      children: [
        // Next event / nearest block
        OSectionHeader(title: 'Up next'),
        if (group.nextEvent != null)
          _NextEventCard(
            title: group.nextEvent!.title,
            when: group.nextEvent!.startTime,
            accent: accent.primary(isDark),
          )
        else if (timeline.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (nearest != null)
          _NextEventCard(
            title: nearest.isBusy ? 'Busy' : nearest.title,
            when: nearest.startTime,
            end: nearest.endTime,
            location: (!nearest.redacted && !nearest.isBusy) ? nearest.location : null,
            muted: nearest.isBusy,
            accent: nearest.color,
          )
        else
          OCard(
            onTap: group.modules.timeline
                ? () => showAddBlockSheet(context, ref, groupId: group.id)
                : null,
            child: Row(
              children: [
                Icon(Icons.event_available_outlined, color: accent.primary(isDark)),
                const SizedBox(width: OrdoSpacing.md),
                Expanded(
                  child: Text(
                    group.modules.timeline ? 'No upcoming events. Add one?' : 'No upcoming events.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: OrdoSpacing.md),

        // Quick actions grid
        OSectionHeader(title: 'Quick actions'),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.search,
                label: 'Find free time',
                accent: accent.primary(isDark),
                onTap: () => context.push('/find-slot?groupId=${group.id}'),
              ),
            ),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: _ActionTile(
                icon: Icons.task_alt,
                label: 'Tasks',
                badge: group.pendingTaskCount > 0 ? '${group.pendingTaskCount}' : null,
                accent: accent.primary(isDark),
                onTap: group.modules.tasks ? () => onSwitchTab(_Tab.tasks) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: OrdoSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                badge: group.unreadCount > 0 ? '${group.unreadCount}' : null,
                accent: accent.primary(isDark),
                onTap: group.modules.chat ? () => context.push('/groups/${group.id}/chat') : null,
              ),
            ),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: _ActionTile(
                icon: Icons.people_outline,
                label: 'Members',
                accent: accent.primary(isDark),
                onTap: group.modules.members ? () => onSwitchTab(_Tab.members) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: OrdoSpacing.md),

        if (group.modules.chat && group.unreadCount > 0)
          OCard(
            onTap: () => context.push('/groups/${group.id}/chat'),
            padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.md),
            child: Row(
              children: [
                Icon(Icons.mark_chat_unread_outlined, color: accent.primary(isDark)),
                const SizedBox(width: OrdoSpacing.md),
                Expanded(
                  child: Text(
                    '${group.unreadCount} unread ${group.unreadCount == 1 ? 'message' : 'messages'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
      ],
    );
  }
}

class _NextEventCard extends StatelessWidget {
  final String title;
  final DateTime when;
  final DateTime? end;
  final String? location;
  final bool muted;
  final Color accent;
  const _NextEventCard({
    required this.title,
    required this.when,
    this.end,
    this.location,
    this.muted = false,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr = end != null ? fmtRange(when, end!) : fmtTime(when);
    return OCard(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(OrdoRadius.md)),
                    child: Icon(muted ? Icons.lock_outline : Icons.event_outlined, color: accent, size: 20),
                  ),
                  const SizedBox(width: OrdoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: muted ? cs.onSecondary : cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: OrdoSpacing.sm,
                          children: [
                            Text('${dayLabel(when)} · $timeStr', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
                            if (location != null) ...[
                              ODot(accent.withValues(alpha: 0.6), size: 4),
                              Text(location!, style: TextStyle(fontSize: 12, color: cs.onSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
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
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color accent;
  final VoidCallback? onTap;
  const _ActionTile({required this.icon, required this.label, this.badge, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    final color = disabled ? cs.onSecondary : accent;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: OCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: OrdoSpacing.lg),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(OrdoRadius.pill)),
                      child: Text(
                        badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: OrdoSpacing.sm),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ── Timeline tab ─────────────────────────────────────────────────────────────

class _TimelineTab extends ConsumerStatefulWidget {
  final String groupId;
  const _TimelineTab({required this.groupId});

  @override
  ConsumerState<_TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends ConsumerState<_TimelineTab> {
  DateTime _weekStart = startOfWeek(DateTime.now());

  ({DateTime from, DateTime to}) get _range => (from: _weekStart, to: addDays(_weekStart, 7));

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(groupTimelineProvider((groupId: widget.groupId, from: _range.from, to: _range.to)));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = OrdoAccent.byName(ref.read(groupDetailProvider(widget.groupId)).valueOrNull?.accentColor ?? 'blue');

    return Column(
      children: [
        // Week navigator
        Padding(
          padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _weekStart = addDays(_weekStart, -7)),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${fmtDate(_range.from)} – ${fmtDate(addDays(_range.from, 6))}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _weekStart = addDays(_weekStart, 7)),
              ),
              TextButton(
                onPressed: () => setState(() => _weekStart = startOfWeek(DateTime.now())),
                child: const Text('Today'),
              ),
            ],
          ),
        ),
        Expanded(child: res.when(
          loading: () => const _ListSkeleton(),
          error: (e, _) => OEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load timeline',
            subtitle: e is ApiException ? e.message : null,
          ),
          data: (data) {
            final items = [...data.items]..sort((a, b) => a.startTime.compareTo(b.startTime));
            if (items.isEmpty) {
              return OEmptyState(
                icon: Icons.event_outlined,
                title: 'Nothing scheduled',
                subtitle: 'Add a group event to get everyone in sync.',
                action: FilledButton.icon(
                  onPressed: () => showAddBlockSheet(context, ref, groupId: widget.groupId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add event'),
                ),
              );
            }
            return Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, 0, OrdoSpacing.lg, 96),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final showDayHeader = i == 0 || !isSameDay(items[i - 1].startTime, it.startTime);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDayHeader) ...[
                          if (i > 0) const SizedBox(height: OrdoSpacing.md),
                          Padding(
                            padding: const EdgeInsets.only(top: OrdoSpacing.sm, bottom: OrdoSpacing.xs),
                            child: Text(
                              dayLabel(it.startTime),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent.primary(isDark)),
                            ),
                          ),
                        ],
                        _TimelineTile(item: it),
                      ],
                    );
                  },
                ),
                Positioned(
                  right: OrdoSpacing.lg,
                  bottom: OrdoSpacing.lg,
                  child: FloatingActionButton(
                    heroTag: 'groupAddEvent',
                    mini: true,
                    backgroundColor: accent.primary(isDark),
                    foregroundColor: Colors.white,
                    onPressed: () => showAddBlockSheet(context, ref, groupId: widget.groupId),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            );
          },
        )),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final TimelineItem item;
  const _TimelineTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final busy = item.isBusy;
    final titleOnly = item.redacted && !busy;
    final full = !item.redacted && !busy;

    final title = busy ? 'Busy' : item.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
      child: OCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: busy ? cs.onSecondary : item.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (busy) ...[
                                  Icon(Icons.lock_outline, size: 14, color: cs.onSecondary),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: busy ? cs.onSecondary : cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.allDay ? 'All day' : '${fmtTime(item.startTime)} – ${fmtTime(item.endTime)}',
                              style: TextStyle(fontSize: 12, color: cs.onSecondary),
                            ),
                            if (full && item.location != null && item.location!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.place_outlined, size: 12, color: cs.onSecondary),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      item.location!,
                                      style: TextStyle(fontSize: 12, color: cs.onSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (full && item.description != null && item.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.description!,
                                style: TextStyle(fontSize: 12, color: cs.onSecondary, height: 1.35),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (titleOnly)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('Private details hidden', style: TextStyle(fontSize: 11, color: cs.onSecondary)),
                              ),
                          ],
                        ),
                      ),
                      if (item.isEvent)
                        OBadge(label: 'Event', color: busy ? cs.onSecondary : item.color),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tasks tab ────────────────────────────────────────────────────────────────

class _TasksTab extends ConsumerStatefulWidget {
  final GroupDetail group;
  const _TasksTab({required this.group});

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
  String _tab = 'all'; // 'all' | 'mine'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final me = ref.read(authControllerProvider).valueOrNull;
    final accent = OrdoAccent.byName(widget.group.accentColor);

    final res = ref.watch(tasksProvider((groupId: widget.group.id, tab: _tab)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: OSegmented<String>(
                  height: 36,
                  segments: const ['all', 'mine'],
                  value: _tab,
                  label: (t) => t == 'all' ? 'All' : 'Mine',
                  onChanged: (t) {
                    setState(() => _tab = t);
                    ref.invalidate(tasksProvider((groupId: widget.group.id, tab: t)));
                  },
                ),
              ),
              const SizedBox(width: OrdoSpacing.sm),
              FloatingActionButton(
                heroTag: 'groupAddTask',
                mini: true,
                backgroundColor: accent.primary(isDark),
                foregroundColor: Colors.white,
                onPressed: () => _showCreateTask(),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: res.when(
            loading: () => const _ListSkeleton(),
            error: (e, _) => OEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load tasks',
              subtitle: e is ApiException ? e.message : null,
            ),
            data: (tasks) {
              if (tasks.isEmpty) {
                return OEmptyState(
                  icon: Icons.task_alt,
                  title: _tab == 'mine' ? 'No tasks assigned to you' : 'No tasks yet',
                  subtitle: 'Create one to keep the group on track.',
                  action: FilledButton.icon(
                    onPressed: () => _showCreateTask(),
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, 0, OrdoSpacing.lg, OrdoSpacing.xxl),
                itemCount: tasks.length,
                itemBuilder: (_, i) {
                  final t = tasks[i];
                  final assignedToMe = me != null && t.assignees.any((a) => a.id == me.id);
                  return _TaskCard(task: t, accent: accent.primary(isDark), assignedToMe: assignedToMe);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateTask() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CreateTaskSheet(group: widget.group, ref: ref),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final Color accent;
  final bool assignedToMe;
  const _TaskCard({required this.task, required this.accent, this.assignedToMe = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pColor = priorityColor(task.priority, isDark);
    final done = task.status == 'DONE';

    return OCard(
      onTap: () => context.push('/tasks/${task.id}'),
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: done ? cs.onSecondary : pColor, width: 2),
              color: done ? cs.onSecondary.withValues(alpha: 0.3) : Colors.transparent,
            ),
            child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? cs.onSecondary : cs.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: OrdoSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OBadge(label: task.priority, color: pColor),
                    if (task.dueAt != null) ...[
                      OBadge(
                        label: dayLabel(task.dueAt!),
                        icon: Icons.calendar_today_outlined,
                      ),
                    ],
                    if (task.commentCount > 0)
                      OBadge(label: '${task.commentCount}', icon: Icons.chat_bubble_outline),
                    if (assignedToMe)
                      OBadge(label: 'Mine', color: accent),
                  ],
                ),
                if (task.assignees.isNotEmpty) ...[
                  const SizedBox(height: OrdoSpacing.sm),
                  OAvatarStack(
                    names: task.assignees.map((a) => a.name).toList(),
                    images: task.assignees.map((a) => a.avatarUrl).toList(),
                    radius: 11,
                    max: 5,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  final GroupDetail group;
  final WidgetRef ref;
  const _CreateTaskSheet({required this.group, required this.ref});

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
    final api = widget.ref.read(apiClientProvider);
    try {
      await api.createTask({
        'groupId': widget.group.id,
        'title': title,
        'priority': _priority,
        if (_due != null) 'dueAt': _due!.toUtc().toIso8601String(),
        if (_assigneeIds.isNotEmpty) 'assigneeIds': _assigneeIds.toList(),
      });
      widget.ref.invalidate(tasksProvider((groupId: widget.group.id, tab: 'all')));
      widget.ref.invalidate(tasksProvider((groupId: widget.group.id, tab: 'mine')));
      widget.ref.invalidate(groupDetailProvider(widget.group.id));
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _due == null ? cs.onSecondary : cs.onSurface,
                    ),
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

// ── Members tab ──────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerStatefulWidget {
  final GroupDetail group;
  const _MembersTab({required this.group});

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  bool _busy = false;

  bool get _canManage => widget.group.role == 'OWNER' || widget.group.role == 'ADMIN';

  Future<void> _changeRole(GroupMember m) async {
    final options = const ['MEMBER', 'ADMIN'];
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Change role for ${m.name}'),
        children: [
          for (final r in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(r == m.role ? '$r (current)' : r),
            ),
        ],
      ),
    );
    if (chosen == null || chosen == m.role) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).updateMemberRole(widget.group.id, m.id, chosen);
      ref.invalidate(groupDetailProvider(widget.group.id));
      ref.invalidate(groupMembersProvider(widget.group.id));
      if (mounted) toast(context, 'Role updated');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(GroupMember m) async {
    final ok = await confirm(
      context,
      title: 'Remove ${m.name}?',
      message: 'They will lose access to this group.',
      confirmText: 'Remove',
      danger: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).removeMember(widget.group.id, m.id);
      ref.invalidate(groupDetailProvider(widget.group.id));
      ref.invalidate(groupMembersProvider(widget.group.id));
      ref.invalidate(groupsProvider);
      if (mounted) toast(context, '${m.name} removed');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = [...widget.group.members]
      ..sort((a, b) {
        const rank = {'OWNER': 0, 'ADMIN': 1, 'MEMBER': 2};
        final ra = rank[a.role] ?? 3;
        final rb = rank[b.role] ?? 3;
        if (ra != rb) return ra.compareTo(rb);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (members.isEmpty) {
      return OEmptyState(
        icon: Icons.people_outline,
        title: 'No members',
        subtitle: 'Invite people from the group menu.',
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
          itemCount: members.length,
          itemBuilder: (_, i) {
            final m = members[i];
            final roleColor = m.role == 'OWNER'
                ? OrdoAccent.amber.light
                : m.role == 'ADMIN'
                    ? (isDark ? OrdoAccent.cyan.dark : OrdoAccent.cyan.light)
                    : cs.onSecondary;
            final isSelf = widget.group.role == m.role && m.userId == ref.read(authControllerProvider).valueOrNull?.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
              child: OCard(
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm + 2),
                child: Row(
                  children: [
                    OAvatar(name: m.name, imageUrl: m.avatarUrl, radius: 20),
                    const SizedBox(width: OrdoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Joined ${fmtDate(m.joinedAt)}',
                            style: TextStyle(fontSize: 12, color: cs.onSecondary),
                          ),
                        ],
                      ),
                    ),
                    OBadge(label: m.role, color: roleColor),
                    if (_canManage && !isSelf)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (v) {
                          if (v == 'role') {
                            _changeRole(m);
                          } else if (v == 'remove') {
                            _remove(m);
                          }
                        },
                        itemBuilder: (_) => [
                          // MEMBER_ROLE_UPDATE is OWNER-only server-side; hide the
                          // option from ADMINs so they're never offered an action
                          // that would 403. (MEMBER_REMOVE is ADMIN-level, so the
                          // menu still shows to ADMINs for Remove.)
                          if (widget.group.role == 'OWNER')
                            const PopupMenuItem(value: 'role', child: Text('Change role')),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove', style: TextStyle(color: cs.error)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_busy)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

// ── Skeletons ────────────────────────────────────────────────────────────────

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();
  @override
  Widget build(BuildContext context) {
    return OSkeletonBox(
      ListView(
        padding: const EdgeInsets.all(OrdoSpacing.lg),
        children: [
          const OSkeleton(height: 120, radius: OrdoRadius.lg),
          const SizedBox(height: OrdoSpacing.md),
          const OSkeleton(height: 38, radius: OrdoRadius.md),
          const SizedBox(height: OrdoSpacing.lg),
          for (int i = 0; i < 4; i++) ...[
            const OSkeleton(height: 64, radius: OrdoRadius.lg),
            const SizedBox(height: OrdoSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();
  @override
  Widget build(BuildContext context) {
    return OSkeletonBox(
      ListView(
        padding: const EdgeInsets.all(OrdoSpacing.lg),
        children: [
          for (int i = 0; i < 5; i++) ...[
            const OSkeleton(height: 70, radius: OrdoRadius.lg),
            const SizedBox(height: OrdoSpacing.sm),
          ],
        ],
      ),
    );
  }
}
