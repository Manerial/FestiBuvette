import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:festi_buvette_app/features/products/data/repositories/products_repository.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/products/providers/products_provider.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  setUpAll(initTestDatabase);

  // ─── Helpers ────────────────────────────────────────────────────────────────

  ProviderContainer makeContainer(ProductsRepository repo) {
    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith(() => ProductsNotifier(repo)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Product buildProduct({String name = 'Coffee', int order = 0}) => Product(
        name: name,
        price: 2.5,
        order: order,
        createdAt: '2026-01-01T00:00:00.000',
      );

  // ─── toggleOutOfStock ────────────────────────────────────────────────────────

  test('toggleOutOfStock marks product as out of stock in state', () async {
    final helper = await createTestDatabaseHelper();
    final repo = ProductsRepository(helper);
    final id = await repo.insert(buildProduct());
    final container = makeContainer(repo);
    await container.read(productsProvider.future);

    await container.read(productsProvider.notifier).toggleOutOfStock(id);

    final products = await container.read(productsProvider.future);
    expect(products.first.isOutOfStock, isTrue);
  });

  test('toggleOutOfStock marks product back in stock in state', () async {
    final helper = await createTestDatabaseHelper();
    final repo = ProductsRepository(helper);
    final id = await repo.insert(buildProduct());
    final container = makeContainer(repo);
    await container.read(productsProvider.future);

    await container.read(productsProvider.notifier).toggleOutOfStock(id);
    await container.read(productsProvider.notifier).toggleOutOfStock(id);

    final products = await container.read(productsProvider.future);
    expect(products.first.isOutOfStock, isFalse);
  });

  test('out-of-stock product appears last in state after toggle', () async {
    final helper = await createTestDatabaseHelper();
    final repo = ProductsRepository(helper);
    final id1 = await repo.insert(buildProduct(name: 'Alpha', order: 0));
    await repo.insert(buildProduct(name: 'Beta', order: 1));
    final container = makeContainer(repo);
    await container.read(productsProvider.future);

    await container.read(productsProvider.notifier).toggleOutOfStock(id1);

    final products = await container.read(productsProvider.future);
    expect(products.first.name, 'Beta');
    expect(products.last.name, 'Alpha');
  });
}
