import 'package:flutter/foundation.dart';

/// Base URL of the Ordo API.
///
/// - Web build → localhost:4000
/// - Android emulator → 10.0.2.2:4000 (maps to host loopback)
/// - iOS simulator / desktop → localhost:4000
/// - Physical device → set ORDO_API_URL to your machine's LAN IP, e.g.
///   `--dart-define=ORDO_API_URL=http://192.168.1.5:4000`
String get apiBaseUrl {
  const env = String.fromEnvironment('ORDO_API_URL');
  if (env.isNotEmpty) return env;
  if (kIsWeb) return 'http://localhost:4000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:4000';
  return 'http://localhost:4000';
}

/// Demo credentials shown on the login screen.
const demoEmail = 'ali@ordo.app';
const demoPassword = 'password123';
