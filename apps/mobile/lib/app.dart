import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/auth_controller.dart';
import 'core/api.dart';
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
  @override
  void initState() {
    super.initState();
    // Connect realtime as soon as we have a session.
    Future.microtask(() => _maybeConnect());
  }

  void _maybeConnect() {
    final auth = ref.read(authControllerProvider);
    final user = auth.valueOrNull;
    final tokens = ref.read(tokenStoreProvider);
    if (user != null && tokens.access != null) {
      ref.read(realtimeProvider).connect(tokens.access!);
    }
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

    if (auth.isLoading) {
      return MaterialApp(debugShowCheckedModeBanner: false, theme: light, darkTheme: dark, themeMode: settings.themeMode, home: const _Splash());
    }

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
          child: child ?? const SizedBox(),
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
