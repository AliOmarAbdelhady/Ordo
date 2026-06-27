import 'package:flutter/material.dart';

import '../groups/group_views.dart';

/// Standalone route wrapper around [CopilotView]. Deep-link: /assistant?groupId=.
class AiAssistantPage extends StatelessWidget {
  final String? groupId;
  const AiAssistantPage({super.key, this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ordo Copilot')),
      body: CopilotView(groupId: groupId),
    );
  }
}
