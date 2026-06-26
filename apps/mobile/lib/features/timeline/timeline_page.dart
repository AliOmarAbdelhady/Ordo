import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import 'add_block_sheet.dart';
import 'sync_sheet.dart';

enum TimelineView { day, week, month }

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  TimelineView _view = TimelineView.day;
  DateTime _focused = startOfDay(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          IconButton(
            tooltip: 'Add block',
            icon: const Icon(Icons.add),
            onPressed: () => showAddBlockSheet(context, ref, initialDate: _focused),
          ),
          IconButton(
            tooltip: 'Todos',
            icon: const Icon(Icons.checklist),
            onPressed: () => context.push('/timeline/todos'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.sm),
            child: OSegmented<TimelineView>(
              segments: TimelineView.values,
              value: _view,
              label: (v) => switch (v) {
                TimelineView.day => 'Day',
                TimelineView.week => 'Week',
                TimelineView.month => 'Month',
              },
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
          _DateNav(
            focused: _focused,
            view: _view,
            onPrev: _prev,
            onNext: _next,
            onToday: () => setState(() => _focused = startOfDay(DateTime.now())),
          ),
          const Divider(height: 1),
          Expanded(child: _bodyForView()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddBlockSheet(context, ref, initialDate: _focused),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _prev() {
    setState(() {
      switch (_view) {
        case TimelineView.day:
          _focused = addDays(_focused, -1);
        case TimelineView.week:
          _focused = addDays(_focused, -7);
        case TimelineView.month:
          _focused = DateTime(_focused.year, _focused.month - 1, 1);
      }
    });
  }

  void _next() {
    setState(() {
      switch (_view) {
        case TimelineView.day:
          _focused = addDays(_focused, 1);
        case TimelineView.week:
          _focused = addDays(_focused, 7);
        case TimelineView.month:
          _focused = DateTime(_focused.year, _focused.month + 1, 1);
      }
    });
  }

  Widget _bodyForView() {
    switch (_view) {
      case TimelineView.day:
        return _DayView(focused: _focused);
      case TimelineView.week:
        return _WeekView(focused: _focused);
      case TimelineView.month:
        return _MonthView(
          focused: _focused,
          onDaySelected: (d) => setState(() {
            _focused = d;
            _view = TimelineView.day;
          }),
        );
    }
  }
}

// ── Date navigation row ──────────────────────────────────────────────────────
class _DateNav extends StatelessWidget {
  final DateTime focused;
  final TimelineView view;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  const _DateNav({required this.focused, required this.view, required this.onPrev, required this.onNext, required this.onToday});

  String _label() {
    switch (view) {
      case TimelineView.day:
        return dayLabel(focused);
      case TimelineView.week:
        final start = startOfWeek(focused);
        final end = addDays(start, 6);
        return '${fmtDayMonth(start)} – ${fmtDayMonth(end)}';
      case TimelineView.month:
        return fmtMonthYear(focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = view == TimelineView.day ? fmtDateLong(focused) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: 'Previous',
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              child: Column(
                children: [
                  Text(_label(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (sub.isNotEmpty)
                    Text(sub, style: TextStyle(fontSize: 12, color: cs.onSecondary)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Next',
          ),
        ],
      ),
    );
  }
}

// ── DAY view ─────────────────────────────────────────────────────────────────
class _DayView extends ConsumerWidget {
  final DateTime focused;
  const _DayView({required this.focused});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = focused;
    final to = addDays(focused, 1);
    final range = rangeFor(from, to);
    final async = ref.watch(selfTimelineProvider(range));

    return async.when(
      loading: () => _DaySkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(OrdoSpacing.xl),
          child: Text('Could not load timeline.\n$e', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return OEmptyState(
            icon: Icons.event_available_outlined,
            title: 'No blocks',
            subtitle: 'Nothing planned for ${dayLabel(focused)}.',
            action: FilledButton.icon(
              onPressed: () => showAddBlockSheet(context, ref, initialDate: focused),
              icon: const Icon(Icons.add),
              label: const Text('Add a block'),
            ),
          );
        }
        final day = items.where((i) => isSameDay(i.startTime, focused)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        if (day.isEmpty) {
          return OEmptyState(
            icon: Icons.event_available_outlined,
            title: 'No blocks',
            subtitle: 'Nothing planned for ${dayLabel(focused)}.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: OrdoSpacing.sm),
          itemCount: day.length,
          itemBuilder: (_, i) => _BlockTile(item: day[i], ref: ref),
        );
      },
    );
  }
}

// ── WEEK view ────────────────────────────────────────────────────────────────
class _WeekView extends ConsumerWidget {
  final DateTime focused;
  const _WeekView({required this.focused});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = startOfWeek(focused);
    final range = rangeFor(weekStart, addDays(weekStart, 7));
    final async = ref.watch(selfTimelineProvider(range));

    return async.when(
      loading: () => _WeekSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(OrdoSpacing.xl),
          child: Text('Could not load timeline.\n$e', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
        ),
      ),
      data: (items) {
        final today = startOfDay(DateTime.now());
        final days = List.generate(7, (i) => addDays(weekStart, i));
        return ListView(
          padding: const EdgeInsets.only(bottom: OrdoSpacing.xxl),
          children: [
            // Weekday header row
            Padding(
              padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.sm),
              child: Row(
                children: [
                  for (final d in days)
                    Expanded(
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1],
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSecondary),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: isSameDay(d, today)
                                  ? BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)
                                  : null,
                              child: Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSameDay(d, today) ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final d in days)
              _WeekDaySection(
                date: d,
                isToday: isSameDay(d, today),
                items: items.where((i) => isSameDay(i.startTime, d)).toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime)),
              ),
          ],
        );
      },
    );
  }
}

class _WeekDaySection extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final List<TimelineItem> items;
  const _WeekDaySection({required this.date, required this.isToday, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1]} ${date.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isToday ? cs.primary : cs.onSurface,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: OrdoSpacing.xs),
                Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
              ],
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: OrdoSpacing.sm),
              child: Text('Nothing', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
            )
          else
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(top: OrdoSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(fmtTime(it.startTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondary)),
                    ),
                    const SizedBox(width: OrdoSpacing.sm),
                    Expanded(
                      child: Row(
                        children: [
                          ODot(it.color, size: 8),
                          const SizedBox(width: OrdoSpacing.sm),
                          Expanded(
                            child: Text(
                              it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ── MONTH view ───────────────────────────────────────────────────────────────
class _MonthView extends ConsumerWidget {
  final DateTime focused;
  final void Function(DateTime) onDaySelected;
  const _MonthView({required this.focused, required this.onDaySelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthStart = DateTime(focused.year, focused.month, 1);
    final range = rangeFor(monthStart, DateTime(focused.year, focused.month + 1, 1));
    final async = ref.watch(selfTimelineProvider(range));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(OrdoSpacing.xl),
          child: Text('Could not load timeline.\n$e', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
        ),
      ),
      data: (items) {
        // Bucket items by day.
        final byDay = <int, List<Color>>{};
        for (final it in items) {
          if (it.startTime.year == focused.year && it.startTime.month == focused.month) {
            byDay.putIfAbsent(it.startTime.day, () => <Color>[]).add(it.color);
          }
        }
        return _MonthGrid(
          focused: focused,
          byDay: byDay,
          onDaySelected: onDaySelected,
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime focused;
  final Map<int, List<Color>> byDay;
  final void Function(DateTime) onDaySelected;
  const _MonthGrid({required this.focused, required this.byDay, required this.onDaySelected});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = startOfDay(DateTime.now());
    final firstOfMonth = DateTime(focused.year, focused.month, 1);
    final leadingBlanks = (firstOfMonth.weekday - DateTime.monday) % 7;
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.md, OrdoSpacing.lg, OrdoSpacing.xxl),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(w, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSecondary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: OrdoSpacing.sm),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.92,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (_, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = index - leadingBlanks + 1;
                final date = DateTime(focused.year, focused.month, day);
                final isToday = isSameDay(date, today);
                final colors = byDay[day] ?? const <Color>[];
                return GestureDetector(
                  onTap: () => onDaySelected(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(OrdoRadius.sm),
                      border: isToday ? Border.all(color: cs.primary, width: 1.5) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isToday ? cs.primary : cs.onSurface,
                          ),
                        ),
                        if (colors.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final c in colors.take(2)) ...[
                                ODot(c, size: 6),
                                if (colors.indexOf(c) < colors.take(2).length - 1) const SizedBox(width: 3),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Block tile ───────────────────────────────────────────────────────────────
class _BlockTile extends StatelessWidget {
  final TimelineItem item;
  final WidgetRef ref;
  const _BlockTile({required this.item, required this.ref});

  bool get _recurring => item.source == 'RECURRENCE';

  Future<void> _onDelete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Delete block?',
      message: 'This removes the block and any synced copies.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiClientProvider).deleteBlock(item.id);
      ref.invalidate(selfTimelineProvider);
      ref.invalidate(groupsProvider);
      if (context.mounted) toast(context, 'Block deleted');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (context.mounted) toast(context, 'Could not delete. Try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rangeLabel = item.allDay ? 'All day' : fmtRange(item.startTime, item.endTime);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.xs),
      child: OCard(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color bar
            Container(
              width: 4,
              height: 44,
              margin: const EdgeInsets.only(right: OrdoSpacing.md),
              decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title.isEmpty ? 'Busy' : item.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_recurring) ...[
                        const SizedBox(width: OrdoSpacing.xs),
                        Icon(Icons.repeat, size: 14, color: cs.onSecondary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: cs.onSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          rangeLabel,
                          style: TextStyle(fontSize: 12, color: cs.onSecondary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (item.location != null && item.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 13, color: cs.onSecondary),
                        const SizedBox(width: 4),
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
                ],
              ),
            ),
            if (item.isOwn)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSecondary),
                onSelected: (v) {
                  switch (v) {
                    case 'sync':
                      showSyncSheet(context, ref, item.id);
                    case 'delete':
                      _onDelete(context);
                  }
                },
                itemBuilder: (_) => [
                  // Sync is a self-block-only privacy feature (the backend's
                  // assertOwned requires ownerUserId === userId). Group blocks
                  // have source == 'GROUP', so hide it there to avoid a 403 that
                  // would leave the sheet spinning forever.
                  if (item.source == 'SELF')
                    const PopupMenuItem(value: 'sync', child: Text('Sync to groups')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Skeletons ────────────────────────────────────────────────────────────────
class _DaySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OSkeletonBox(
      ListView(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.sm),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int i = 0; i < 6; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(OrdoSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(OrdoRadius.lg),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    OSkeleton(height: 16, width: 160),
                    SizedBox(height: OrdoSpacing.sm),
                    OSkeleton(height: 12, width: 100),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OSkeletonBox(
      ListView(
        padding: const EdgeInsets.all(OrdoSpacing.lg),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: OrdoSpacing.md),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OSkeleton(height: 14, width: 90),
                  SizedBox(height: OrdoSpacing.sm),
                  OSkeleton(height: 16),
                  SizedBox(height: 6),
                  OSkeleton(height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
