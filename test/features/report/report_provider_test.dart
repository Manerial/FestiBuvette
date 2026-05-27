import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_pay_app/features/report/providers/report_provider.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale_line.dart';
import 'package:ludo_pay_app/features/sales/data/repositories/sales_repository.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  setUpAll(initTestDatabase);

  // ─── Helpers ────────────────────────────────────────────────────────────────

  ProviderContainer makeContainer(SalesRepository repo) {
    final container = ProviderContainer(overrides: [
      reportProvider.overrideWith(() => ReportNotifier.withRepository(repo)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<ReportState> awaitData(ProviderContainer container) async {
    // Let the AsyncNotifier build and settle.
    return container
        .read(reportProvider.future);
  }

  // ─── Empty state ─────────────────────────────────────────────────────────

  test('hasData is false when no business day exists', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.hasData, isFalse);
    expect(state.day, isNull);
    expect(state.productTotals, isEmpty);
  });

  test('hasData is false when business day has no sales', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    await repo.getOrCreateToday(); // creates day with saleCount=0
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.hasData, isFalse);
    expect(state.day, isNotNull);
    expect(state.day!.saleCount, 0);
  });

  // ─── With sales ──────────────────────────────────────────────────────────

  test('loads business day and product totals after a sale', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final day = await repo.getOrCreateToday();

    await repo.insertSaleWithLines(
      sale: Sale(
          dateTime: '2026-01-01T10:00:00.000',
          total: 7.5,
          businessDayId: day.id!),
      lines: [
        SaleLine(
          saleId: 0,
          productId: 1,
          nameSnapshot: 'Coffee',
          priceSnapshot: 2.5,
          quantity: 3,
          subtotal: 7.5,
        ),
      ],
    );
    await repo.updateBusinessDay(day.id!, totalRevenue: 7.5, saleCount: 1);

    final container = makeContainer(repo);
    final state = await awaitData(container);

    expect(state.hasData, isTrue);
    expect(state.day!.totalRevenue, closeTo(7.5, 0.001));
    expect(state.day!.saleCount, 1);
    expect(state.productTotals.length, 1);
    expect(state.productTotals.first['name_snapshot'], 'Coffee');
    expect(state.productTotals.first['total_quantity'], 3);
  });

  // ─── refresh ─────────────────────────────────────────────────────────────

  test('refresh reloads updated data', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    // Initially no data.
    final before = await awaitData(container);
    expect(before.hasData, isFalse);

    // Add a sale directly.
    final day = await repo.getOrCreateToday();
    await repo.insertSaleWithLines(
      sale: Sale(
          dateTime: '2026-01-01T11:00:00.000',
          total: 3.0,
          businessDayId: day.id!),
      lines: [
        SaleLine(
          saleId: 0,
          productId: 2,
          nameSnapshot: 'Water',
          priceSnapshot: 1.0,
          quantity: 3,
          subtotal: 3.0,
        ),
      ],
    );
    await repo.updateBusinessDay(day.id!, totalRevenue: 3.0, saleCount: 1);

    // Refresh the notifier.
    await container.read(reportProvider.notifier).refresh();
    final after = await container.read(reportProvider.future);

    expect(after.hasData, isTrue);
    expect(after.day!.saleCount, 1);
  });

  // ─── closeDay ────────────────────────────────────────────────────────────

  test('closeDay marks the day as closed', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final day = await repo.getOrCreateToday();

    await repo.insertSaleWithLines(
      sale: Sale(
          dateTime: '2026-01-01T12:00:00.000',
          total: 5.0,
          businessDayId: day.id!),
      lines: [
        SaleLine(
          saleId: 0,
          productId: 1,
          nameSnapshot: 'Coffee',
          priceSnapshot: 2.5,
          quantity: 2,
          subtotal: 5.0,
        ),
      ],
    );
    await repo.updateBusinessDay(day.id!, totalRevenue: 5.0, saleCount: 1);

    final container = makeContainer(repo);
    await awaitData(container);

    expect((await container.read(reportProvider.future)).day!.isClosed, isFalse);

    await container.read(reportProvider.notifier).closeDay();
    final closed = await container.read(reportProvider.future);

    expect(closed.day!.isClosed, isTrue);
    expect(closed.day!.closedAt, isNotNull);
  });

  // ─── Day navigation ──────────────────────────────────────────────────────

  test('canGoPrevious and canGoNext are false with a single day', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final day = await repo.getOrCreateToday();
    await repo.updateBusinessDay(day.id!, totalRevenue: 5.0, saleCount: 1);
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.canGoPrevious, isFalse);
    expect(state.canGoNext, isFalse);
  });

  test('goToPreviousDay loads the older day', () async {
    final helper = await createTestDatabaseHelper();
    final db = await helper.database;
    // Insert two days: yesterday and today.
    await db.insert('business_days', {
      'date': '2026-01-01',
      'total_revenue': 10.0,
      'sale_count': 1,
      'closed_at': null,
    });
    await db.insert('business_days', {
      'date': '2026-01-02',
      'total_revenue': 20.0,
      'sale_count': 2,
      'closed_at': null,
    });
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    // Starts on index 0 = most recent (Jan 2).
    final initial = await awaitData(container);
    expect(initial.day!.date, '2026-01-02');
    expect(initial.canGoPrevious, isTrue);
    expect(initial.canGoNext, isFalse);

    // Navigate to Jan 1.
    await container.read(reportProvider.notifier).goToPreviousDay();
    final prev = await container.read(reportProvider.future);

    expect(prev.day!.date, '2026-01-01');
    expect(prev.canGoPrevious, isFalse);
    expect(prev.canGoNext, isTrue);
  });

  test('goToNextDay returns to the more recent day', () async {
    final helper = await createTestDatabaseHelper();
    final db = await helper.database;
    await db.insert('business_days', {
      'date': '2026-01-01',
      'total_revenue': 10.0,
      'sale_count': 1,
      'closed_at': null,
    });
    await db.insert('business_days', {
      'date': '2026-01-02',
      'total_revenue': 20.0,
      'sale_count': 2,
      'closed_at': null,
    });
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);
    await awaitData(container);

    // Go back to Jan 1, then forward to Jan 2.
    await container.read(reportProvider.notifier).goToPreviousDay();
    await container.read(reportProvider.notifier).goToNextDay();
    final state = await container.read(reportProvider.future);

    expect(state.day!.date, '2026-01-02');
    expect(state.currentDayIndex, 0);
  });

  test('closeDay is a no-op when day is already closed', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final day = await repo.getOrCreateToday();

    await repo.insertSaleWithLines(
      sale: Sale(
          dateTime: '2026-01-01T12:00:00.000',
          total: 5.0,
          businessDayId: day.id!),
      lines: [
        SaleLine(
          saleId: 0,
          productId: 1,
          nameSnapshot: 'Coffee',
          priceSnapshot: 2.5,
          quantity: 2,
          subtotal: 5.0,
        ),
      ],
    );
    await repo.updateBusinessDay(day.id!, totalRevenue: 5.0, saleCount: 1);
    await repo.closeBusinessDay(day.id!);

    final container = makeContainer(repo);
    await awaitData(container);

    final before = await container.read(reportProvider.future);
    final closedAtBefore = before.day!.closedAt;

    // Call closeDay on already-closed day — should not change closedAt.
    await container.read(reportProvider.notifier).closeDay();
    final after = await container.read(reportProvider.future);

    expect(after.day!.closedAt, closedAtBefore);
  });
}
