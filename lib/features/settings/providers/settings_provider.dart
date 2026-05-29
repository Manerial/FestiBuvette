import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_role.dart';

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

  final SyncRole syncRole;

  /// 6-digit PIN displayed on the control. Null until Control role is first selected.
  final String? syncPin;

  /// IP address of the control phone, used by Second devices.
  final String syncControlIp;

  const SettingsState({
    required this.appName,
    this.locale,
    this.cartGridView = true,
    this.hapticFeedback = true,
    this.appBarColor = AppConstants.defaultAppBarColor,
    this.syncRole = SyncRole.standalone,
    this.syncPin,
    this.syncControlIp = '192.168.43.1',
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

    final roleStr = prefs.getString(AppConstants.keySyncRole);
    final syncRole = SyncRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => SyncRole.standalone,
    );

    String? syncPin = prefs.getString(AppConstants.keySyncPin);
    if (syncRole == SyncRole.control && syncPin == null) {
      syncPin = _generatePin();
      await prefs.setString(AppConstants.keySyncPin, syncPin);
    }

    return SettingsState(
      appName: prefs.getString(AppConstants.keyAppName) ?? AppConstants.appName,
      locale: prefs.getString(AppConstants.keyLocale),
      cartGridView: prefs.getBool(AppConstants.keyCartGridView) ?? true,
      hapticFeedback: prefs.getBool(AppConstants.keyHapticFeedback) ?? true,
      appBarColor: colorValue != null
          ? Color(colorValue)
          : AppConstants.defaultAppBarColor,
      syncRole: syncRole,
      syncPin: syncPin,
      syncControlIp:
          prefs.getString(AppConstants.keySyncControlIp) ?? '192.168.43.1',
    );
  }

  Future<void> setAppName(String name) async {
    final trimmed = name.trim();
    final effective = trimmed.isEmpty ? AppConstants.appName : trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAppName, effective);
    final c = state.valueOrNull;
    state = AsyncData(_build(c, appName: effective));
  }

  Future<void> setLocale(String? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(AppConstants.keyLocale);
    } else {
      await prefs.setString(AppConstants.keyLocale, locale);
    }
    final c = state.valueOrNull;
    state = AsyncData(_build(c, locale: locale, overrideLocale: true));
  }

  Future<void> setCartGridView(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyCartGridView, value);
    final c = state.valueOrNull;
    state = AsyncData(_build(c, cartGridView: value));
  }

  Future<void> setHapticFeedback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyHapticFeedback, value);
    final c = state.valueOrNull;
    state = AsyncData(_build(c, hapticFeedback: value));
  }

  Future<void> setAppBarColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyAppBarColor, color.toARGB32());
    final c = state.valueOrNull;
    state = AsyncData(_build(c, appBarColor: color));
  }

  Future<void> setSyncRole(SyncRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySyncRole, role.name);
    final c = state.valueOrNull;
    String? syncPin = c?.syncPin ?? prefs.getString(AppConstants.keySyncPin);
    if (role == SyncRole.control && syncPin == null) {
      syncPin = _generatePin();
      await prefs.setString(AppConstants.keySyncPin, syncPin);
    }
    state = AsyncData(_build(c, syncRole: role, syncPin: syncPin, overrideSyncPin: true));
  }

  Future<void> regeneratePin() async {
    final pin = _generatePin();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySyncPin, pin);
    final c = state.valueOrNull;
    state = AsyncData(_build(c, syncPin: pin, overrideSyncPin: true));
  }

  Future<void> setSyncControlIp(String ip) async {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySyncControlIp, trimmed);
    final c = state.valueOrNull;
    state = AsyncData(_build(c, syncControlIp: trimmed));
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  static String _generatePin() =>
      Random.secure().nextInt(1000000).toString().padLeft(6, '0');

  SettingsState _build(
    SettingsState? c, {
    String? appName,
    String? locale,
    bool overrideLocale = false,
    bool? cartGridView,
    bool? hapticFeedback,
    Color? appBarColor,
    SyncRole? syncRole,
    String? syncPin,
    bool overrideSyncPin = false,
    String? syncControlIp,
  }) {
    return SettingsState(
      appName: appName ?? c?.appName ?? AppConstants.appName,
      locale: overrideLocale ? locale : (locale ?? c?.locale),
      cartGridView: cartGridView ?? c?.cartGridView ?? true,
      hapticFeedback: hapticFeedback ?? c?.hapticFeedback ?? true,
      appBarColor: appBarColor ?? c?.appBarColor ?? AppConstants.defaultAppBarColor,
      syncRole: syncRole ?? c?.syncRole ?? SyncRole.standalone,
      syncPin: overrideSyncPin ? syncPin : (syncPin ?? c?.syncPin),
      syncControlIp: syncControlIp ?? c?.syncControlIp ?? '192.168.43.1',
    );
  }
}
