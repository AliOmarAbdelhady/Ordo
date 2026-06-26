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

/// The daily command center: greeting, current/next status, today's blocks,
/// upcoming group events, due-soon tasks, and today's to-dos.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _DueGroupedTask {
  final Task task;
  final String groupName;
  const _DueGroupedTask(this.task, this.groupName);
}

class _TodayPageState extends ConsumerState<TodayPage> {
  List<_DueGroupedTask>? _dueTasks;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = startOfDay(now);
    final todayEnd = addDays(todayStart, 1);
    final dayRange = (from: todayStart, to: todayEnd);

    final user = ref.watch(authControllerProvider).valueOrNull;
    final timelineAsync = ref.watch(selfTimelineProvider(dayRange));
    final groupsAsync = ref.watch(groupsProvider);
    final todosAsync = ref.watch(todosProvider((groupId: null, tab: 'today')));

    // Aggregate "due soon" tasks whenever the group list resolves.
    ref.listen<AsyncValue<List<Group>>>(groupsProvider, (prev, next) {
      next.whenData((groups) => _loadDueTasks(groups));
    });
    if (_dueTasks == null) {
      groupsAsync.whenData((groups) => _loadDueTasks(groups));
    }

    final greeting = _greeting(now, user?.name);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(selfTimelineProvider(dayRange));
            ref.invalidate(groupsProvider);
            ref.invalidate(todosProvider((groupId: null, tab: 'today')));
            setState(() => _dueTasks = null);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(greeting: greeting)),
              SliverToBoxAdapter(
                child: _StatusLine(
                  timelineAsync: timelineAsync,
                  now: now,
                ),
              ),
              // ── Today ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: OSectionHeader(
                  title: 'Today',
                  actionLabel: 'Add',
                  onAction: () => showAddBlockSheet(context, ref, groupId: null, initialDate: now),
                ),
              ),
              _TodaySection(
                timelineAsync: timelineAsync,
                onAdd: () => showAddBlockSheet(context, ref, groupId: null, initialDate: now),
              ),
              // ── Upcoming with groups ────────────────────────────────
              _UpcomingSection(groupsAsync: groupsAsync),
              // ── Due soon ────────────────────────────────────────────
              if (_dueTasks != null && _dueTasks!.isNotEmpty)
                _DueSoonSection(tasks: _dueTasks!),
              // ── To-dos ──────────────────────────────────────────────
              _TodosSection(todosAsync: todosAsync),
              const SliverToBoxAdapter(child: SizedBox(height: OrdoSpacing.xxl)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(DateTime now, String? name) {
    final hour = now.hour;
    final part = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final first = (name == null || name.trim().isEmpty)
        ? ''
        : name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? part : '$part, $first';
  }

  Future<void> _loadDueTasks(List<Group> groups) async {
    if (_dueTasks != null) return;
    final api = ref.read(apiClientProvider);
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 2));
    final activeStatuses = {'TODO', 'IN_PROGRESS', 'BLOCKED'};
    final List<_DueGroupedTask> out = [];
    try {
      for (final g in groups) {
        if (!g.modules.tasks) continue;
        final tasks = await api.tasks(g.id, 'mine');
        for (final t in tasks) {
          if (t.dueAt == null) continue;
          if (!activeStatuses.contains(t.status)) continue;
          if (t.dueAt!.isBefore(horizon)) {
            out.add(_DueGroupedTask(t, g.name));
          }
        }
      }
    } catch (_) {
      // Fail gracefully — keep this optional section quiet.
    }
    // Overdue first, then soonest due.
    out.sort((a, b) => a.task.dueAt!.compareTo(b.task.dueAt!));
    if (mounted) setState(() => _dueTasks = out);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Header + status
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String greeting;
  const _Header({required this.greeting});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OrdoSpacing.lg,
        OrdoSpacing.lg,
        OrdoSpacing.lg,
        OrdoSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmtDateLong(DateTime.now()),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            greeting,
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final AsyncValue<List<TimelineItem>> timelineAsync;
  final DateTime now;
  const _StatusLine({required this.timelineAsync, required this.now});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OrdoSpacing.lg,
        OrdoSpacing.xs,
        OrdoSpacing.lg,
        OrdoSpacing.md,
      ),
      child: timelineAsync.when(
        loading: () => _statusPill(cs, isDark, null),
        error: (_, _) => _statusPill(cs, isDark, null),
        data: (items) => _statusPill(cs, isDark, _computeStatus(items, now)),
      ),
    );
  }

  Widget _statusPill(ColorScheme cs, bool isDark, _StatusInfo? info) {
    final accent = info?.color ?? OrdoAccent.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: OrdoSpacing.lg,
        vertical: OrdoSpacing.md,
      ),
      decoration: BoxDecoration(
        color: accent.soft(isDark),
        borderRadius: BorderRadius.circular(OrdoRadius.lg),
        border: Border.all(color: accent.primary(isDark).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.primary(isDark).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              info?.icon ?? Icons.schedule_rounded,
              size: 17,
              color: accent.primary(isDark),
            ),
          ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: info == null
                ? Text(
                    'Loading your day…',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        info.headline,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      if (info.detail != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          info.detail!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _computeStatus(List<TimelineItem> items, DateTime now) {
    // Sort by start time for a stable scan.
    final sorted = [...items]..sort((a, b) => a.startTime.compareTo(b.startTime));

    TimelineItem? current;
    TimelineItem? next;
    for (final it in sorted) {
      if (!it.endTime.isBefore(now)) {
        if (it.startTime.isBefore(now) || it.startTime.isAtSameMomentAs(now)) {
          current = it;
        } else {
          next = it;
          break;
        }
      }
    }

    if (current != null) {
      final label = current.redacted ? 'Busy' : (current.title.isEmpty ? 'Busy' : current.title);
      return _StatusInfo(
        headline: 'Now: $label',
        detail: 'Until ${fmtTime(current.endTime)}',
        icon: Icons.play_circle_rounded,
        color: OrdoAccent.byName(_accentNameFromColor(current.color)),
      );
    }
    if (next != null) {
      final label = next.redacted ? 'Busy' : (next.title.isEmpty ? 'Busy' : next.title);
      return _StatusInfo(
        headline: 'Free until ${fmtTime(next.startTime)}',
        detail: 'Next: $label',
        icon: Icons.coffee_rounded,
        color: OrdoAccent.byName(_accentNameFromColor(next.color)),
      );
    }
    return _StatusInfo(
      headline: 'Nothing else today',
      detail: 'Enjoy the breathing room',
      icon: Icons.nightlight_rounded,
      color: OrdoAccent.slate,
    );
  }

  /// Best-effort mapping of a timeline color back to an accent name for soft fills.
  String _accentNameFromColor(Color c) {
    final argb = c.toARGB32();
    for (final a in OrdoAccent.all) {
      if (a.light.toARGB32() == argb || a.dark.toARGB32() == argb) {
        return a.name;
      }
    }
    return 'blue';
  }
}

class _StatusInfo {
  final String headline;
  final String? detail;
  final IconData icon;
  final OrdoAccent color;
  const _StatusInfo({
    required this.headline,
    this.detail,
    required this.icon,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Today section
// ═══════════════════════════════════════════════════════════════════════════

class _TodaySection extends StatelessWidget {
  final AsyncValue<List<TimelineItem>> timelineAsync;
  final VoidCallback onAdd;
  const _TodaySection({required this.timelineAsync, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return timelineAsync.when(
      loading: () => SliverToBoxAdapter(
        child: OSkeletonBox(
          Column(
            children: [
              for (int i = 0; i < 3; i++) ...[
                _BlockSkeleton(),
                const SizedBox(height: OrdoSpacing.sm),
              ],
            ],
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
          child: Text(
            'Could not load your day. Pull to retry.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
          ),
        ),
      ),
      data: (items) {
        final today = DateTime.now();
        final todayItems = items
            .where((it) => isSameDay(it.startTime, today))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        if (todayItems.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
              child: OCard(
                bordered: true,
                child: OEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing planned today',
                  subtitle: 'Add a block to map out your day.',
                  action: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add a block'),
                  ),
                ),
              ),
            ),
          );
        }

        return SliverList.separated(
          itemCount: todayItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: OrdoSpacing.sm),
          itemBuilder: (context, i) {
            final it = todayItems[i];
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
              child: _BlockRow(item: it),
            );
          },
        );
      },
    );
  }
}

class _BlockRow extends StatelessWidget {
  final TimelineItem item;
  const _BlockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = item.redacted
        ? 'Busy'
        : (item.title.isEmpty ? 'Untitled' : item.title);
    final now = DateTime.now();
    final inProgress =
        now.isAfter(item.startTime) && now.isBefore(item.endTime);

    return OCard(
      padding: EdgeInsets.zero,
      bordered: true,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(OrdoRadius.lg),
                  bottomLeft: Radius.circular(OrdoRadius.lg),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OrdoSpacing.md,
                  vertical: OrdoSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                              decoration: inProgress ? null : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: cs.onSecondary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  item.allDay
                                      ? 'All day'
                                      : fmtRange(item.startTime, item.endTime),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: cs.onSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (item.isBusy || item.redacted) ...[
                      const SizedBox(width: OrdoSpacing.sm),
                      Icon(
                        item.redacted ? Icons.lock_outline : Icons.do_not_disturb_on_outlined,
                        size: 16,
                        color: cs.onSecondary,
                      ),
                    ],
                    if (inProgress) ...[
                      const SizedBox(width: OrdoSpacing.sm),
                      ODot(item.color, size: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OCard(
      padding: const EdgeInsets.symmetric(
        horizontal: OrdoSpacing.md,
        vertical: OrdoSpacing.md,
      ),
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          OSkeleton(width: 160, height: 14),
          SizedBox(height: OrdoSpacing.sm),
          OSkeleton(width: 110, height: 11),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Upcoming with groups
// ═══════════════════════════════════════════════════════════════════════════

class _UpcomingSection extends StatelessWidget {
  final AsyncValue<List<Group>> groupsAsync;
  const _UpcomingSection({required this.groupsAsync});

  @override
  Widget build(BuildContext context) {
    return groupsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: OSkeletonBox(
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
              children: const [
                _UpcomingSkeleton(),
                SizedBox(width: OrdoSpacing.sm),
                _UpcomingSkeleton(),
              ],
            ),
          ),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (groups) {
        final now = DateTime.now();
        final week = now.add(const Duration(days: 7));
        final upcoming = groups
            .where((g) => g.nextEvent != null)
            .where((g) =>
                g.nextEvent!.startTime.isAfter(now) &&
                g.nextEvent!.startTime.isBefore(week))
            .toList()
          ..sort((a, b) =>
              a.nextEvent!.startTime.compareTo(b.nextEvent!.startTime));
        final shown = upcoming.take(3).toList();

        if (shown.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OSectionHeader(title: 'Upcoming with groups'),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(width: OrdoSpacing.sm),
                  itemBuilder: (context, i) {
                    final g = shown[i];
                    return _UpcomingCard(
                      group: g,
                      onTap: () => context.push('/groups/${g.id}'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _UpcomingCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ev = group.nextEvent!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = OrdoAccent.byName(group.accentColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(OrdoSpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(OrdoRadius.lg),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            OGroupAvatar(name: group.name, accent: group.accentColor, size: 38),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ev.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.groups_2_outlined,
                        size: 12,
                        color: cs.onSecondary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  OBadge(
                    label: dayLabel(ev.startTime),
                    color: accent.primary(isDark),
                    icon: Icons.event_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSkeleton extends StatelessWidget {
  const _UpcomingSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(OrdoSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(OrdoRadius.lg),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OSkeleton(width: 120, height: 13),
          SizedBox(height: OrdoSpacing.sm),
          OSkeleton(width: 80, height: 11),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Due soon
// ═══════════════════════════════════════════════════════════════════════════

class _DueSoonSection extends StatelessWidget {
  final List<_DueGroupedTask> tasks;
  const _DueSoonSection({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OSectionHeader(title: 'Due soon'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
            child: Column(
              children: [
                for (final gt in tasks.take(5)) ...[
                  _TaskRow(task: gt.task, groupName: gt.groupName),
                  if (gt != tasks.take(5).last) const SizedBox(height: OrdoSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final String groupName;
  const _TaskRow({required this.task, required this.groupName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = task.dueAt!.isBefore(DateTime.now());

    final dueLabel = overdue
        ? 'Overdue'
        : (isSameDay(task.dueAt!, DateTime.now()) ? 'Today' : dayLabel(task.dueAt!));

    final chipColor = overdue
        ? OrdoColors.danger
        : OrdoAccent.amber.primary(isDark);

    return OCard(
      onTap: () => context.push('/tasks/${task.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: OrdoSpacing.md,
        vertical: OrdoSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: isDark ? 0.22 : 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 16,
              color: chipColor,
            ),
          ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  groupName,
                  style: TextStyle(fontSize: 12, color: cs.onSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: OrdoSpacing.sm),
          OBadge(
            label: dueLabel,
            color: overdue ? OrdoColors.danger : OrdoAccent.amber.light,
            icon: Icons.schedule_outlined,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// To-dos
// ═══════════════════════════════════════════════════════════════════════════

class _TodosSection extends StatelessWidget {
  final AsyncValue<List<Todo>> todosAsync;
  const _TodosSection({required this.todosAsync});

  @override
  Widget build(BuildContext context) {
    return todosAsync.when(
      loading: () => SliverToBoxAdapter(
        child: OSkeletonBox(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
            child: Column(
              children: const [
                _TodoSkeleton(),
                SizedBox(height: OrdoSpacing.sm),
                _TodoSkeleton(),
              ],
            ),
          ),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (todos) {
        if (todos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final shown = todos.take(4).toList();

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OSectionHeader(
                title: 'To-dos',
                actionLabel: 'All',
                onAction: () => context.push('/timeline/todos'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                child: Column(
                  children: [
                    for (final todo in shown) ...[
                      _TodoRow(todo: todo),
                      if (todo != shown.last) const SizedBox(height: OrdoSpacing.sm),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodoRow extends StatelessWidget {
  final Todo todo;
  const _TodoRow({required this.todo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OCard(
      onTap: () => context.push('/timeline/todos'),
      padding: const EdgeInsets.symmetric(
        horizontal: OrdoSpacing.md,
        vertical: OrdoSpacing.md - 2,
      ),
      child: Row(
        children: [
          Icon(
            todo.done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: todo.done ? OrdoColors.success : cs.onSecondary,
          ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: todo.done ? TextDecoration.lineThrough : null,
                color: todo.done ? cs.onSecondary : cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoSkeleton extends StatelessWidget {
  const _TodoSkeleton();
  @override
  Widget build(BuildContext context) {
    return OCard(
      padding: const EdgeInsets.symmetric(
        horizontal: OrdoSpacing.md,
        vertical: OrdoSpacing.md - 2,
      ),
      child: Row(
        children: const [
          OSkeleton(width: 20, height: 20, radius: 10),
          SizedBox(width: OrdoSpacing.md),
          OSkeleton(width: 140, height: 13),
        ],
      ),
    );
  }
}
