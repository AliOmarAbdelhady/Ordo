import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'api.dart';
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
    Future.microtask(
        () => ref.read(authLogoutProvider.notifier).state = _forceLogout);

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
    state = await AsyncValue.guard(() async {
      final res = await _api.login(email, password);
      await _tokens.save(res.accessToken, res.refreshToken);
      ref.read(settingsProvider.notifier).syncFromUser(res.user);
      return res.user;
    });
  }

  Future<void> register(String name, String email, String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await _api.register(name, email, username, password);
      await _tokens.save(res.accessToken, res.refreshToken);
      return res.user;
    });
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
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
