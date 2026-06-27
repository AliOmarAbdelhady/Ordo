import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../groups/group_views.dart';

/// Standalone route wrapper around [FilesView]. Deep-link: /groups/:id/files.
class FilesPage extends ConsumerWidget {
  final String? groupId;
  const FilesPage({super.key, this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Files')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pickGroupFile(context, ref, groupId),
        child: const Icon(Icons.upload_file),
      ),
      body: FilesView(groupId: groupId),
    );
  }
}
