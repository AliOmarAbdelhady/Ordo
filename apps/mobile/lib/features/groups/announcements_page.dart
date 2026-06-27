import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_views.dart';

/// Standalone route wrapper around [AnnouncementsView]. Deep-link: /groups/:id/announcements.
class AnnouncementsPage extends ConsumerWidget {
  final String groupId;
  const AnnouncementsPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateAnnouncementSheet(context, ref, groupId),
        child: const Icon(Icons.add),
      ),
      body: AnnouncementsView(groupId: groupId),
    );
  }
}
