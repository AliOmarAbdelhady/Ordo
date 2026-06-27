import 'package:flutter/material.dart';

import '../groups/group_views.dart';

/// Standalone route wrapper around [LocationView]. Deep-link: /groups/:id/location.
/// When shown as a full page the view is always active, so the live-location
/// pusher runs whenever sharing is on.
class LocationPage extends StatelessWidget {
  final String groupId;
  const LocationPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: LocationView(groupId: groupId, active: true),
    );
  }
}
