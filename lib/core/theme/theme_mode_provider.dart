import 'package:avogs/core/config/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _themeModeKey = 'theme_mode';

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(ref.watch(secureStorageProvider)),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._storage) : super(ThemeMode.system) {
    _load();
  }

  final FlutterSecureStorage _storage;

  Future<void> _load() async {
    final value = await _storage.read(key: _themeModeKey);
    state = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(
      key: _themeModeKey,
      value: switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}
