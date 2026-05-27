import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class SettingsState {
  final String appName;

  /// `null`  → use the device system locale
  /// `'fr'`  → French
  /// `'en'`  → English
  final String? locale;

  const SettingsState({required this.appName, this.locale});
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsState(
      appName:
          prefs.getString(AppConstants.keyAppName) ?? AppConstants.appName,
      locale: prefs.getString(AppConstants.keyLocale),
    );
  }

  /// Persists [name] and updates the state immediately.
  /// Falls back to [AppConstants.appName] if the trimmed value is empty.
  Future<void> setAppName(String name) async {
    final trimmed = name.trim();
    final effective = trimmed.isEmpty ? AppConstants.appName : trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAppName, effective);
    state = AsyncData(SettingsState(
      appName: effective,
      locale: state.valueOrNull?.locale,
    ));
  }

  /// Persists [locale] (`'fr'`, `'en'`, or `null` for system default)
  /// and updates the state immediately.
  Future<void> setLocale(String? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(AppConstants.keyLocale);
    } else {
      await prefs.setString(AppConstants.keyLocale, locale);
    }
    state = AsyncData(SettingsState(
      appName: state.valueOrNull?.appName ?? AppConstants.appName,
      locale: locale,
    ));
  }
}
