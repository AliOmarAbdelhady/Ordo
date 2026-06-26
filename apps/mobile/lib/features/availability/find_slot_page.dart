import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import '../timeline/add_block_sheet.dart';

const _durations = [30, 60, 90, 120];

const _windowLabels = {
  'morning': 'Morning',
  'afternoon': 'Afternoon',
  'evening': 'Evening',
  'night': 'Night',
};
const _windowOptions = ['morning', 'afternoon', 'evening', 'night'];

class FindSlotPage extends ConsumerWidget {
  final String? groupId;
  const FindSlotPage({super.key, this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a slot')),
      body: SafeArea(
        child: groupId == null
            ? _GroupPicker(onSelect: (id) => context.go('/find-slot?groupId=$id'))
            : _FindSlotForm(groupId: groupId!),
      ),
    );
  }
}

class _GroupPicker extends ConsumerWidget {
  final void Function(String id) onSelect;
  const _GroupPicker({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroups = ref.watch(groupsProvider);
    return asyncGroups.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(OrdoSpacing.xl),
          child: Text(
            e is ApiException ? e.message : 'Could not load groups.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
          ),
        ),
      ),
      data: (groups) {
        final available = groups.where((g) => g.modules.availability).toList();
        if (available.isEmpty) {
          return const OEmptyState(
            icon: Icons.group_off_outlined,
            title: 'No groups with availability',
            subtitle: 'Join or create a group that has availability enabled.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.md, OrdoSpacing.lg, OrdoSpacing.xxl),
          children: [
            const SizedBox(height: OrdoSpacing.sm),
            OSectionHeader(title: 'Choose a group'),
            for (final g in available)
              Padding(
                padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
                child: OCard(
                  onTap: () => onSelect(g.id),
                  child: Row(
                    children: [
                      OGroupAvatar(name: g.name, accent: g.accentColor),
                      const SizedBox(width: OrdoSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text('${g.memberCount} members',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSecondary),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FindSlotForm extends ConsumerStatefulWidget {
  final String groupId;
  const _FindSlotForm({required this.groupId});

  @override
  ConsumerState<_FindSlotForm> createState() => _FindSlotFormState();
}

class _FindSlotFormState extends ConsumerState<_FindSlotForm> {
  DateTime _rangeStart = startOfDay(DateTime.now());
  DateTime _rangeEnd = addDays(DateTime.now(), 7);
  int _duration = 60;
  int _minimum = 2;
  final Set<String> _windows = {'morning', 'afternoon', 'evening'};
  final Set<String> _requiredMemberIds = {};

  bool _searching = false;
  ({List<SlotResult> slots, List<MemberRef> members, int totalMembers})? _result;
  String? _searchError;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _rangeStart : _rangeEnd,
      firstDate: startOfDay(DateTime.now()),
      lastDate: addDays(DateTime.now(), 365),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _rangeStart = picked;
        if (_rangeEnd.isBefore(_rangeStart)) _rangeEnd = addDays(_rangeStart, 1);
      } else {
        _rangeEnd = picked;
        if (_rangeEnd.isBefore(_rangeStart)) _rangeStart = _rangeEnd;
      }
    });
  }

  void _applySevenDays() => setState(() {
        _rangeStart = startOfDay(DateTime.now());
        _rangeEnd = addDays(DateTime.now(), 7);
      });

  Future<void> _findSlots() async {
    setState(() {
      _searching = true;
      _searchError = null;
      _result = null;
    });
    try {
      final res = await ref.read(apiClientProvider).findSlots(
            widget.groupId,
            _rangeStart,
            _rangeEnd,
            _duration,
            required: _requiredMemberIds.isEmpty ? null : _requiredMemberIds.toList(),
            minimum: _minimum,
            windows: _windows.isEmpty ? null : _windows.toList(),
          );
      if (mounted) setState(() => _result = res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } catch (_) {
      if (mounted) setState(() => _searchError = 'Could not find slots. Try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final groupDetail = ref.watch(groupDetailProvider(widget.groupId));
    final detail = groupDetail.valueOrNull;
    final groupName = detail?.name ?? 'Group';
    final memberCount = detail?.memberCount ?? 0;
    final members = detail?.members ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
      children: [
        // Selected group chip
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(OrdoRadius.pill),
                ),
                child: Row(
                  children: [
                    OGroupAvatar(name: groupName, accent: detail?.accentColor ?? 'blue', size: 28),
                    const SizedBox(width: OrdoSpacing.sm),
                    Expanded(
                      child: Text(groupName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: OrdoSpacing.sm),
            TextButton(
              onPressed: () => context.go('/find-slot'),
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: OrdoSpacing.lg),

        // Date range
        OField(
          label: 'Date range',
          child: Row(
            children: [
              Expanded(child: _DateChip(label: fmtDate(_rangeStart), onTap: () => _pickDate(true))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('–')),
              Expanded(child: _DateChip(label: fmtDate(_rangeEnd), onTap: () => _pickDate(false))),
              const SizedBox(width: OrdoSpacing.sm),
              TextButton(onPressed: _applySevenDays, child: const Text('7 days')),
            ],
          ),
        ),
        const SizedBox(height: OrdoSpacing.md),

        // Duration
        OField(
          label: 'Duration',
          child: DropdownButton<int>(
            value: _duration,
            underline: const SizedBox(),
            isExpanded: true,
            items: [
              for (final d in _durations) DropdownMenuItem(value: d, child: Text(fmtDuration(d))),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _duration = v);
            },
          ),
        ),
        const SizedBox(height: OrdoSpacing.md),

        // Minimum available
        OField(
          label: 'Minimum available',
          child: Row(
            children: [
              IconButton(
                onPressed: _minimum > 1 ? () => setState(() => _minimum--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_minimum', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: (memberCount == 0 || _minimum < memberCount)
                    ? () => setState(() => _minimum++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
              const Spacer(),
              if (memberCount > 0)
                TextButton(
                  onPressed: () => setState(() => _minimum = memberCount),
                  child: Text('All ($memberCount)'),
                ),
            ],
          ),
        ),
        const SizedBox(height: OrdoSpacing.md),

        // Preferred windows
        OField(
          label: 'Preferred windows',
          child: Wrap(
            spacing: OrdoSpacing.sm,
            runSpacing: OrdoSpacing.sm,
            children: [
              for (final w in _windowOptions)
                ChoiceChip(
                  label: Text(_windowLabels[w]!),
                  selected: _windows.contains(w),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _windows.add(w);
                    } else {
                      _windows.remove(w);
                    }
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: OrdoSpacing.md),

        // Required members
        if (members.isNotEmpty) ...[
          OField(
            label: 'Required members (optional)',
            child: Wrap(
              spacing: OrdoSpacing.sm,
              runSpacing: OrdoSpacing.sm,
              children: [
                for (final m in members)
                  FilterChip(
                    avatar: OAvatar(name: m.name, imageUrl: m.avatarUrl, radius: 12),
                    label: Text(m.name),
                    selected: _requiredMemberIds.contains(m.userId),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _requiredMemberIds.add(m.userId);
                      } else {
                        _requiredMemberIds.remove(m.userId);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: OrdoSpacing.lg),
        ] else ...[
          const SizedBox(height: OrdoSpacing.lg),
        ],

        // Find button
        FilledButton.icon(
          onPressed: _searching ? null : _findSlots,
          icon: _searching
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.search, size: 20),
          label: const Text('Find slots'),
        ),

        // Results
        if (_searchError != null) ...[
          const SizedBox(height: OrdoSpacing.lg),
          Center(
            child: Text(_searchError!,
                textAlign: TextAlign.center, style: TextStyle(color: cs.error, fontSize: 13)),
          ),
        ],
        if (_searching) ...[
          const SizedBox(height: OrdoSpacing.xl),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_result != null && !_searching) ...[
          const SizedBox(height: OrdoSpacing.lg),
          OSectionHeader(
            title: '${_result!.slots.length} slot${_result!.slots.length == 1 ? '' : 's'} found',
          ),
          if (_result!.slots.isEmpty)
            const OEmptyState(
              icon: Icons.event_busy,
              title: 'No common slots',
              subtitle: 'No common slots — try widening the range.',
            )
          else
            for (final slot in _result!.slots) ...[
              _SlotCard(
                slot: slot,
                members: _result!.members,
                isDark: isDark,
                onCreate: () => showAddBlockSheet(
                  context,
                  ref,
                  groupId: widget.groupId,
                  initialDate: slot.start,
                ),
              ),
              const SizedBox(height: OrdoSpacing.sm),
            ],
        ],
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OrdoRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.event_outlined, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrdoRadius.md)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final SlotResult slot;
  final List<MemberRef> members;
  final bool isDark;
  final VoidCallback onCreate;
  const _SlotCard({required this.slot, required this.members, required this.isDark, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final available = members.where((m) => !slot.unavailableMemberIds.contains(m.id)).toList();

    return OCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayLabel(slot.start), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(fmtRange(slot.start, slot.end),
                        style: TextStyle(fontSize: 12, color: cs.onSecondary)),
                  ],
                ),
              ),
              OBadge(
                label: '${slot.availableCount}/${slot.totalCount}',
                color: OrdoAccent.emerald.primary(isDark),
              ),
            ],
          ),
          const SizedBox(height: OrdoSpacing.sm),
          if (available.isNotEmpty)
            OAvatarStack(
              names: available.map((m) => m.name).toList(),
              images: available.map((m) => m.avatarUrl).toList(),
            )
          else
            Text('No members available', style: TextStyle(fontSize: 12, color: cs.onSecondary)),
          const SizedBox(height: OrdoSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(OrdoRadius.pill),
            child: LinearProgressIndicator(
              value: slot.score.clamp(0.0, 1.0),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: OrdoSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create event'),
            ),
          ),
        ],
      ),
    );
  }
}
