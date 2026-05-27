import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_pay_app/core/database/database_helper.dart';
import 'package:ludo_pay_app/features/products/data/models/category.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/data/repositories/categories_repository.dart';
import 'package:ludo_pay_app/features/products/data/repositories/products_repository.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseHelper helper;
  late CategoriesRepository repo;

  setUpAll(initTestDatabase);

  setUp(() async {
    helper = await createTestDatabaseHelper();
    repo = CategoriesRepository(helper);
  });

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Category buildCategory({String name = 'Drinks', int order = 0}) =>
      Category(name: name, order: order);

  // ─── getAll ─────────────────────────────────────────────────────────────────

  test('getAll returns empty list when no categories exist', () async {
    expect(await repo.getAll(), isEmpty);
  });

  // ─── insert / getAll ────────────────────────────────────────────────────────

  test('insert assigns an id and getAll returns it', () async {
    final id = await repo.insert(buildCategory());

    final categories = await repo.getAll();

    expect(categories.length, 1);
    expect(categories.first.id, id);
    expect(categories.first.name, 'Drinks');
  });

  test('getAll sorts by sort_order ascending', () async {
    await repo.insert(buildCategory(name: 'C', order: 2));
    await repo.insert(buildCategory(name: 'A', order: 0));
    await repo.insert(buildCategory(name: 'B', order: 1));

    final categories = await repo.getAll();

    expect(categories.map((c) => c.name).toList(), ['A', 'B', 'C']);
  });

  // ─── update ─────────────────────────────────────────────────────────────────

  test('update changes the name', () async {
    final id = await repo.insert(buildCategory(name: 'OldName'));
    final original = (await repo.getAll()).first;

    await repo.update(original.copyWith(name: 'NewName'));

    final updated = await repo.getAll();
    expect(updated.first.name, 'NewName');
    expect(updated.first.id, id);
  });

  // ─── delete ─────────────────────────────────────────────────────────────────

  test('delete removes the category', () async {
    final id = await repo.insert(buildCategory());
    await repo.delete(id);

    expect(await repo.getAll(), isEmpty);
  });

  test('delete uncategorizes products that belonged to the category', () async {
    final categoryId = await repo.insert(buildCategory());
    final productsRepo = ProductsRepository(helper);

    // Insert a product linked to this category
    final productId = await productsRepo.insert(Product(
      name: 'Beer',
      price: 3.0,
      order: 0,
      createdAt: '2026-01-01T00:00:00.000',
      categoryId: categoryId,
    ));

    await repo.delete(categoryId);

    // Category is gone
    expect(await repo.getAll(), isEmpty);

    // Product still exists but category_id is now null
    final db = await helper.database;
    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    expect(rows.length, 1);
    expect(rows.first['category_id'], isNull);
  });

  // ─── nextOrder ──────────────────────────────────────────────────────────────

  test('nextOrder returns 0 when no categories exist', () async {
    expect(await repo.nextOrder(), 0);
  });

  test('nextOrder increments with each insert', () async {
    expect(await repo.nextOrder(), 0);
    await repo.insert(buildCategory(order: 0));
    expect(await repo.nextOrder(), 1);
    await repo.insert(buildCategory(order: 1));
    expect(await repo.nextOrder(), 2);
  });
}
