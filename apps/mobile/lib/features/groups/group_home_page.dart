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
import 'group_views.dart';

/// A group's command center. Every enabled module is a swipeable tab
/// (Home / Timeline / Tasks / Members / Polls / Announcements / Files /
/// Location / Copilot / Settings). Home surfaces a "what's new" feed; the
/// floating action button is contextual to the active tab so you can create
/// from anywhere. Chat stays secondary — an AppBar action, not a tab.
class GroupHomePage extends ConsumerStatefulWidget {
  final String groupId;
  const GroupHomePage({super.key, required this.groupId});

  @override
  ConsumerState<GroupHomePage> createState() => _GroupHomePageState();
}

/// Every module that can appear as a tab. Order here is the strip order.
enum GroupTab {
  home('Home', Icons.home_outlined),
  timeline('Timeline', Icons.calendar_view_week_outlined),
  tasks('Tasks', Icons.task_alt_outlined),
  members('Members', Icons.people_outline),
  polls('Polls', Icons.poll_outlined),
  announcements('News', Icons.campaign_outlined),
  files('Files', Icons.folder_outlined),
  location('Map', Icons.location_on_outlined),
  copilot('Copilot', Icons.auto_awesome_outlined),
  settings('Settings', Icons.settings_outlined);

  final String label;
  final IconData icon;
  const GroupTab(this.label, this.icon);
}

class _GroupHomePageState extends ConsumerState<GroupHomePage> with TickerProviderStateMixin {
  TabController? _ctrl;
  int _lastIndex = 0;
  List<GroupTab>? _lastTabs;
  bool _mutating = false;

  String get _gid => widget.groupId;

  List<GroupTab> _tabsFor(GroupDetail g) {
    return [
      GroupTab.home,
      if (g.modules.timeline) GroupTab.timeline,
      if (g.modules.tasks) GroupTab.tasks,
      if (g.modules.members) GroupTab.members,
      if (g.modules.polls) GroupTab.polls,
      if (g.modules.announcements) GroupTab.announcements,
      if (g.modules.files) GroupTab.files,
      if (g.modules.location) GroupTab.location,
      GroupTab.copilot,
      GroupTab.settings,
    ];
  }

  /// (Re)create the TabController only when the tab count changes — which
  /// happens once after the group loads, and again only if a module is toggled
  /// in Settings. We preserve the semantic TAB the user was on (not its numeric
  /// index): toggling a module that sits *before* the active tab would otherwise
  /// shift everything left and silently land the user on a different tab.
  void _ensureController(List<GroupTab> newTabs) {
    if (newTabs.isEmpty) return;
    final length = newTabs.length;
    if (_ctrl != null && _ctrl!.length == length) {
      _lastTabs = newTabs;
      return;
    }
    GroupTab? keep;
    final old = _lastTabs;
    if (old != null && _lastIndex < old.length) keep = old[_lastIndex];
    final initial = (keep != null && newTabs.contains(keep)) ? newTabs.indexOf(keep) : _lastIndex.clamp(0, length - 1);
    _ctrl?.removeListener(_onTabChanged);
    _ctrl?.dispose();
    _ctrl = TabController(length: length, vsync: this, initialIndex: initial);
    _ctrl!.addListener(_onTabChanged);
    _lastIndex = _ctrl!.index;
    _lastTabs = newTabs;
  }

  void _onTabChanged() {
    final c = _ctrl;
    if (c == null) return;
    // Only react once the swipe/settle is complete, and only on real changes —
    // the guard prevents a setState → listener → setState rebuild loop.
    if (!c.indexIsChanging && c.index != _lastIndex) {
      _lastIndex = c.index;
      setState(() {});
    }
  }

  bool _isTabActive(GroupTab tab, List<GroupTab> tabs) {
    final c = _ctrl;
    if (c == null || c.index >= tabs.length) return false;
    return tabs[c.index] == tab;
  }

  void _jumpTo(GroupTab tab) {
    final c = _ctrl;
    final g = ref.read(groupDetailProvider(_gid)).valueOrNull;
    if (c == null || g == null) return;
    final tabs = _tabsFor(g);
    final i = tabs.indexOf(tab);
    if (i >= 0) c.animateTo(i);
  }

  Future<void> _refresh() async {
    final g = ref.read(groupDetailProvider(_gid)).valueOrNull;
    ref.invalidate(groupDetailProvider(_gid));
    ref.invalidate(groupsProvider);
    if (g != null) _invalidateActiveTab(g);
  }

  void _invalidateActiveTab(GroupDetail g) {
    final c = _ctrl;
    if (c == null) return;
    final tabs = _tabsFor(g);
    if (c.index >= tabs.length) return;
    switch (tabs[c.index]) {
      case GroupTab.tasks:
        ref.invalidate(tasksProvider((groupId: _gid, tab: 'all')));
        ref.invalidate(tasksProvider((groupId: _gid, tab: 'mine')));
      case GroupTab.polls:
        ref.invalidate(pollsProvider(_gid));
      case GroupTab.announcements:
        ref.invalidate(announcementsProvider(_gid));
      case GroupTab.files:
        ref.invalidate(mediaProvider(_gid));
      case GroupTab.location:
        ref.invalidate(locationsProvider(_gid));
      default:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh on focus / first build.
    ref.invalidate(groupDetailProvider(_gid));
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onTabChanged);
    _ctrl?.dispose();
    super.dispose();
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3, color: Theme.of(ctx).colorScheme.primary),
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

  FloatingActionButton? _buildFab(GroupDetail g, List<GroupTab> tabs) {
    final c = _ctrl;
    if (c == null || c.index >= tabs.length) return null;
    final accent = OrdoAccent.byName(g.accentColor).primary(Theme.of(context).brightness == Brightness.dark);

    FloatingActionButton fab(VoidCallback onTap, IconData icon) => FloatingActionButton(
          heroTag: 'groupHostFab',
          backgroundColor: accent,
          foregroundColor: Colors.white,
          onPressed: onTap,
          child: Icon(icon),
        );
    switch (tabs[c.index]) {
      case GroupTab.timeline:
        return fab(() => showAddBlockSheet(context, ref, groupId: _gid), Icons.add);
      case GroupTab.tasks:
        return fab(() => showCreateTaskSheet(context, g), Icons.add);
      case GroupTab.polls:
        return fab(() => showCreatePollSheet(context, ref, _gid), Icons.add);
      case GroupTab.announcements:
        return fab(() => showCreateAnnouncementSheet(context, ref, _gid), Icons.add);
      case GroupTab.files:
        return fab(() => pickGroupFile(context, ref, _gid), Icons.upload_file);
      default:
        return null;
    }
  }

  Widget _buildTab(GroupDetail g, GroupTab t) {
    final tabs = _tabsFor(g);
    switch (t) {
      case GroupTab.home:
        return _HomeTab(group: g, onJumpTo: _jumpTo);
      case GroupTab.timeline:
        return _TimelineTab(groupId: _gid);
      case GroupTab.tasks:
        return _TasksTab(group: g);
      case GroupTab.members:
        return _MembersTab(group: g);
      case GroupTab.polls:
        return PollsView(groupId: _gid);
      case GroupTab.announcements:
        return AnnouncementsView(groupId: _gid);
      case GroupTab.files:
        return FilesView(groupId: _gid);
      case GroupTab.location:
        return LocationView(groupId: _gid, active: _isTabActive(GroupTab.location, tabs));
      case GroupTab.copilot:
        return CopilotView(groupId: _gid);
      case GroupTab.settings:
        return GroupSettingsView(groupId: _gid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(_gid));
    final g = detail.valueOrNull;
    final tabs = g != null ? _tabsFor(g) : const <GroupTab>[];
    if (g != null) _ensureController(tabs);

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
          if (g?.modules.chat ?? false)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat',
              onPressed: () => context.push('/groups/$_gid/chat'),
            ),
          IconButton(
            icon: _mutating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_outlined),
            onPressed: _mutating ? null : _refresh,
          ),
        ],
      ),
      floatingActionButton: (g != null && _ctrl != null) ? _buildFab(g, tabs) : null,
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
          // _ctrl was ensured above; clamp is a safety net for the brief window
          // where a module was just toggled off.
          return Column(
            children: [
              _Header(group: g, onMenu: () => _openMenu(g)),
              _GroupTabBar(controller: _ctrl!, tabs: tabs),
              Expanded(
                child: TabBarView(
                  controller: _ctrl!,
                  children: tabs.map((t) => _buildTab(g, t)).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
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
                    Text(group.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
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
              IconButton(icon: const Icon(Icons.more_horiz), onPressed: onMenu, tooltip: 'Group actions'),
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
                    OBadge(label: '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}', icon: Icons.people_outline),
                    OBadge(label: group.role, color: accent.primary(isDark)),
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

// ── Tab bar (scrollable when there are many modules) ─────────────────────────

class _GroupTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<GroupTab> tabs;
  const _GroupTabBar({required this.controller, required this.tabs});

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scrollable = tabs.length > 4;
    return TabBar(
      controller: controller,
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : TabAlignment.center,
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.sm),
      labelPadding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(OrdoRadius.pill)),
      dividerColor: Colors.transparent,
      overlayColor: WidgetStatePropertyAll(cs.primary.withValues(alpha: 0.06)),
      labelColor: cs.primary,
      unselectedLabelColor: cs.onSecondary,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      splashBorderRadius: BorderRadius.circular(OrdoRadius.pill),
      tabs: tabs.map((t) => Tab(text: t.label)).toList(),
    );
  }
}

// ── Home tab: up next + "what's new" feed + quick actions ────────────────────

class _HomeTab extends ConsumerWidget {
  final GroupDetail group;
  final void Function(GroupTab) onJumpTo;
  const _HomeTab({required this.group, required this.onJumpTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final accent = OrdoAccent.byName(group.accentColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = accent.primary(isDark);

    final from = startOfDay(DateTime.now());
    final to = addDays(from, 30); // wider than the Timeline tab's week view so Home surfaces the real next event
    final timeline = ref.watch(groupTimelineProvider((groupId: group.id, from: from, to: to)));
    final nowTs = DateTime.now();
    final nextUp = [...?timeline.valueOrNull?.items]
      ..retainWhere((i) => i.startTime.isAfter(nowTs) || i.startTime.isAtSameMomentAs(nowTs))
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final TimelineItem? nearest = nextUp.isNotEmpty ? nextUp.first : null;

    // "What's new" — each source is module-gated (conditional watch is safe in
    // Riverpod: it tracks providers watched this build and unsubscribes the rest).
    final announcements = group.modules.announcements ? ref.watch(announcementsProvider(group.id)).valueOrNull : null;
    final polls = group.modules.polls ? ref.watch(pollsProvider(group.id)).valueOrNull : null;
    final files = group.modules.files ? ref.watch(mediaProvider(group.id)).valueOrNull : null;

    final latestAnnouncement = (announcements != null && announcements.isNotEmpty) ? announcements.first : null;
    final latestPoll = (polls != null && polls.isNotEmpty) ? polls.first : null;
    final recentFiles = files != null ? files.take(2).toList() : <MediaFile>[];

    final whatsNew = <Widget>[
      if (latestAnnouncement != null)
        _WhatsNewCard(
          icon: Icons.campaign_outlined,
          iconColor: Colors.amber.shade700,
          title: latestAnnouncement.title,
          subtitle: latestAnnouncement.body,
          onTap: () => onJumpTo(GroupTab.announcements),
        ),
      if (latestPoll != null)
        _WhatsNewCard(
          icon: Icons.poll_outlined,
          iconColor: cs.primary,
          title: latestPoll.question,
          subtitle: latestPoll.closed ? 'Poll closed' : '${latestPoll.totalVoters} voter${latestPoll.totalVoters == 1 ? '' : 's'} · tap to vote',
          onTap: () => onJumpTo(GroupTab.polls),
        ),
      for (final f in recentFiles)
        _WhatsNewCard(
          icon: f.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
          iconColor: cs.primary,
          title: f.filename,
          subtitle: '${f.uploaderName} · ${_size(f.sizeBytes)}',
          onTap: () => onJumpTo(GroupTab.files),
        ),
      if (group.modules.tasks && group.pendingTaskCount > 0)
        _WhatsNewCard(
          icon: Icons.task_alt_outlined,
          iconColor: accentColor,
          title: '${group.pendingTaskCount} pending task${group.pendingTaskCount == 1 ? '' : 's'}',
          subtitle: 'Tap to see what needs doing',
          onTap: () => onJumpTo(GroupTab.tasks),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
      children: [
        OSectionHeader(title: 'Up next'),
        if (group.nextEvent != null)
          _NextEventCard(title: group.nextEvent!.title, when: group.nextEvent!.startTime, accent: accentColor)
        else if (timeline.isLoading)
          const Padding(padding: EdgeInsets.symmetric(horizontal: OrdoSpacing.lg), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
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
            onTap: group.modules.timeline ? () => showAddBlockSheet(context, ref, groupId: group.id) : null,
            child: Row(children: [
              Icon(Icons.event_available_outlined, color: accentColor),
              const SizedBox(width: OrdoSpacing.md),
              Expanded(child: Text(group.modules.timeline ? 'No upcoming events. Add one?' : 'No upcoming events.', style: TextStyle(color: cs.onSecondary))),
            ]),
          ),
        const SizedBox(height: OrdoSpacing.md),

        OSectionHeader(title: 'What’s new'),
        if (whatsNew.isEmpty)
          OCard(
            child: Row(children: [
              Icon(Icons.check_circle_outline, color: accentColor),
              const SizedBox(width: OrdoSpacing.md),
              const Expanded(child: Text('You’re all caught up', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          )
        else
          ...whatsNew,
        const SizedBox(height: OrdoSpacing.md),

        OSectionHeader(title: 'Quick actions'),
        Row(
          children: [
            Expanded(child: _ActionTile(icon: Icons.search, label: 'Find free time', accent: accentColor, onTap: () => context.push('/find-slot?groupId=${group.id}'))),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: _ActionTile(
                icon: Icons.task_alt,
                label: 'Tasks',
                badge: group.pendingTaskCount > 0 ? '${group.pendingTaskCount}' : null,
                accent: accentColor,
                onTap: group.modules.tasks ? () => onJumpTo(GroupTab.tasks) : null,
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
                accent: accentColor,
                onTap: group.modules.chat ? () => context.push('/groups/${group.id}/chat') : null,
              ),
            ),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(child: _ActionTile(icon: Icons.people_outline, label: 'Members', accent: accentColor, onTap: group.modules.members ? () => onJumpTo(GroupTab.members) : null)),
          ],
        ),
        const SizedBox(height: OrdoSpacing.md),

        if (group.modules.chat && group.unreadCount > 0)
          OCard(
            onTap: () => context.push('/groups/${group.id}/chat'),
            padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.md),
            child: Row(children: [
              Icon(Icons.mark_chat_unread_outlined, color: accentColor),
              const SizedBox(width: OrdoSpacing.md),
              Expanded(child: Text('${group.unreadCount} unread ${group.unreadCount == 1 ? 'message' : 'messages'}', style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ]),
          ),
      ],
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _WhatsNewCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _WhatsNewCard({required this.icon, required this.iconColor, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
      child: OCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(OrdoRadius.md)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
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
  const _NextEventCard({required this.title, required this.when, this.end, this.location, this.muted = false, required this.accent});

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
                        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: muted ? cs.onSecondary : cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(OrdoRadius.pill)),
                      child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
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
// (No inner FAB — the host provides a contextual one for the active tab.)

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
        Padding(
          padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.sm),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _weekStart = addDays(_weekStart, -7))),
              Expanded(child: Center(child: Text('${fmtDate(_range.from)} – ${fmtDate(addDays(_range.from, 6))}', style: const TextStyle(fontWeight: FontWeight.w600)))),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _weekStart = addDays(_weekStart, 7))),
              TextButton(onPressed: () => setState(() => _weekStart = startOfWeek(DateTime.now())), child: const Text('Today')),
            ],
          ),
        ),
        Expanded(child: res.when(
          loading: () => const _ListSkeleton(),
          error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Could not load timeline', subtitle: e is ApiException ? e.message : null),
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
            return ListView.builder(
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
                        child: Text(dayLabel(it.startTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent.primary(isDark))),
                      ),
                    ],
                    _TimelineTile(item: it),
                  ],
                );
              },
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
                                if (busy) ...[Icon(Icons.lock_outline, size: 14, color: cs.onSecondary), const SizedBox(width: 4)],
                                Flexible(
                                  child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: busy ? cs.onSecondary : cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(item.allDay ? 'All day' : '${fmtTime(item.startTime)} – ${fmtTime(item.endTime)}', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
                            if (full && item.location != null && item.location!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.place_outlined, size: 12, color: cs.onSecondary),
                                const SizedBox(width: 3),
                                Flexible(child: Text(item.location!, style: TextStyle(fontSize: 12, color: cs.onSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ]),
                            ],
                            if (full && item.description != null && item.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(item.description!, style: TextStyle(fontSize: 12, color: cs.onSecondary, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            if (titleOnly)
                              Padding(padding: const EdgeInsets.only(top: 2), child: Text('Private details hidden', style: TextStyle(fontSize: 11, color: cs.onSecondary))),
                          ],
                        ),
                      ),
                      if (item.isEvent) OBadge(label: 'Event', color: busy ? cs.onSecondary : item.color),
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
// (No inner FAB — the host provides a contextual one for the active tab.)

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
        Expanded(
          child: res.when(
            loading: () => const _ListSkeleton(),
            error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Could not load tasks', subtitle: e is ApiException ? e.message : null),
            data: (tasks) {
              if (tasks.isEmpty) {
                return OEmptyState(
                  icon: taskIcon,
                  title: _tab == 'mine' ? 'No tasks assigned to you' : 'No tasks yet',
                  subtitle: 'Create one to keep the group on track.',
                  action: FilledButton.icon(
                    onPressed: () => showCreateTaskSheet(context, widget.group),
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, 0, OrdoSpacing.lg, 96),
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
}

const taskIcon = Icons.task_alt;

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
                Text(task.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, decoration: done ? TextDecoration.lineThrough : null, color: done ? cs.onSecondary : cs.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: OrdoSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OBadge(label: task.priority, color: pColor),
                    if (task.dueAt != null) OBadge(label: dayLabel(task.dueAt!), icon: Icons.calendar_today_outlined),
                    if (task.commentCount > 0) OBadge(label: '${task.commentCount}', icon: Icons.chat_bubble_outline),
                    if (assignedToMe) OBadge(label: 'Mine', color: accent),
                  ],
                ),
                if (task.assignees.isNotEmpty) ...[
                  const SizedBox(height: OrdoSpacing.sm),
                  OAvatarStack(names: task.assignees.map((a) => a.name).toList(), images: task.assignees.map((a) => a.avatarUrl).toList(), radius: 11, max: 5),
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
        children: [for (final r in options) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, r), child: Text(r == m.role ? '$r (current)' : r))],
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
    final ok = await confirm(context, title: 'Remove ${m.name}?', message: 'They will lose access to this group.', confirmText: 'Remove', danger: true);
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
      return const OEmptyState(icon: Icons.people_outline, title: 'No members', subtitle: 'Invite people from the group menu.');
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
                          Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Joined ${fmtDate(m.joinedAt)}', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
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
                          // MEMBER_ROLE_UPDATE is OWNER-only server-side; hide it
                          // from ADMINs so they're never offered an action that 403s.
                          if (widget.group.role == 'OWNER') const PopupMenuItem(value: 'role', child: Text('Change role')),
                          PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: cs.error))),
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
            child: Container(color: Colors.black.withValues(alpha: 0.15), alignment: Alignment.center, child: const CircularProgressIndicator()),
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
