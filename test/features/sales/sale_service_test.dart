import 'package:flutter_test/flutter_test.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';
import 'package:festi_buvette_app/features/sales/services/sale_service.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseHelper helper;
  late SaleService service;
  late SalesRepository repo;

  setUpAll(initTestDatabase);

  setUp(() async {
    helper = await createTestDatabaseHelper();
    repo = SalesRepository(helper);
    service = SaleService.withRepository(repo);
  });

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Product product(int id, {double price = 2.5}) => Product(
        id: id,
        name: 'Product $id',
        price: price,
        order: 0,
        createdAt: '2026-01-01T00:00:00.000',
      );

  // ─── Empty cart ─────────────────────────────────────────────────────────────

  test('record throws Exception when cart is empty', () async {
    expect(
      () => service.record(products: [], quantities: {}),
      throwsA(isA<Exception>()),
    );
  });

  test('record throws when all quantities are zero', () async {
    final products = [product(1), product(2)];
    expect(
      () => service.record(products: products, quantities: {1: 0, 2: 0}),
      throwsA(isA<Exception>()),
    );
  });

  // ─── Nominal case ───────────────────────────────────────────────────────────

  test('record returns a Sale with a non-null id', () async {
    final sale = await service.record(
      products: [product(1, price: 2.5)],
      quantities: {1: 2},
    );

    expect(sale.id, isNotNull);
    expect(sale.total, closeTo(5.0, 0.001)); // 2.5 × 2
  });

  test('record creates a business day if none exists', () async {
    expect(await repo.getToday(), isNull);

    await service.record(
      products: [product(1)],
      quantities: {1: 1},
    );

    expect(await repo.getToday(), isNotNull);
  });

  test('record updates business day total_revenue and sale_count', () async {
    await service.record(
      products: [product(1, price: 3.0), product(2, price: 1.5)],
      quantities: {1: 2, 2: 1}, // total = 3.0*2 + 1.5*1 = 7.5
    );

    final day = await repo.getToday();
    expect(day!.totalRevenue, closeTo(7.5, 0.001));
    expect(day.saleCount, 1);
  });

  test('record accumulates across multiple sales', () async {
    await service.record(
      products: [product(1, price: 2.0)],
      quantities: {1: 1}, // total = 2.0
    );
    await service.record(
      products: [product(1, price: 2.0)],
      quantities: {1: 3}, // total = 6.0
    );

    final day = await repo.getToday();
    expect(day!.totalRevenue, closeTo(8.0, 0.001));
    expect(day.saleCount, 2);
  });

  test('record only processes products with quantity > 0', () async {
    final sale = await service.record(
      products: [product(1, price: 5.0), product(2, price: 3.0)],
      quantities: {1: 1, 2: 0}, // product 2 should be ignored
    );

    expect(sale.total, closeTo(5.0, 0.001));
  });

  // ─── Concurrent calls (BUG-1) ───────────────────────────────────────────────

  test('concurrent record calls preserve both sale_count and total_revenue', () async {
    final products = [product(1, price: 2.0)];
    final quantities = {1: 1};

    await Future.wait([
      service.record(products: products, quantities: quantities),
      service.record(products: products, quantities: quantities),
    ]);

    final day = await repo.getToday();
    expect(day!.saleCount, 2);
    expect(day.totalRevenue, closeTo(4.0, 0.001));
  });

  test('concurrent getOrCreateToday does not throw on first call of the day', () async {
    final days = await Future.wait([
      repo.getOrCreateToday(),
      repo.getOrCreateToday(),
    ]);
    expect(days[0].id, days[1].id);
  });

  // ─── Auto-reopen closed day ─────────────────────────────────────────────────

  test('record reopens a closed business day', () async {
    // Close today's day
    final day = await repo.getOrCreateToday();
    await repo.closeBusinessDay(day.id!);
    expect((await repo.getToday())!.isClosed, isTrue);

    // Recording a new sale should reopen it
    await service.record(
      products: [product(1, price: 2.0)],
      quantities: {1: 1},
    );

    final reopened = await repo.getToday();
    expect(reopened!.isClosed, isFalse);
    expect(reopened.closedAt, isNull);
  });

  test('record updates aggregates correctly after reopening', () async {
    // Close after a first sale
    await service.record(
      products: [product(1, price: 3.0)],
      quantities: {1: 2}, // total = 6.0
    );
    final day = await repo.getToday();
    await repo.closeBusinessDay(day!.id!);

    // Second sale after closure
    await service.record(
      products: [product(1, price: 3.0)],
      quantities: {1: 1}, // total = 3.0
    );

    final updated = await repo.getToday();
    expect(updated!.isClosed, isFalse);
    expect(updated.totalRevenue, closeTo(9.0, 0.001)); // 6.0 + 3.0
    expect(updated.saleCount, 2);
  });
}
