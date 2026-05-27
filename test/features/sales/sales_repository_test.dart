import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_pay_app/core/database/database_helper.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale_line.dart';
import 'package:ludo_pay_app/features/sales/data/repositories/sales_repository.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseHelper helper;
  late SalesRepository repo;

  setUpAll(initTestDatabase);

  setUp(() async {
    helper = await createTestDatabaseHelper();
    repo = SalesRepository(helper);
  });

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Sale buildSale({int businessDayId = 1, double total = 10.0}) => Sale(
        dateTime: '2026-01-01T12:00:00.000',
        total: total,
        businessDayId: businessDayId,
      );

  SaleLine buildLine({int saleId = 0}) => SaleLine(
        saleId: saleId,
        productId: 1,
        nameSnapshot: 'Coffee',
        priceSnapshot: 2.5,
        quantity: 2,
        subtotal: 5.0,
      );

  // ─── Business Days ──────────────────────────────────────────────────────────

  test('getOrCreateToday creates a business day on first call', () async {
    final day = await repo.getOrCreateToday();
    expect(day.id, isNotNull);
    expect(day.totalRevenue, 0.0);
    expect(day.saleCount, 0);
    expect(day.isClosed, isFalse);
  });

  test('getOrCreateToday returns the same day on subsequent calls', () async {
    final first = await repo.getOrCreateToday();
    final second = await repo.getOrCreateToday();
    expect(second.id, first.id);
    expect(second.date, first.date);
  });

  test('getToday returns null when no business day exists', () async {
    expect(await repo.getToday(), isNull);
  });

  test('getToday returns existing business day', () async {
    final created = await repo.getOrCreateToday();
    final fetched = await repo.getToday();
    expect(fetched, isNotNull);
    expect(fetched!.id, created.id);
  });

  test('updateBusinessDay updates total_revenue and sale_count', () async {
    final day = await repo.getOrCreateToday();
    await repo.updateBusinessDay(day.id!, totalRevenue: 42.0, saleCount: 3);

    final updated = await repo.getToday();
    expect(updated!.totalRevenue, 42.0);
    expect(updated.saleCount, 3);
  });

  test('closeBusinessDay sets closed_at', () async {
    final day = await repo.getOrCreateToday();
    expect(day.isClosed, isFalse);

    await repo.closeBusinessDay(day.id!);

    final closed = await repo.getToday();
    expect(closed!.isClosed, isTrue);
    expect(closed.closedAt, isNotNull);
  });

  test('reopenBusinessDay clears closed_at', () async {
    final day = await repo.getOrCreateToday();
    await repo.closeBusinessDay(day.id!);
    expect((await repo.getToday())!.isClosed, isTrue);

    await repo.reopenBusinessDay(day.id!);

    final reopened = await repo.getToday();
    expect(reopened!.isClosed, isFalse);
    expect(reopened.closedAt, isNull);
  });

  // ─── Sales ─────────────────────────────────────────────────────────────────

  test('insertSaleWithLines creates sale and lines and returns sale with id',
      () async {
    final day = await repo.getOrCreateToday();
    final sale = await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!),
      lines: [buildLine()],
    );

    expect(sale.id, isNotNull);
    expect(sale.total, 10.0);
  });

  test('insertSaleWithLines inserts all lines', () async {
    final day = await repo.getOrCreateToday();
    final sale = await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!),
      lines: [buildLine(), buildLine()],
    );

    final lines = await repo.getLinesBySale(sale.id!);
    expect(lines.length, 2);
  });

  test('getSalesByDay returns sales for the given business day', () async {
    final day = await repo.getOrCreateToday();
    await repo.insertSaleWithLines(
        sale: buildSale(businessDayId: day.id!), lines: [buildLine()]);
    await repo.insertSaleWithLines(
        sale: buildSale(businessDayId: day.id!), lines: [buildLine()]);

    final sales = await repo.getSalesByDay(day.id!);
    expect(sales.length, 2);
  });

  test('getSalesByDay returns empty list for unknown business day', () async {
    expect(await repo.getSalesByDay(999), isEmpty);
  });

  test('getLinesBySale returns correct lines', () async {
    final day = await repo.getOrCreateToday();
    final sale = await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!),
      lines: [buildLine()],
    );

    final lines = await repo.getLinesBySale(sale.id!);
    expect(lines.length, 1);
    expect(lines.first.nameSnapshot, 'Coffee');
    expect(lines.first.quantity, 2);
    expect(lines.first.subtotal, 5.0);
  });

  // ─── deleteSale ────────────────────────────────────────────────────────────

  test('deleteSale removes the sale and its lines', () async {
    final day = await repo.getOrCreateToday();
    final sale = await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!),
      lines: [buildLine()],
    );

    await repo.deleteSale(sale);

    expect(await repo.getSalesByDay(day.id!), isEmpty);
    expect(await repo.getLinesBySale(sale.id!), isEmpty);
  });

  test('deleteSale updates business day aggregates', () async {
    final day = await repo.getOrCreateToday();
    await repo.updateBusinessDay(day.id!, totalRevenue: 20.0, saleCount: 2);

    final sale = await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!, total: 10.0),
      lines: [buildLine()],
    );

    await repo.deleteSale(sale);

    // After deletion, only the first two sales that were manually set are gone —
    // the aggregates should reflect what is actually in the DB (empty after delete).
    final updated = await repo.getToday();
    expect(updated!.saleCount, 0);
    expect(updated.totalRevenue, closeTo(0.0, 0.001));
  });

  test('deleteSale only removes the targeted sale when multiple exist', () async {
    final day = await repo.getOrCreateToday();
    final sale1 = await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!, total: 5.0),
      lines: [buildLine()],
    );
    await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!, total: 8.0),
      lines: [buildLine()],
    );

    await repo.deleteSale(sale1);

    final remaining = await repo.getSalesByDay(day.id!);
    expect(remaining.length, 1);
    expect(remaining.first.total, 8.0);

    final updated = await repo.getToday();
    expect(updated!.saleCount, 1);
    expect(updated.totalRevenue, closeTo(8.0, 0.001));
  });

  // ─── getTotalsByProduct ─────────────────────────────────────────────────────

  test('getTotalsByProduct returns aggregated data per product', () async {
    final day = await repo.getOrCreateToday();

    // Sale 1: 2× Coffee (5.0)
    await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!),
      lines: [
        SaleLine(
            saleId: 0,
            productId: 1,
            nameSnapshot: 'Coffee',
            priceSnapshot: 2.5,
            quantity: 2,
            subtotal: 5.0),
      ],
    );

    // Sale 2: 1× Coffee (2.5) + 3× Water (3.0)
    await repo.insertSaleWithLines(
      sale: buildSale(businessDayId: day.id!, total: 5.5),
      lines: [
        SaleLine(
            saleId: 0,
            productId: 1,
            nameSnapshot: 'Coffee',
            priceSnapshot: 2.5,
            quantity: 1,
            subtotal: 2.5),
        SaleLine(
            saleId: 0,
            productId: 2,
            nameSnapshot: 'Water',
            priceSnapshot: 1.0,
            quantity: 3,
            subtotal: 3.0),
      ],
    );

    final totals = await repo.getTotalsByProduct(day.id!);

    // Sorted by total_quantity DESC → Coffee (3) then Water (3)
    // Coffee: qty=3, total=7.5 | Water: qty=3, total=3.0
    expect(totals.length, 2);

    final coffee = totals.firstWhere((r) => r['name_snapshot'] == 'Coffee');
    expect(coffee['total_quantity'], 3);
    expect((coffee['product_total'] as num).toDouble(), closeTo(7.5, 0.001));

    final water = totals.firstWhere((r) => r['name_snapshot'] == 'Water');
    expect(water['total_quantity'], 3);
    expect((water['product_total'] as num).toDouble(), closeTo(3.0, 0.001));
  });
}
