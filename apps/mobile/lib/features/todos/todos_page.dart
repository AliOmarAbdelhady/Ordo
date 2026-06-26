import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

enum _Tab { today, upcoming, noDate, done }

const _tabLabels = {
  _Tab.today: 'Today',
  _Tab.upcoming: 'Upcoming',
  _Tab.noDate: 'No date',
  _Tab.done: 'Done',
};

const _tabApi = {
  _Tab.today: 'today',
  _Tab.upcoming: 'upcoming',
  _Tab.noDate: 'no_date',
  _Tab.done: 'done',
};

class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({super.key});

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage> {
  _Tab _tab = _Tab.today;
  final _addController = TextEditingController();
  bool _adding = false;
  // Optimistic toggle state: flip the checkbox instantly, guard against
  // double-taps firing a second PATCH, revert on error.
  final Set<String> _pending = {};
  final Map<String, bool> _doneOverride = {};

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  ({String? groupId, String tab}) get _query => (groupId: null, tab: _tabApi[_tab]!);

  Future<void> _addTodo() async {
    final title = _addController.text.trim();
    if (title.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ref.read(apiClientProvider).createTodo({'title': title});
      _addController.clear();
      ref.invalidate(todosProvider(_query));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not add to-do.', error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleDone(Todo todo) async {
    if (_pending.contains(todo.id)) return; // ignore double-taps mid-flight
    final next = !todo.done;
    setState(() {
      _pending.add(todo.id);
      _doneOverride[todo.id] = next;
    });
    try {
      await ref.read(apiClientProvider).updateTodo(todo.id, {'done': next});
      ref.invalidate(todosProvider(_query));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _doneOverride.remove(todo.id)); // revert optimistic flip
        toast(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _doneOverride.remove(todo.id));
        toast(context, 'Could not update to-do.', error: true);
      }
    } finally {
      if (mounted) setState(() => _pending.remove(todo.id));
    }
  }

  Future<void> _deleteTodo(Todo todo) async {
    final ok = await confirm(context, title: 'Delete to-do?', message: todo.title, confirmText: 'Delete', danger: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(apiClientProvider).deleteTodo(todo.id);
      ref.invalidate(todosProvider(_query));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not delete to-do.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final asyncTodos = ref.watch(todosProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('To-do')),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.sm),
              child: OSegmented<_Tab>(
                segments: _Tab.values,
                value: _tab,
                label: (t) => _tabLabels[t]!,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),

            // Fast add field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Add a to-do…', isDense: true),
                      onSubmitted: (_) => _addTodo(),
                    ),
                  ),
                  const SizedBox(width: OrdoSpacing.sm),
                  IconButton.filled(
                    onPressed: _adding ? null : _addTodo,
                    icon: _adding
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OrdoSpacing.sm),

            // List
            Expanded(
              child: asyncTodos.when(
                loading: () => OSkeletonBox(
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                    children: const [
                      SizedBox(height: OrdoSpacing.md),
                      OSkeleton(height: 52),
                      SizedBox(height: OrdoSpacing.sm),
                      OSkeleton(height: 52),
                      SizedBox(height: OrdoSpacing.sm),
                      OSkeleton(height: 52),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(OrdoSpacing.xl),
                    child: Text(
                      e is ApiException ? e.message : 'Could not load to-dos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSecondary),
                    ),
                  ),
                ),
                data: (todos) {
                  if (todos.isEmpty) {
                    return OEmptyState(
                      icon: Icons.check_circle_outline,
                      title: _emptyTitle(_tab),
                      subtitle: _emptySubtitle(_tab),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.sm, OrdoSpacing.lg, OrdoSpacing.xxl),
                    itemCount: todos.length,
                    itemBuilder: (_, i) {
                      final todo = todos[i];
                      final done = _doneOverride[todo.id] ?? todo.done;
                      return Dismissible(
                        key: ValueKey(todo.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: OrdoSpacing.lg),
                          decoration: BoxDecoration(
                            color: cs.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(OrdoRadius.lg),
                          ),
                          child: Icon(Icons.delete_outline, color: cs.error),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteTodo(todo);
                          return false;
                        },
                        child: _TodoTile(todo: todo, done: done, onToggle: () => _toggleDone(todo), onDelete: () => _deleteTodo(todo)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _emptyTitle(_Tab tab) {
  switch (tab) {
    case _Tab.today:
      return 'Nothing for today';
    case _Tab.upcoming:
      return 'No upcoming to-dos';
    case _Tab.noDate:
      return 'No undated to-dos';
    case _Tab.done:
      return 'Nothing completed yet';
  }
}

String _emptySubtitle(_Tab tab) {
  switch (tab) {
    case _Tab.today:
      return 'Add one above to get started.';
    case _Tab.upcoming:
      return 'To-dos with a future due date show up here.';
    case _Tab.noDate:
      return 'To-dos without a due date live here.';
    case _Tab.done:
      return 'Completed to-dos will appear here.';
  }
}

class _TodoTile extends StatelessWidget {
  final Todo todo;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _TodoTile({required this.todo, required this.done, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OCard(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.sm + 2),
      child: Row(
        children: [
          _RoundCheckbox(checked: done, onTap: onToggle),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                    color: done ? cs.onSecondary : cs.onSurface,
                  ),
                ),
                if (todo.dueAt != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 13, color: cs.onSecondary),
                      const SizedBox(width: 3),
                      Text(
                        dayLabel(todo.dueAt!),
                        style: TextStyle(fontSize: 12, color: cs.onSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            color: cs.onSecondary,
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(todo.done ? Icons.undo : Icons.check_circle_outline),
              title: Text(todo.done ? 'Mark not done' : 'Mark done'),
              onTap: () {
                Navigator.pop(ctx);
                onToggle();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
            const SizedBox(height: OrdoSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _RoundCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const _RoundCheckbox({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? cs.primary : Colors.transparent,
          border: Border.all(color: checked ? cs.primary : cs.outline, width: 2),
        ),
        child: checked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }
}
