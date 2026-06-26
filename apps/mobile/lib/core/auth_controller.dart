import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'api.dart';
import 'realtime.dart';
import 'settings.dart';

class AuthController extends AsyncNotifier<User?> {
  late TokenStore _tokens;
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<User?> build() async {
    _tokens = ref.read(tokenStoreProvider);
    // Let the Dio interceptor force a logout on failed refresh. Deferred to a
    // microtask: Riverpod forbids mutating another provider during build(). The
    // microtask runs while `load()` is awaited below, before any request, so the
    // callback is always registered in time.
    Future.microtask(() {
      ref.read(authLogoutProvider.notifier).state = _forceLogout;
      // Reconnect the realtime socket when the access token is rotated by the
      // Dio 401 interceptor — socket_io_client freezes the handshake auth, so a
      // plain reconnect would keep using the now-expired token.
      ref.read(authRefreshProvider.notifier).state = _reconnectRealtime;
    });

    await _tokens.load();
    if (_tokens.access == null) return null;
    try {
      final user = await _api.me();
      ref.read(settingsProvider.notifier).syncFromUser(user);
      return user;
    } catch (_) {
      await _tokens.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final res = await _api.login(email, password);
      await _tokens.save(res.accessToken, res.refreshToken);
      ref.read(settingsProvider.notifier).syncFromUser(res.user);
      state = AsyncData(res.user);
    } catch (e, st) {
      state = AsyncError(e, st);
      // Rethrow so the page's `on ApiException` can surface "Invalid credentials"
      // etc. (AsyncValue.guard swallows the exception, which hid all auth errors.)
      rethrow;
    }
  }

  Future<void> register(String name, String email, String username, String password) async {
    state = const AsyncLoading();
    try {
      final res = await _api.register(name, email, username, password);
      await _tokens.save(res.accessToken, res.refreshToken);
      ref.read(settingsProvider.notifier).syncFromUser(res.user);
      state = AsyncData(res.user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout(_tokens.refresh);
    } catch (_) {}
    await _tokens.clear();
    state = const AsyncData(null);
  }

  void _forceLogout() {
    _tokens.clear();
    state = const AsyncData(null);
  }

  void _reconnectRealtime(String newAccessToken) {
    ref.read(realtimeProvider).connect(newAccessToken);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
