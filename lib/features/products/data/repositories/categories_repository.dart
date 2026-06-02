import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/products/data/models/category.dart';
import 'package:sqflite/sqflite.dart';

class CategoriesRepository {
  final DatabaseHelper _dbHelper;

  CategoriesRepository(this._dbHelper);

  /// Returns all categories sorted by ascending order.
  Future<List<Category>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories', orderBy: 'sort_order ASC');
    return maps.map(Category.fromMap).toList();
  }

  /// Inserts a new category and returns its generated id.
  Future<int> insert(Category category) async {
    final db = await _dbHelper.database;
    return db.insert('categories', category.toMap());
  }

  /// Updates the name of an existing category.
  Future<void> update(Category category) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      {'name': category.name},
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Deletes a category and moves its products to uncategorized (category_id = NULL).
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Saves the display order of the entire list in a single batch transaction.
  Future<void> updateOrders(List<Category> categories) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (int i = 0; i < categories.length; i++) {
      batch.update(
        'categories',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [categories[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Returns the next order number (= current number of categories).
  Future<int> nextOrder() async {
    final db = await _dbHelper.database;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories'),
        ) ??
        0;
    return count;
  }
}
