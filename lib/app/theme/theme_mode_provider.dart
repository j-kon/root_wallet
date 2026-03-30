import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const _themeModeKey = 'settings.theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    return StoredThemeModeX.fromStorage(prefs.getString(_themeModeKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_themeModeKey, mode.storageValue);
    state = AsyncData(mode);
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

extension StoredThemeModeX on ThemeMode {
  String get storageValue {
    return switch (this) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
  }

  String get label {
    return switch (this) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  IconData get icon {
    return switch (this) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
  }

  static ThemeMode fromStorage(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
