import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'FestiBuvette';
  static const Color defaultAppBarColor = Color(0xFFFFA946);

  // SharedPreferences keys
  static const String keyAppName = 'app_name';
  static const String keyLocale = 'app_locale';
  static const String keyPrinterAddress = 'printer_address';
  static const String keyPrinterName = 'printer_name';
  static const String keyCartGridView = 'cart_grid_view';
  static const String keyHapticFeedback = 'haptic_feedback';
  static const String keyAppBarColor = 'app_bar_color';

  // Sync
  static const String keySyncRole = 'sync_role';
  static const String keySyncPin = 'sync_pin';
  static const String keySyncControlIp = 'sync_control_ip';
  static const String keySyncToken = 'sync_token';
  static const String keyDeviceId = 'device_id';

  // Database — nom volontairement indépendant du nom de l'app
  static const String dbName = 'caisse.db';
  static const int dbVersion = 5;
}
