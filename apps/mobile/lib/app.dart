import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/auth_controller.dart';
import 'core/api.dart';
import 'core/providers.dart';
import 'core/realtime.dart';
import 'core/router.dart';
import 'core/settings.dart';
import 'models/models.dart';

class OrdoApp extends ConsumerStatefulWidget {
  const OrdoApp({super.key});
  @override
  ConsumerState<OrdoApp> createState() => _OrdoAppState();
}

class _OrdoAppState extends ConsumerState<OrdoApp> {
  StreamSubscription<RealtimeEvent>? _notifSub;

  @override
  void initState() {
    super.initState();
    // Connect realtime + start the notification listener as soon as we have a session.
    Future.microtask(() {
      _maybeConnect();
      _ensureNotifListener();
    });
  }

  void _maybeConnect() {
    final auth = ref.read(authControllerProvider);
    final user = auth.valueOrNull;
    final tokens = ref.read(tokenStoreProvider);
    if (user != null && tokens.access != null) {
      ref.read(realtimeProvider).connect(tokens.access!);
    }
  }

  /// Long-lived subscription to the realtime stream: when the server pushes a
  /// `notification` (task assigned, mention, reminder), refresh the inbox list
  /// and the bottom-nav unread badge live. Without this the badge only updates
  /// when the user manually opens Inbox.
  void _ensureNotifListener() {
    if (_notifSub != null) return;
    _notifSub = ref.read(realtimeProvider).events.listen((e) {
      if (e.name != 'notification') return;
      // Only meaningful with an active session; skip while logged out so we
      // don't trigger a needless 401 fetch.
      if (ref.read(authControllerProvider).valueOrNull == null) return;
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final settings = ref.watch(settingsProvider);

    ref.listen<User?>(authControllerProvider.select((v) => v.valueOrNull), (_, user) {
      if (user != null) {
        final token = ref.read(tokenStoreProvider).access;
        if (token != null) ref.read(realtimeProvider).connect(token);
      } else {
        ref.read(realtimeProvider).disconnect();
      }
    });

    final light = ordoTheme(settings.accent, Brightness.light);
    final dark = ordoTheme(settings.accent, Brightness.dark);

    // Always return the SAME MaterialApp.router root — never swap it for a
    // plain MaterialApp(home: _Splash()) while auth is loading. Those two build
    // structurally different subtrees (a `home:` plain Navigator vs a `routerConfig:`
    // Router), so reconciling across the loading→loaded transition — which fires on
    // every launch AND every login, since login() sets state = AsyncLoading() —
    // deactivates an internal Navigator/Overlay InheritedWidget while descendants
    // still depend on it, tripping InheritedElement.debugDeactivated →
    // "_dependents.isEmpty is not true" (red error screen in debug). Now the
    // inherited-widget ancestry stays constant; only the leaf content swaps to the
    // splash while we don't yet have a session.
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Ordo',
      theme: light,
      darkTheme: dark,
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        return MediaQuery(
          // Cap font scaling for a consistent look.
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1).clamp(0.9, 1.2))),
          child: auth.isLoading ? const _Splash() : (child ?? const SizedBox()),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.auto_awesome_outlined, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text('Ordo', style: Theme.of(context).textTheme.displaySmall),
          ],
        ),
      ),
    );
  }
}
