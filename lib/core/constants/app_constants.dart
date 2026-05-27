class AppConstants {
  AppConstants._();

  static const String appName = 'FestiBuvette';

  // SharedPreferences keys
  static const String keyAppName = 'app_name';
  static const String keyLocale = 'app_locale';
  static const String keyPrinterAddress = 'printer_address';
  static const String keyPrinterName = 'printer_name';
  static const String keyCartGridView = 'cart_grid_view';

  // Database — nom volontairement indépendant du nom de l'app
  static const String dbName = 'caisse.db';
  static const int dbVersion = 2;
}
