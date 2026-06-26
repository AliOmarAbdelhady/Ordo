import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'app_theme.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String accentName;
  const SettingsState(this.themeMode, this.accentName);

  OrdoAccent get accent => OrdoAccent.byName(accentName);
}

class SettingsController extends Notifier<SettingsState> {
  SharedPreferences? _prefs;
  bool _loaded = false;

  @override
  SettingsState build() {
    _init();
    return const SettingsState(ThemeMode.system, 'blue');
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loaded = true;
    final theme = _prefs!.getString('ordo_theme') ?? 'system';
    final accent = _prefs!.getString('ordo_accent') ?? 'blue';
    state = SettingsState(_modeFromString(theme), accent);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = SettingsState(mode, state.accentName);
    if (_prefs != null) await _prefs!.setString('ordo_theme', _modeToString(mode));
  }

  Future<void> setAccent(String name) async {
    state = SettingsState(state.themeMode, name);
    if (_prefs != null) await _prefs!.setString('ordo_accent', name);
  }

  /// Pull theme + accent from the user's profile after login.
  void syncFromUser(User user) {
    if (!_loaded) {
      // prefs not ready; schedule after init
      Future.microtask(() => _applyUser(user));
    } else {
      _applyUser(user);
    }
  }

  void _applyUser(User user) {
    state = SettingsState(_modeFromString(user.theme), user.accentColor);
  }

  ThemeMode _modeFromString(String s) =>
      s == 'light' ? ThemeMode.light : (s == 'dark' ? ThemeMode.dark : ThemeMode.system);
  String _modeToString(ThemeMode m) =>
      m == ThemeMode.light ? 'light' : (m == ThemeMode.dark ? 'dark' : 'system');
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
