import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

/// Start a 1:1 conversation. Pick one of your groups, then a member. The backend
/// only allows DMs between members who share a group.
class NewDmPage extends ConsumerStatefulWidget {
  const NewDmPage({super.key});

  @override
  ConsumerState<NewDmPage> createState() => _NewDmPageState();
}

class _NewDmPageState extends ConsumerState<NewDmPage> {
  String? _groupId;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.md, OrdoSpacing.lg, OrdoSpacing.sm),
            child: groups.when(
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (list) => DropdownButtonFormField<String>(
                value: _groupId,
                decoration: const InputDecoration(labelText: 'From group', border: OutlineInputBorder()),
                items: list.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                onChanged: (v) => setState(() => _groupId = v),
              ),
            ),
          ),
          if (_groupId != null)
            Expanded(child: _memberList(context, ref, _groupId!))
          else
            const Expanded(child: OEmptyState(icon: Icons.groups_2_outlined, title: 'Pick a group', subtitle: 'You can message people you share a group with.')),
        ],
      ),
    );
  }

  Widget _memberList(BuildContext context, WidgetRef ref, String groupId) {
    final members = ref.watch(groupMembersProvider(groupId));
    final me = ref.watch(authControllerProvider).valueOrNull?.id;
    return members.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Couldn’t load members', subtitle: '$e'),
      data: (list) {
        final others = list.where((m) => m.userId != me).toList();
        if (others.isEmpty) return const OEmptyState(icon: Icons.person_outline, title: 'No other members');
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
          itemCount: others.length,
          itemBuilder: (_, i) {
            final m = others[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
              child: OCard(
                onTap: () => _start(context, ref, m.userId),
                child: Row(children: [
                  CircleAvatar(child: Text(m.name.isNotEmpty ? m.name[0] : '?')),
                  const SizedBox(width: OrdoSpacing.md),
                  Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref, String otherUserId) async {
    try {
      final threadId = await ref.read(apiClientProvider).startDm(otherUserId);
      ref.invalidate(dmThreadsProvider);
      if (!mounted) return;
      context.go('/inbox/dm/$threadId');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }
}
