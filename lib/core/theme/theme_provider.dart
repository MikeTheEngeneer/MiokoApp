import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  final bool dark;
  final bool monet;

  const ThemeSettings({this.dark = true, this.monet = false});

  ThemeSettings copyWith({bool? dark, bool? monet}) =>
      ThemeSettings(dark: dark ?? this.dark, monet: monet ?? this.monet);
}

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  ThemeSettingsNotifier() : super(const ThemeSettings()) {
    _load();
  }

  static const _darkKey = 'theme_dark';
  static const _monetKey = 'theme_monet';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ThemeSettings(
      dark: prefs.getBool(_darkKey) ?? true,
      monet: prefs.getBool(_monetKey) ?? false,
    );
  }

  Future<void> setDark(bool dark) async {
    state = state.copyWith(dark: dark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkKey, dark);
  }

  Future<void> setMonet(bool monet) async {
    state = state.copyWith(monet: monet);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monetKey, monet);
  }
}

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
  (ref) => ThemeSettingsNotifier(),
);

// Monet есть только на Android 12+, на остальных устройствах палитры нет
final monetSupportedProvider = FutureProvider<bool>(
  (ref) async => await DynamicColorPlugin.getCorePalette() != null,
);
