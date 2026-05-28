import 'package:sqflite/sqflite.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';

class ProductsRepository {
  final DatabaseHelper _dbHelper;

  ProductsRepository(this._dbHelper);

  /// Returns all active products sorted by ascending order.
  Future<List<Product>> getAllActive() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'active = ?',
      whereArgs: [1],
      orderBy: 'sort_order ASC',
    );
    return maps.map(Product.fromMap).toList();
  }

  /// Inserts a new product and returns its generated id.
  Future<int> insert(Product product) async {
    final db = await _dbHelper.database;
    return db.insert('products', product.toMap());
  }

  /// Updates name, price and category of an existing product.
  Future<void> update(Product product) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      {
        'name': product.name,
        'price': product.price,
        'category_id': product.categoryId,
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Saves the order of the entire list in a single batch transaction.
  Future<void> updateOrders(List<Product> products) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (int i = 0; i < products.length; i++) {
      batch.update(
        'products',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [products[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Deletes a product.
  /// - If the product does not appear in any sale → physical delete.
  /// - Otherwise → deactivation (active = 0) to preserve history.
  Future<void> softDelete(int id) async {
    final db = await _dbHelper.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM sale_lines WHERE product_id = ?',
          [id],
        )) ??
        0;
    if (count > 0) {
      await db.update('products', {'active': 0},
          where: 'id = ?', whereArgs: [id]);
    } else {
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Returns the next order number (= current number of active products).
  Future<int> nextOrder() async {
    final db = await _dbHelper.database;
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM products WHERE active = 1'),
        ) ??
        0;
    return count;
  }
}
