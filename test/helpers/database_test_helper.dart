import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ludo_pay_app/core/database/database_helper.dart';

/// Initialise SQLite FFI pour les tests desktop (à appeler dans [setUpAll]).
void initTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Crée un [DatabaseHelper] sur une base in-memory fraîche.
/// Enregistre automatiquement un [addTearDown] pour fermer la connexion
/// après chaque test et garantir l'isolation.
Future<DatabaseHelper> createTestDatabaseHelper() async {
  final helper = await DatabaseHelper.testInstance();
  addTearDown(helper.close);
  return helper;
}
