import 'package:flutter/material.dart';

import 'group_views.dart';

/// Standalone route wrapper around [GroupSettingsView]. Deep-link: /groups/:id/settings.
class GroupSettingsPage extends StatelessWidget {
  final String groupId;
  const GroupSettingsPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: GroupSettingsView(groupId: groupId),
    );
  }
}
