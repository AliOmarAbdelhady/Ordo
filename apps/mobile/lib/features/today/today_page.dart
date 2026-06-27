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

/// The unified "My Dashboard": a single view of the user's timeline, tasks,
/// to-dos and groups across EVERY group they belong to — the daily command
/// center. Replaces the shallow per-section Today view with a real aggregation.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = startOfDay(now);
    final dayRange = (from: todayStart, to: addDays(todayStart, 1));

    final user = ref.watch(authControllerProvider).valueOrNull;
    final timelineAsync = ref.watch(selfTimelineProvider(dayRange));
    final myTasksAsync = ref.watch(myTasksProvider);
    final myTodosAsync = ref.watch(myTodosProvider('today'));
    final groupsAsync = ref.watch(groupsProvider);

    final greeting = _greeting(now, user?.name);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            // Invalidate the family providers without an arg to clear every
            // cached key, then the scalar providers.
            ref.invalidate(selfTimelineProvider);
            ref.invalidate(myTasksProvider);
            ref.invalidate(myTodosProvider);
            ref.invalidate(groupsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(greeting: greeting)),
              SliverToBoxAdapter(child: _StatusLine(timelineAsync: timelineAsync, now: now)),

              // ── My tasks (all groups) ────────────────────────────────────
              _MyTasksSection(tasksAsync: myTasksAsync),

              // ── My to-dos (personal + all groups) ────────────────────────
              _MyTodosSection(
                todosAsync: myTodosAsync,
                onToggle: _toggleTodo,
                onOpenAll: () => context.push('/timeline/todos'),
              ),

              // ── Today's timeline ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: OSectionHeader(
                  title: "Today's timeline",
                  actionLabel: 'Add',
                  onAction: () => showAddBlockSheet(context, ref, groupId: null, initialDate: now),
                ),
              ),
              _TodaySection(
                timelineAsync: timelineAsync,
                onAdd: () => showAddBlockSheet(context, ref, groupId: null, initialDate: now),
              ),

              // ── My groups ────────────────────────────────────────────────
              _MyGroupsSection(groupsAsync: groupsAsync),

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

  Future<void> _toggleTodo(Todo todo) async {
    try {
      await ref.read(apiClientProvider).updateTodo(todo.id, {'done': !todo.done});
      ref.invalidate(myTodosProvider);
      ref.invalidate(todosProvider); // keep the To-dos page in sync too
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not update to-do.', error: true);
    }
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
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmtDateLong(DateTime.now()),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(greeting, style: Theme.of(context).textTheme.displaySmall),
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
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.xs, OrdoSpacing.lg, OrdoSpacing.md),
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
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.md),
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
            child: Icon(info?.icon ?? Icons.schedule_rounded, size: 17, color: accent.primary(isDark)),
          ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: info == null
                ? Text('Loading your day…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(info.headline, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      if (info.detail != null) ...[
                        const SizedBox(height: 1),
                        Text(info.detail!, style: TextStyle(fontSize: 12.5, color: cs.onSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _computeStatus(List<TimelineItem> items, DateTime now) {
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

  String _accentNameFromColor(Color c) {
    final argb = c.toARGB32();
    for (final a in OrdoAccent.all) {
      if (a.light.toARGB32() == argb || a.dark.toARGB32() == argb) return a.name;
    }
    return 'blue';
  }
}

class _StatusInfo {
  final String headline;
  final String? detail;
  final IconData icon;
  final OrdoAccent color;
  const _StatusInfo({required this.headline, this.detail, required this.icon, required this.color});
}

// ═══════════════════════════════════════════════════════════════════════════
// My tasks (cross-group)
// ═══════════════════════════════════════════════════════════════════════════

const _activeStatuses = {'TODO', 'IN_PROGRESS', 'BLOCKED'};

class _MyTasksSection extends StatelessWidget {
  final AsyncValue<List<Task>> tasksAsync;
  const _MyTasksSection({required this.tasksAsync});

  @override
  Widget build(BuildContext context) {
    return tasksAsync.when(
      loading: () => SliverToBoxAdapter(
        child: OSkeletonBox(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
            child: Column(
              children: [
                _TaskSkeleton(),
                const SizedBox(height: OrdoSpacing.sm),
                _TaskSkeleton(),
              ],
            ),
          ),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (tasks) {
        final active = tasks.where((t) => _activeStatuses.contains(t.status)).toList()
          ..sort((a, b) {
            final ad = a.dueAt;
            final bd = b.dueAt;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return ad.compareTo(bd);
          });
        final shown = active.take(6).toList();

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OSectionHeader(title: active.isEmpty ? 'My tasks' : 'My tasks · ${active.length}'),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                  child: OCard(
                    bordered: true,
                    child: OEmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'No tasks on your plate',
                      subtitle: active.isEmpty ? 'Tasks assigned to you across all groups appear here.' : 'You\'re all caught up.',
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                  child: Column(
                    children: [
                      for (final t in shown) ...[
                        _MyTaskRow(task: t),
                        if (t != shown.last) const SizedBox(height: OrdoSpacing.sm),
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

class _MyTaskRow extends StatelessWidget {
  final Task task;
  const _MyTaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final overdue = task.dueAt != null && task.dueAt!.isBefore(now);
    final dueToday = task.dueAt != null && isSameDay(task.dueAt!, now);
    final dueLabel = task.dueAt == null
        ? null
        : (overdue && !dueToday ? 'Overdue' : (dueToday ? 'Today' : dayLabel(task.dueAt!)));

    return OCard(
      onTap: () => context.push('/tasks/${task.id}'),
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
      child: Row(
        children: [
          if (task.groupName != null)
            OGroupAvatar(name: task.groupName, accent: task.groupAccent ?? 'blue', size: 32)
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: cs.surfaceContainer, shape: BoxShape.circle),
              child: Icon(Icons.task_alt_rounded, size: 16, color: cs.onSecondary),
            ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.groupName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.groupName!,
                    style: TextStyle(fontSize: 12, color: cs.onSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: OrdoSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OBadge(label: _priorityLabel(task.priority), color: priorityColor(task.priority, isDark)),
              if (dueLabel != null) ...[
                const SizedBox(height: 4),
                OBadge(
                  label: dueLabel,
                  color: overdue ? OrdoColors.danger : OrdoAccent.amber.light,
                  icon: Icons.schedule_outlined,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _priorityLabel(String p) => p[0] + p.substring(1).toLowerCase();

class _TaskSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OCard(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
      bordered: true,
      child: Row(
        children: const [
          OSkeleton(width: 32, height: 32, radius: 10),
          SizedBox(width: OrdoSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [OSkeleton(width: 160, height: 13), SizedBox(height: 6), OSkeleton(width: 90, height: 11)])),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// My to-dos (personal + all groups)
// ═══════════════════════════════════════════════════════════════════════════

class _MyTodosSection extends StatelessWidget {
  final AsyncValue<List<Todo>> todosAsync;
  final void Function(Todo todo) onToggle;
  final VoidCallback onOpenAll;
  const _MyTodosSection({required this.todosAsync, required this.onToggle, required this.onOpenAll});

  @override
  Widget build(BuildContext context) {
    return todosAsync.when(
      loading: () => SliverToBoxAdapter(
        child: OSkeletonBox(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
            child: Column(
              children: [
                _TodoSkeleton(),
                const SizedBox(height: OrdoSpacing.sm),
                _TodoSkeleton(),
              ],
            ),
          ),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (todos) {
        if (todos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final open = todos.where((t) => !t.done).toList();
        final shown = open.take(5).toList();

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OSectionHeader(
                title: open.isEmpty ? 'To-dos' : 'To-dos · ${open.length} open',
                actionLabel: 'All',
                onAction: onOpenAll,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                child: Column(
                  children: [
                    for (final todo in shown) ...[
                      _MyTodoRow(todo: todo, onToggle: () => onToggle(todo)),
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

class _MyTodoRow extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  const _MyTodoRow({required this.todo, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OCard(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm + 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.done ? cs.primary : Colors.transparent,
                border: Border.all(color: todo.done ? cs.primary : cs.outline, width: 2),
              ),
              child: todo.done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                if (todo.groupName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      ODot(OrdoAccent.byName(todo.groupAccent ?? 'blue').primary(isDark), size: 7),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          todo.groupName!,
                          style: TextStyle(fontSize: 11.5, color: cs.onSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else if (todo.dueAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dayLabel(todo.dueAt!),
                    style: TextStyle(fontSize: 11.5, color: cs.onSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OCard(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm + 2),
      child: Row(
        children: const [
          OSkeleton(width: 22, height: 22, radius: 11),
          SizedBox(width: OrdoSpacing.md),
          OSkeleton(width: 150, height: 13),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Today's timeline
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
        final todayItems = items.where((it) => isSameDay(it.startTime, today)).toList()
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
              padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
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
    final title = item.redacted ? 'Busy' : (item.title.isEmpty ? 'Untitled' : item.title);
    final now = DateTime.now();
    final inProgress = now.isAfter(item.startTime) && now.isBefore(item.endTime);

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
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 13, color: cs.onSecondary),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  item.allDay ? 'All day' : fmtRange(item.startTime, item.endTime),
                                  style: TextStyle(fontSize: 12.5, color: cs.onSecondary),
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
                      Icon(item.redacted ? Icons.lock_outline : Icons.do_not_disturb_on_outlined, size: 16, color: cs.onSecondary),
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
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
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
// My groups
// ═══════════════════════════════════════════════════════════════════════════

/// Fixed height for the horizontal group mini-cards. Sized to fit the tallest
/// card (avatar row + a 2-line badge wrap + next-event row) so content never
/// overflows the carousel's cross-axis constraint.
const double _groupCardHeight = 124;

class _MyGroupsSection extends StatelessWidget {
  final AsyncValue<List<Group>> groupsAsync;
  const _MyGroupsSection({required this.groupsAsync});

  @override
  Widget build(BuildContext context) {
    return groupsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: OSkeletonBox(
          SizedBox(
            height: _groupCardHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
              children: const [_GroupSkeleton(), SizedBox(width: OrdoSpacing.sm), _GroupSkeleton()],
            ),
          ),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (groups) {
        if (groups.isEmpty) {
          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OSectionHeader(title: 'My groups'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                  child: OCard(
                    bordered: true,
                    child: OEmptyState(
                      icon: Icons.groups_2_outlined,
                      title: 'No groups yet',
                      subtitle: 'Create or join a group to start coordinating.',
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final sorted = [...groups]..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return a.name.compareTo(b.name);
          });
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OSectionHeader(title: 'My groups · ${groups.length}'),
              SizedBox(
                height: _groupCardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(width: OrdoSpacing.sm),
                  itemBuilder: (context, i) => _GroupMiniCard(group: sorted[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupMiniCard extends StatelessWidget {
  final Group group;
  const _GroupMiniCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = OrdoAccent.byName(group.accentColor);

    return GestureDetector(
      onTap: () => context.push('/groups/${group.id}'),
      child: Container(
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(OrdoRadius.lg),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                OGroupAvatar(name: group.name, accent: group.accentColor, size: 34),
                const SizedBox(width: OrdoSpacing.sm),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (group.pinned) Icon(Icons.push_pin_rounded, size: 13, color: accent.primary(isDark)),
              ],
            ),
            const SizedBox(height: OrdoSpacing.sm),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                if (group.pendingTaskCount > 0)
                  OBadge(label: '${group.pendingTaskCount} task${group.pendingTaskCount == 1 ? '' : 's'}', color: OrdoAccent.amber.light, icon: Icons.task_alt_rounded),
                if (group.unreadCount > 0)
                  OBadge(label: '${group.unreadCount} unread', color: OrdoAccent.cyan.light, icon: Icons.chat_bubble_outline_rounded),
                if (group.pendingTaskCount == 0 && group.unreadCount == 0)
                  OBadge(label: '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}', icon: Icons.groups_2_outlined),
              ],
            ),
            if (group.nextEvent != null) ...[
              const SizedBox(height: OrdoSpacing.xs),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 12, color: accent.primary(isDark)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      group.nextEvent!.title,
                      style: TextStyle(fontSize: 11.5, color: cs.onSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(dayLabel(group.nextEvent!.startTime), style: TextStyle(fontSize: 11, color: accent.primary(isDark), fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupSkeleton extends StatelessWidget {
  const _GroupSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(OrdoSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(OrdoRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          OSkeleton(width: 100, height: 13),
          SizedBox(height: OrdoSpacing.sm),
          OSkeleton(width: 70, height: 11),
        ],
      ),
    );
  }
}
