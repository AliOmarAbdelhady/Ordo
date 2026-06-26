import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

const _statusSegments = ['TODO', 'IN_PROGRESS', 'BLOCKED', 'DONE'];
const _statusLabels = {
  'TODO': 'To do',
  'IN_PROGRESS': 'In progress',
  'BLOCKED': 'Blocked',
  'DONE': 'Done',
};

class TaskDetailPage extends ConsumerWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(taskDetailProvider(taskId));
    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: SafeArea(
        child: asyncDetail.when(
          loading: () => const _TaskSkeleton(),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(OrdoSpacing.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not load this task.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
              ),
            ),
          ),
          data: (data) => _TaskBody(taskId: taskId, task: data.task, comments: data.comments),
        ),
      ),
    );
  }
}

class _TaskBody extends ConsumerStatefulWidget {
  final String taskId;
  final Task task;
  final List<TaskComment> comments;
  const _TaskBody({required this.taskId, required this.task, required this.comments});

  @override
  ConsumerState<_TaskBody> createState() => _TaskBodyState();
}

class _TaskBodyState extends ConsumerState<_TaskBody> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String status) async {
    if (status == widget.task.status) return;
    try {
      await ref.read(apiClientProvider).updateTask(widget.taskId, {'status': status});
      ref.invalidate(taskDetailProvider(widget.taskId));
      _invalidateList();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not update status.', error: true);
    }
  }

  Future<void> _pickDue() async {
    final initial = widget.task.dueAt ?? DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    final due = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    try {
      await ref.read(apiClientProvider).updateTask(widget.taskId, {'dueAt': due.toUtc().toIso8601String()});
      ref.invalidate(taskDetailProvider(widget.taskId));
      _invalidateList();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not update due date.', error: true);
    }
  }

  /// Refresh the parent group's task list (All + Mine tabs) so the card reflects
  /// the edit on back-navigation. Without this the mounted list shows stale data.
  void _invalidateList() {
    ref.invalidate(tasksProvider((groupId: widget.task.groupId, tab: 'all')));
    ref.invalidate(tasksProvider((groupId: widget.task.groupId, tab: 'mine')));
  }

  Future<void> _editTask() async {
    final titleCtrl = TextEditingController(text: widget.task.title);
    final descCtrl = TextEditingController(text: widget.task.description ?? '');
    String priority = widget.task.priority;
    const priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Edit task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: OrdoSpacing.sm),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: OrdoSpacing.sm),
                DropdownButton<String>(
                  value: priority,
                  isExpanded: true,
                  items: priorities
                      .map((p) => DropdownMenuItem(value: p, child: Text(p[0] + p.substring(1).toLowerCase())))
                      .toList(),
                  onChanged: (v) => setSt(() => priority = v ?? priority),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final newTitle = titleCtrl.text.trim();
    if (newTitle.isEmpty) {
      if (mounted) toast(context, 'Title cannot be empty', error: true);
      return;
    }
    try {
      await ref.read(apiClientProvider).updateTask(widget.taskId, {
        'title': newTitle,
        'description': descCtrl.text.trim(),
        'priority': priority,
      });
      ref.invalidate(taskDetailProvider(widget.taskId));
      _invalidateList();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not save edits.', error: true);
    }
  }

  Future<void> _deleteTask() async {
    final ok = await confirm(
      context,
      title: 'Delete task?',
      message: 'This task and its comments will be permanently removed.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiClientProvider).deleteTask(widget.taskId);
      _invalidateList();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not delete task.', error: true);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).addComment(widget.taskId, text);
      _commentController.clear();
      ref.invalidate(taskDetailProvider(widget.taskId));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not send comment.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final task = widget.task;

    return ListView(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
      children: [
        // Title row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit task',
              onPressed: _editTask,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
              tooltip: 'Delete task',
              onPressed: _deleteTask,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: OrdoSpacing.md),

        // Status segmented
        OSegmented<String>(
          segments: _statusSegments,
          value: task.status,
          label: (s) => _statusLabels[s] ?? s,
          onChanged: _setStatus,
        ),
        const SizedBox(height: OrdoSpacing.md),

        // Priority + due row
        Wrap(
          spacing: OrdoSpacing.sm,
          runSpacing: OrdoSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OBadge(
              label: task.priority,
              color: priorityColor(task.priority, isDark),
              icon: Icons.flag_outlined,
            ),
            GestureDetector(
              onTap: _pickDue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(OrdoRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_outlined, size: 14, color: cs.onSecondary),
                    const SizedBox(width: 4),
                    Text(
                      task.dueAt != null ? fmtDateTime(task.dueAt!) : 'No due date',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: OrdoSpacing.lg),

        // Assignees
        if (task.assignees.isNotEmpty) ...[
          OSectionHeader(title: 'Assigned to'),
          Row(
            children: [
              OAvatarStack(
                names: task.assignees.map((a) => a.name).toList(),
                images: task.assignees.map((a) => a.avatarUrl).toList(),
              ),
              const SizedBox(width: OrdoSpacing.md),
              Expanded(
                child: Text(
                  task.assignees.map((a) => a.name).join(', '),
                  style: TextStyle(fontSize: 13, color: cs.onSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: OrdoSpacing.lg),
        ],

        // Description
        if (task.description != null && task.description!.isNotEmpty) ...[
          OSectionHeader(title: 'Description'),
          OCard(
            child: Text(task.description!, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: OrdoSpacing.lg),
        ],

        // Comments
        OSectionHeader(title: 'Comments'),
        if (widget.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: OrdoSpacing.md),
            child: Text('No comments yet.', style: TextStyle(color: cs.onSecondary, fontSize: 13)),
          )
        else
          for (final c in widget.comments) ...[
            _CommentTile(comment: c),
            const SizedBox(height: OrdoSpacing.md),
          ],

        // Composer
        const SizedBox(height: OrdoSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Write a comment…'),
                onSubmitted: (_) => _addComment(),
              ),
            ),
            const SizedBox(width: OrdoSpacing.sm),
            IconButton.filled(
              onPressed: _sending ? null : _addComment,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final TaskComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OAvatar(name: comment.userName, imageUrl: comment.userAvatar, radius: 16),
        const SizedBox(width: OrdoSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.userName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: OrdoSpacing.sm),
                  Text(
                    fmtRelative(comment.createdAt),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(comment.body, style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskSkeleton extends StatelessWidget {
  const _TaskSkeleton();
  @override
  Widget build(BuildContext context) {
    return OSkeletonBox(
      ListView(
        padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.md, OrdoSpacing.lg, OrdoSpacing.xxl),
        children: [
          const OSkeleton(height: 24, width: 220),
          const SizedBox(height: OrdoSpacing.md),
          const OSkeleton(height: 38),
          const SizedBox(height: OrdoSpacing.md),
          const OSkeleton(height: 24, width: 160),
          const SizedBox(height: OrdoSpacing.xl),
          const OSkeleton(height: 14, width: 100),
          const SizedBox(height: OrdoSpacing.sm),
          const OSkeleton(height: 64),
          const SizedBox(height: OrdoSpacing.lg),
          const OSkeleton(height: 14, width: 80),
          const SizedBox(height: OrdoSpacing.sm),
          for (int i = 0; i < 3; i++) ...[
            const OSkeleton(height: 48),
            const SizedBox(height: OrdoSpacing.sm),
          ],
        ],
      ),
    );
  }
}
