import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        price       REAL    NOT NULL,
        sort_order  INTEGER NOT NULL DEFAULT 0,
        active      INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL,
        category_id INTEGER REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE business_days (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        date           TEXT    NOT NULL UNIQUE,
        total_revenue  REAL    NOT NULL DEFAULT 0,
        sale_count     INTEGER NOT NULL DEFAULT 0,
        closed_at      TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        date_time        TEXT    NOT NULL,
        total            REAL    NOT NULL,
        business_day_id  INTEGER NOT NULL,
        FOREIGN KEY (business_day_id) REFERENCES business_days(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_lines (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id         INTEGER NOT NULL,
        product_id      INTEGER NOT NULL,
        name_snapshot   TEXT    NOT NULL,
        price_snapshot  REAL    NOT NULL,
        quantity        INTEGER NOT NULL,
        subtotal        REAL    NOT NULL,
        FOREIGN KEY (sale_id)    REFERENCES sales(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE categories (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT    NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'ALTER TABLE products ADD COLUMN category_id INTEGER REFERENCES categories(id)',
      );
    }
  }

  /// Closes the underlying SQLite connection.
  /// Used in tests to release the in-memory database between test cases.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Creates a fresh in-memory [DatabaseHelper] for unit tests.
  /// Call [sqfliteFfiInit] + set [databaseFactory = databaseFactoryFfi] before using.
  static Future<DatabaseHelper> testInstance() async {
    final helper = DatabaseHelper._();
    helper._db = await openDatabase(
      inMemoryDatabasePath,
      version: AppConstants.dbVersion,
      onCreate: helper._onCreate,
    );
    return helper;
  }
}
