import 'package:flutter_test/flutter_test.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/products/data/repositories/products_repository.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseHelper helper;
  late ProductsRepository repo;

  setUpAll(initTestDatabase);

  setUp(() async {
    helper = await createTestDatabaseHelper();
    repo = ProductsRepository(helper);
  });

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Product buildProduct({
    String name = 'Coffee',
    double price = 2.5,
    int order = 0,
  }) =>
      Product(
        name: name,
        price: price,
        order: order,
        createdAt: '2026-01-01T00:00:00.000',
      );

  // ─── insert / getAllActive ───────────────────────────────────────────────────

  test('insert assigns an id and getAllActive returns it', () async {
    final id = await repo.insert(buildProduct());

    final products = await repo.getAllActive();

    expect(products.length, 1);
    expect(products.first.id, id);
    expect(products.first.name, 'Coffee');
    expect(products.first.price, 2.5);
  });

  test('getAllActive sorts by sort_order ascending', () async {
    await repo.insert(buildProduct(name: 'B', order: 2));
    await repo.insert(buildProduct(name: 'A', order: 0));
    await repo.insert(buildProduct(name: 'C', order: 1));

    final products = await repo.getAllActive();

    expect(products.map((p) => p.name).toList(), ['A', 'C', 'B']);
  });

  test('getAllActive excludes inactive products', () async {
    final id = await repo.insert(buildProduct(name: 'Active'));
    await repo.insert(buildProduct(name: 'Deleted'));

    // Manually deactivate the second product via the raw database
    final db = await helper.database;
    await db.update(
      'products',
      {'active': 0},
      where: 'name = ?',
      whereArgs: ['Deleted'],
    );

    final products = await repo.getAllActive();
    expect(products.length, 1);
    expect(products.first.id, id);
  });

  // ─── update ─────────────────────────────────────────────────────────────────

  test('update changes name and price', () async {
    final id = await repo.insert(buildProduct(name: 'OldName', price: 1.0));
    final original = (await repo.getAllActive()).first;

    await repo.update(original.copyWith(name: 'NewName', price: 9.99));

    final updated = await repo.getAllActive();
    expect(updated.first.name, 'NewName');
    expect(updated.first.price, 9.99);
    expect(updated.first.id, id);
  });

  // ─── updateOrders ───────────────────────────────────────────────────────────

  test('updateOrders persists new sort_order', () async {
    await repo.insert(buildProduct(name: 'A', order: 0));
    await repo.insert(buildProduct(name: 'B', order: 1));

    final before = await repo.getAllActive(); // [A, B]
    final reordered = [before[1], before[0]]; // [B, A]
    await repo.updateOrders(reordered);

    final after = await repo.getAllActive();
    expect(after.map((p) => p.name).toList(), ['B', 'A']);
  });

  // ─── softDelete ─────────────────────────────────────────────────────────────

  test('softDelete physically removes product when no sale_lines reference it',
      () async {
    final id = await repo.insert(buildProduct());
    await repo.softDelete(id);

    final products = await repo.getAllActive();
    expect(products, isEmpty);

    // Verify it's truly deleted (not just deactivated)
    final db = await helper.database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    expect(rows, isEmpty);
  });

  test('softDelete deactivates product when sale_lines reference it', () async {
    final id = await repo.insert(buildProduct());

    // Simulate a sale line referencing this product (FK not enforced by default)
    final db = await helper.database;
    await db.insert('sale_lines', {
      'sale_id': 999,
      'product_id': id,
      'name_snapshot': 'Coffee',
      'price_snapshot': 2.5,
      'quantity': 1,
      'subtotal': 2.5,
    });

    await repo.softDelete(id);

    // Product should still exist but with active = 0
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    expect(rows.length, 1);
    expect(rows.first['active'], 0);

    // Should not appear in getAllActive
    expect(await repo.getAllActive(), isEmpty);
  });

  // ─── nextOrder ──────────────────────────────────────────────────────────────

  test('nextOrder returns count of active products', () async {
    expect(await repo.nextOrder(), 0);

    await repo.insert(buildProduct(order: 0));
    expect(await repo.nextOrder(), 1);

    await repo.insert(buildProduct(order: 1));
    expect(await repo.nextOrder(), 2);
  });

  // ─── toggleOutOfStock ────────────────────────────────────────────────────────

  test('toggleOutOfStock marks product as out of stock', () async {
    final id = await repo.insert(buildProduct());
    await repo.toggleOutOfStock(id);

    final products = await repo.getAllActive();
    expect(products.first.isOutOfStock, isTrue);
  });

  test('toggleOutOfStock marks product back in stock', () async {
    final id = await repo.insert(buildProduct());
    await repo.toggleOutOfStock(id); // out
    await repo.toggleOutOfStock(id); // back in

    final products = await repo.getAllActive();
    expect(products.first.isOutOfStock, isFalse);
  });

  test('getAllActive returns out-of-stock products last', () async {
    final id1 = await repo.insert(buildProduct(name: 'Alpha', order: 0));
    await repo.insert(buildProduct(name: 'Beta', order: 1));

    await repo.toggleOutOfStock(id1); // Alpha is now OOS

    final products = await repo.getAllActive();
    expect(products.first.name, 'Beta');
    expect(products.last.name, 'Alpha');
    expect(products.last.isOutOfStock, isTrue);
  });

  test('nextOrder decreases after softDelete with no sale_lines reference', () async {
    final id1 = await repo.insert(buildProduct(name: 'A', order: 0));
    await repo.insert(buildProduct(name: 'B', order: 1));
    expect(await repo.nextOrder(), 2);

    await repo.softDelete(id1); // no sale_lines reference → hard delete
    expect(await repo.nextOrder(), 1);
  });
}
