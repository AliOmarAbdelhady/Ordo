import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import 'sync_sheet.dart';

const List<Color> _palette = [
  Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFDC2626), Color(0xFF9333EA),
  Color(0xFFEA580C), Color(0xFF0891B2), Color(0xFFDB2777), Color(0xFFCA8A04),
  Color(0xFF475569), Color(0xFF0D9488),
];

/// Opens the add-block sheet. [groupId] null → self space (enables sync).
/// Pass [initialStart]/[initialEnd] to pre-fill exact times (e.g. from a found
/// slot); otherwise [initialDate] seeds only the day with a rounded-now time.
Future<void> showAddBlockSheet(BuildContext context, WidgetRef ref,
    {String? groupId, DateTime? initialDate, DateTime? initialStart, DateTime? initialEnd}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AddBlockSheet(
      groupId: groupId,
      initialDate: initialDate,
      initialStart: initialStart,
      initialEnd: initialEnd,
      ref: ref,
    ),
  );
}

class _AddBlockSheet extends ConsumerStatefulWidget {
  final String? groupId;
  final DateTime? initialDate;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final WidgetRef ref;
  const _AddBlockSheet({this.groupId, this.initialDate, this.initialStart, this.initialEnd, required this.ref});

  @override
  ConsumerState<_AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends ConsumerState<_AddBlockSheet> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  bool _allDay = false;
  Color _color = _palette.first;
  String _visibility = 'PRIVATE';
  String _repeat = 'none';
  int? _reminder;
  bool _saving = false;
  final Map<String, String> _syncs = {}; // groupId -> visibility (self only)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialStart != null) {
      // Pre-filled from a found slot / external caller: honour the exact times.
      _start = widget.initialStart!;
      _end = widget.initialEnd ?? _start.add(const Duration(hours: 1));
    } else {
      final base = widget.initialDate ?? DateTime.now();
      _start = DateTime(base.year, base.month, base.day, now.hour, (now.minute / 15).ceil() * 15 % 60);
      if (_start.isBefore(now)) _start = _start.add(const Duration(hours: 1));
      _end = _start.add(const Duration(hours: 1));
    }
    if (widget.groupId != null) _visibility = 'TITLE_ONLY';
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _rrule() {
    switch (_repeat) {
      case 'daily':
        return 'FREQ=DAILY';
      case 'weekdays':
        return 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
      case 'weekly':
        const days = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
        return 'FREQ=WEEKLY;BYDAY=${days[_start.weekday % 7]}';
      default:
        return '';
    }
  }

  String _hex(Color c) => '#${c.toARGB32().toUnsigned(24).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'Add a title', error: true);
      return;
    }
    if (!_allDay && !_end.isAfter(_start)) {
      toast(context, 'End time must be after the start time', error: true);
      return;
    }
    setState(() => _saving = true);
    final api = widget.ref.read(apiClientProvider);
    try {
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'description': _notes.text.trim(),
        'startTime': _start.toUtc().toIso8601String(),
        'endTime': _end.toUtc().toIso8601String(),
        'allDay': _allDay,
        'color': _hex(_color),
        if (widget.groupId != null) 'groupId': widget.groupId,
        if (widget.groupId != null) 'visibility': _visibility,
        if (_repeat != 'none') 'recurrenceRule': _rrule(),
        if (_reminder != null) 'reminderMinutesBefore': _reminder,
        if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
      };
      final block = await api.createBlock(body);

      // Sync the self block to selected groups (the privacy feature).
      if (widget.groupId == null && _syncs.isNotEmpty) {
        await api.setSyncs(block.id, _syncs.entries.map((e) => SyncEntry(groupId: e.key, visibility: e.value)).toList());
      }

      // Invalidate timelines so the new block appears immediately. Invalidating
      // a family provider with no argument clears every cached date range, so the
      // active Day/Week/Month view refreshes without a manual pull.
      widget.ref.invalidate(groupsProvider);
      if (widget.groupId == null) {
        widget.ref.invalidate(selfTimelineProvider);
      }
      // Group timelines also change for a new group block, or when a self block
      // is synced into groups.
      if (widget.groupId != null || _syncs.isNotEmpty) {
        widget.ref.invalidate(groupTimelineProvider);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(context: context, initialDate: isStart ? _start : _end, firstDate: DateTime(2024), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() {
      if (isStart) {
        _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
      } else {
        _end = DateTime(d.year, d.month, d.day, _end.hour, _end.minute);
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(isStart ? _start : _end));
    if (t == null) return;
    setState(() {
      if (isStart) {
        _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
      } else {
        _end = DateTime(_end.year, _end.month, _end.day, t.hour, t.minute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelf = widget.groupId == null;
    final groups = widget.ref.watch(groupsProvider).valueOrNull ?? [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(OrdoSpacing.xl, 0, OrdoSpacing.xl, OrdoSpacing.xxl),
          children: [
            Text(isSelf ? 'New block' : 'New group event', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: OrdoSpacing.lg),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(hintText: 'What are you doing?', border: InputBorder.none),
            ),
            const Divider(),
            const SizedBox(height: OrdoSpacing.sm),

            // Date / time
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All-day'),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            if (!_allDay) ...[
              Row(children: [
                Expanded(child: _DateTimeChip(icon: Icons.event_outlined, label: 'Starts', value: '${fmtDate(_start)} · ${fmtTime(_start)}', onTap: () => _pickDate(true))),
                IconButton(onPressed: () => _pickTime(true), icon: const Icon(Icons.access_time)),
              ]),
              const SizedBox(height: OrdoSpacing.sm),
              Row(children: [
                Expanded(child: _DateTimeChip(icon: Icons.event_available_outlined, label: 'Ends', value: '${fmtDate(_end)} · ${fmtTime(_end)}', onTap: () => _pickDate(false))),
                IconButton(onPressed: () => _pickTime(false), icon: const Icon(Icons.access_time)),
              ]),
            ] else
              Wrap(
                spacing: OrdoSpacing.sm,
                children: [
                  ChoiceChip(label: Text(fmtDate(_start)), selected: false, onSelected: (_) => _pickDate(true)),
                  ChoiceChip(label: Text(fmtDate(_end)), selected: false, onSelected: (_) => _pickDate(false)),
                ],
              ),
            const SizedBox(height: OrdoSpacing.lg),

            // Color
            Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSecondary)),
            const SizedBox(height: OrdoSpacing.sm),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == c ? cs.onSurface : Colors.transparent, width: 3),
                      ),
                      child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: OrdoSpacing.lg),

            // Repeat
            _OptionRow(
              label: 'Repeat',
              child: DropdownButton<String>(
                value: _repeat,
                underline: const SizedBox(),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
                  DropdownMenuItem(value: 'daily', child: Text('Every day')),
                  DropdownMenuItem(value: 'weekdays', child: Text('Weekdays (Mon–Fri)')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                ],
                onChanged: (v) => setState(() => _repeat = v ?? 'none'),
              ),
            ),
            const SizedBox(height: OrdoSpacing.sm),

            // Reminder
            _OptionRow(
              label: 'Reminder',
              child: DropdownButton<int?>(
                value: _reminder,
                underline: const SizedBox(),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('No reminder')),
                  DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                  DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                  DropdownMenuItem(value: 60, child: Text('1 hour before')),
                ],
                onChanged: (v) => setState(() => _reminder = v),
              ),
            ),
            const SizedBox(height: OrdoSpacing.md),

            TextField(controller: _location, decoration: const InputDecoration(hintText: 'Add location', prefixIcon: Icon(Icons.place_outlined))),
            const SizedBox(height: OrdoSpacing.sm),
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Add notes'),
            ),

            // Visibility (group block) OR Sync (self block)
            if (!isSelf) ...[
              const SizedBox(height: OrdoSpacing.lg),
              Text('Who can see details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSecondary)),
              const SizedBox(height: OrdoSpacing.sm),
              Wrap(
                spacing: OrdoSpacing.sm,
                children: [
                  for (final v in ['FULL', 'TITLE_ONLY', 'BUSY_ONLY'])
                    ChoiceChip(
                      label: Text(const {'FULL': 'Full', 'TITLE_ONLY': 'Title', 'BUSY_ONLY': 'Busy only'}[v]!),
                      selected: _visibility == v,
                      onSelected: (_) => setState(() => _visibility = v),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: OrdoSpacing.lg),
              Row(children: [
                const Icon(Icons.share_outlined, size: 18),
                const SizedBox(width: OrdoSpacing.sm),
                Expanded(child: Text('Share with groups', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSecondary))),
                Text('Privacy', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: OrdoSpacing.xs),
              Text('Choose what each group sees — they never see your private details unless you allow it.',
                  style: TextStyle(fontSize: 12, color: cs.onSecondary, height: 1.35)),
              const SizedBox(height: OrdoSpacing.sm),
              if (groups.isEmpty)
                Text('Join or create a group to sync this block.', style: TextStyle(fontSize: 13, color: cs.onSecondary)),
              for (final g in groups)
                SyncRow(
                  name: g.name,
                  accent: g.accentColor,
                  visibility: _syncs[g.id],
                  onToggle: (vis) => setState(() {
                    if (vis == null) {
                      _syncs.remove(g.id);
                    } else {
                      _syncs[g.id] = vis;
                    }
                  }),
                ),
            ],

            const SizedBox(height: OrdoSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateTimeChip({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OrdoRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrdoRadius.md)),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _OptionRow({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 96, child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface))),
      Expanded(child: child),
    ]);
  }
}
