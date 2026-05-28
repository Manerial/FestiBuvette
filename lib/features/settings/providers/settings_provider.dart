import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class SettingsState {
  final String appName;

  /// `null`  → use the device system locale
  /// `'fr'`  → French
  /// `'en'`  → English
  final String? locale;

  /// `true`  → grid view (default)
  /// `false` → list view
  final bool cartGridView;

  /// `true`  → vibrate on + / - button press (default)
  /// `false` → no vibration
  final bool hapticFeedback;

  final Color appBarColor;

  const SettingsState({
    required this.appName,
    this.locale,
    this.cartGridView = true,
    this.hapticFeedback = true,
    this.appBarColor = AppConstants.defaultAppBarColor,
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(AppConstants.keyAppBarColor);
    return SettingsState(
      appName: prefs.getString(AppConstants.keyAppName) ?? AppConstants.appName,
      locale: prefs.getString(AppConstants.keyLocale),
      cartGridView: prefs.getBool(AppConstants.keyCartGridView) ?? true,
      hapticFeedback: prefs.getBool(AppConstants.keyHapticFeedback) ?? true,
      appBarColor: colorValue != null
          ? Color(colorValue)
          : AppConstants.defaultAppBarColor,
    );
  }

  Future<void> setAppName(String name) async {
    final trimmed = name.trim();
    final effective = trimmed.isEmpty ? AppConstants.appName : trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAppName, effective);
    final current = state.valueOrNull;
    state = AsyncData(SettingsState(
      appName: effective,
      locale: current?.locale,
      cartGridView: current?.cartGridView ?? true,
      hapticFeedback: current?.hapticFeedback ?? true,
      appBarColor: current?.appBarColor ?? AppConstants.defaultAppBarColor,
    ));
  }

  Future<void> setLocale(String? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(AppConstants.keyLocale);
    } else {
      await prefs.setString(AppConstants.keyLocale, locale);
    }
    final current = state.valueOrNull;
    state = AsyncData(SettingsState(
      appName: current?.appName ?? AppConstants.appName,
      locale: locale,
      cartGridView: current?.cartGridView ?? true,
      hapticFeedback: current?.hapticFeedback ?? true,
      appBarColor: current?.appBarColor ?? AppConstants.defaultAppBarColor,
    ));
  }

  Future<void> setCartGridView(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyCartGridView, value);
    final current = state.valueOrNull;
    state = AsyncData(SettingsState(
      appName: current?.appName ?? AppConstants.appName,
      locale: current?.locale,
      cartGridView: value,
      hapticFeedback: current?.hapticFeedback ?? true,
      appBarColor: current?.appBarColor ?? AppConstants.defaultAppBarColor,
    ));
  }

  Future<void> setHapticFeedback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyHapticFeedback, value);
    final current = state.valueOrNull;
    state = AsyncData(SettingsState(
      appName: current?.appName ?? AppConstants.appName,
      locale: current?.locale,
      cartGridView: current?.cartGridView ?? true,
      hapticFeedback: value,
      appBarColor: current?.appBarColor ?? AppConstants.defaultAppBarColor,
    ));
  }

  Future<void> setAppBarColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyAppBarColor, color.toARGB32());
    final current = state.valueOrNull;
    state = AsyncData(SettingsState(
      appName: current?.appName ?? AppConstants.appName,
      locale: current?.locale,
      cartGridView: current?.cartGridView ?? true,
      hapticFeedback: current?.hapticFeedback ?? true,
      appBarColor: color,
    ));
  }
}
