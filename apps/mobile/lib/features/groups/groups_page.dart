import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});
  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _joinWithCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Join with code'),
          content: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Enter invite code'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Join')),
          ],
        );
      },
    );
    if (code == null || code.isEmpty || !mounted) return;

    try {
      final groupId = await ref.read(apiClientProvider).joinByCode(code);
      ref.invalidate(groupsProvider);
      if (mounted) context.go('/groups/$groupId');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not join group. Try again.', error: true);
    }
  }

  bool _matches(Group g) => _query.isEmpty || g.name.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Groups'),
              floating: true,
              pinned: false,
              snap: true,
              actions: [
                IconButton(
                  tooltip: 'Join with code',
                  icon: const Icon(Icons.qr_code_2_outlined),
                  onPressed: _joinWithCode,
                ),
                IconButton(
                  tooltip: 'New group',
                  icon: const Icon(Icons.add),
                  onPressed: () => context.push('/groups/create'),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, 0, OrdoSpacing.lg, OrdoSpacing.md),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search groups',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(groupsProvider),
              child: groupsAsync.when(
                loading: () => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _GroupListSkeleton(),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: OEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load groups',
                    subtitle: e.toString(),
                    action: FilledButton.icon(
                      onPressed: () => ref.invalidate(groupsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ),
                ),
                data: (all) {
                  final filtered = all.where(_matches).toList();
                  if (all.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: OEmptyState(
                        icon: Icons.groups_outlined,
                        title: 'No groups yet',
                        subtitle: 'Create a group or join one with a code.',
                        action: FilledButton.icon(
                          onPressed: () => context.push('/groups/create'),
                          icon: const Icon(Icons.add),
                          label: const Text('New group'),
                        ),
                      ),
                    );
                  }
                  if (filtered.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: OEmptyState(
                        icon: Icons.search_off,
                        title: 'No matches',
                        subtitle: 'Try a different search.',
                      ),
                    );
                  }

                  final pinned = filtered.where((g) => g.pinned).toList();
                  final rest = filtered.where((g) => !g.pinned).toList();

                  return MultiSliverList(
                    pinned: pinned,
                    rest: rest,
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

/// Renders optional pinned + all sections with section headers.
class MultiSliverList extends StatelessWidget {
  final List<Group> pinned;
  final List<Group> rest;
  const MultiSliverList({super.key, required this.pinned, required this.rest});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        if (pinned.isNotEmpty) ...[
          const SliverToBoxAdapter(child: OSectionHeader(title: 'Pinned')),
          SliverList.builder(
            itemCount: pinned.length,
            itemBuilder: (_, i) => _GroupTile(group: pinned[i]),
          ),
        ],
        if (rest.isNotEmpty) ...[
          const SliverToBoxAdapter(child: OSectionHeader(title: 'All groups')),
          SliverList.builder(
            itemCount: rest.length,
            itemBuilder: (_, i) => _GroupTile(group: rest[i]),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: OrdoSpacing.xxl)),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;
  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = OrdoAccent.byName(group.accentColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.xs),
      child: OCard(
        onTap: () => context.push('/groups/${group.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OGroupAvatar(name: group.name, accent: group.accentColor, size: 46),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (group.pinned)
                        Padding(
                          padding: const EdgeInsets.only(left: OrdoSpacing.xs),
                          child: Icon(Icons.push_pin, size: 14, color: accent.primary(Theme.of(context).brightness == Brightness.dark)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: OrdoSpacing.xs,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OBadge(label: _typeLabel(group.type)),
                      if (group.unreadCount > 0)
                        OBadge(
                          label: '${group.unreadCount}',
                          color: accent.primary(Theme.of(context).brightness == Brightness.dark),
                          icon: Icons.mark_chat_unread,
                        ),
                      if (group.pendingTaskCount > 0)
                        OBadge(
                          label: '${group.pendingTaskCount} task${group.pendingTaskCount == 1 ? '' : 's'}',
                          icon: Icons.check_circle_outline,
                        ),
                    ],
                  ),
                  if (group.description != null && group.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      group.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: cs.onSecondary),
                    ),
                  ],
                  const SizedBox(height: OrdoSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: cs.onSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                        style: TextStyle(fontSize: 12, color: cs.onSecondary),
                      ),
                      if (group.nextEvent != null) ...[
                        const SizedBox(width: OrdoSpacing.md),
                        Icon(Icons.event_outlined, size: 14, color: accent.primary(Theme.of(context).brightness == Brightness.dark)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${dayLabel(group.nextEvent!.startTime)} · ${fmtTime(group.nextEvent!.startTime)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: cs.onSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: OrdoSpacing.sm),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Prisma GroupType enum: FAMILY, FRIENDS, UNIVERSITY, GYM, SPORTS, WORK,
  // PROJECT, TRAVEL, CUSTOM. Title-case the enum value (CUSTOM -> 'Custom').
  String _typeLabel(String type) {
    if (type.isEmpty) return 'Custom';
    return type[0] + type.substring(1).toLowerCase();
  }
}

class _GroupListSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(OrdoSpacing.lg),
        children: [
          const OSkeleton(width: 90, height: 12),
          const SizedBox(height: OrdoSpacing.sm),
          for (int i = 0; i < 3; i++) ...[
            OSkeleton(height: 92, radius: OrdoRadius.lg),
            const SizedBox(height: OrdoSpacing.sm),
          ],
        ],
      ),
    );
  }
}
