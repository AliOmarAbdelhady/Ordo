import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Global search across the user's groups, tasks, to-dos, messages and blocks.
/// The server enforces object-level authorization — only content in groups the
/// viewer belongs to (or owns) is matched, and timeline hits are privacy-redacted.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  SearchResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onChanged() async {
    final q = _controller.text.trim();
    if (q.length < 2) {
      setState(() {
        _result = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).search(q);
      if (!mounted) return;
      setState(() {
        _result = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _open(SearchHit hit) {
    switch (hit.kind) {
      case 'group':
        if (hit.groupId != null) context.push('/groups/${hit.groupId}');
        break;
      case 'task':
        context.push('/tasks/${hit.id}');
        break;
      case 'todo':
        context.go('/timeline/todos');
        break;
      case 'message':
        if (hit.groupId != null) context.push('/groups/${hit.groupId}/chat');
        break;
      case 'block':
        context.go('/timeline');
        break;
    }
  }

  IconData _icon(String kind) => switch (kind) {
        'group' => Icons.groups_2_outlined,
        'task' => Icons.task_outlined,
        'todo' => Icons.check_circle_outline,
        'message' => Icons.chat_bubble_outline,
        _ => Icons.schedule_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.md, OrdoSpacing.lg, OrdoSpacing.sm),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Groups, tasks, to-dos, messages…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close), onPressed: () => _controller.clear())
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrdoRadius.md), borderSide: BorderSide.none),
                filled: true,
                fillColor: cs.surfaceContainer,
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_controller.text.trim().length < 2) {
      return const OEmptyState(icon: Icons.search, title: 'Search Ordo', subtitle: 'Find groups, tasks, to-dos and messages.');
    }
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return OEmptyState(icon: Icons.error_outline, title: 'Search failed', subtitle: _error, action: TextButton(onPressed: _onChanged, child: const Text('Retry')));
    }
    final hits = _result?.hits ?? [];
    if (hits.isEmpty) {
      return OEmptyState(icon: Icons.manage_search, title: 'No results', subtitle: 'Try a different keyword.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.sm),
      itemCount: hits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final h = hits[i];
        return OCard(
          padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
          onTap: () => _open(h),
          child: Row(
            children: [
              Icon(_icon(h.kind), color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: OrdoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (h.subtitle != null)
                      Text(h.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OBadge(label: h.kind),
            ],
          ),
        );
      },
    );
  }
}
