import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_views.dart';

/// Standalone route wrapper around [PollsView]. Deep-link: /groups/:id/polls.
class PollsPage extends ConsumerWidget {
  final String groupId;
  const PollsPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreatePollSheet(context, ref, groupId),
        child: const Icon(Icons.add),
      ),
      body: PollsView(groupId: groupId),
    );
  }
}
