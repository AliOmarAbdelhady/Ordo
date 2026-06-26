import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Group location sharing — strictly opt-in. Each member controls their own
/// share and the screen always shows a "your location is visible" warning when
/// sharing is on. Approximate mode fuzzes coordinates server-side.
class LocationPage extends ConsumerStatefulWidget {
  final String groupId;
  const LocationPage({super.key, required this.groupId});

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  // Foreground position pusher: while this page is open and the user has opted
  // in, we periodically read the device position and POST it. (Background
  // sharing would need a dedicated background service — out of scope for MVP.)
  Timer? _pushTimer;

  @override
  void dispose() {
    _stopPushing();
    super.dispose();
  }

  Future<void> _setMode(String mode) async {
    try {
      await ref.read(apiClientProvider).setLocationShare(widget.groupId, mode);
      ref.invalidate(locationsProvider(widget.groupId));
      if (!mounted) return;
      if (mode == 'OFF') {
        _stopPushing();
        toast(context, 'Location sharing off');
      } else {
        toast(context, 'Sharing your location');
        await _startPushing();
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _startPushing() async {
    _stopPushing();
    // Gracefully no-op when the device/OS won't let us read location.
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) toast(context, 'Enable device location to share live', error: true);
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) toast(context, 'Location permission denied', error: true);
      return;
    }
    await _pushOnce();
    _pushTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pushOnce());
  }

  void _stopPushing() {
    _pushTimer?.cancel();
    _pushTimer = null;
  }

  Future<void> _pushOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await ref.read(apiClientProvider).pushLocation(widget.groupId, pos.latitude, pos.longitude);
      if (mounted) ref.invalidate(locationsProvider(widget.groupId));
    } catch (_) {
      // Best-effort: a transient failure is retried on the next tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(locationsProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Couldn’t load', subtitle: '$e', action: TextButton(onPressed: () => ref.invalidate(locationsProvider(widget.groupId)), child: const Text('Retry'))),
        data: (list) {
          final mine = list.firstWhere((l) => l.isOwn, orElse: () => LocationMember(userId: '', name: '', mode: 'OFF', isOwn: true));
          final sharing = mine.mode != 'OFF';
          return ListView(
            padding: const EdgeInsets.all(OrdoSpacing.lg),
            children: [
              if (sharing)
                Container(
                  padding: const EdgeInsets.all(OrdoSpacing.md),
                  margin: const EdgeInsets.only(bottom: OrdoSpacing.md),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(OrdoRadius.md)),
                  child: const Row(children: [
                    Icon(Icons.visibility, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Your location is visible to this group.')),
                  ]),
                ),
              OCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Share my location', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Off · Approximate · Precise (temporary). Approximate fuzzes your point.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
                    const SizedBox(height: OrdoSpacing.sm),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(label: const Text('Off'), selected: mine.mode == 'OFF', onSelected: (_) => _setMode('OFF')),
                        ChoiceChip(label: const Text('Approximate'), selected: mine.mode == 'APPROXIMATE', onSelected: (_) => _setMode('APPROXIMATE')),
                        ChoiceChip(label: const Text('Precise'), selected: mine.mode == 'PRECISE_TEMPORARY', onSelected: (_) => _setMode('PRECISE_TEMPORARY')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: OrdoSpacing.lg),
              Text('Who’s sharing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSecondary, letterSpacing: 0.4)),
              const SizedBox(height: OrdoSpacing.sm),
              if (list.isEmpty)
                const OEmptyState(icon: Icons.location_on_outlined, title: 'Nobody is sharing', subtitle: 'Be the first to opt in.')
              else
                ...list.map((l) => _memberTile(l)),
            ],
          );
        },
      ),
    );
  }

  Widget _memberTile(LocationMember l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
      child: OCard(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
        child: Row(children: [
          CircleAvatar(child: Text(initials(l.name))),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.isOwn ? 'You' : l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (l.distanceMeters != null)
                  Text('${l.distanceMeters!.toStringAsFixed(0)} m away · ${l.mode}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary))
                else if (l.lat != null)
                  Text('${l.lat!.toStringAsFixed(3)}, ${l.lng!.toStringAsFixed(3)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary))
                else
                  Text('No point yet · ${l.mode}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
              ],
            ),
          ),
          if (l.isOwn && l.mode != 'OFF') OBadge(label: 'live', color: Colors.green),
        ]),
      ),
    );
  }
}
