import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:festi_buvette_app/features/report/providers/report_provider.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale_line.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';

import '../../helpers/database_test_helper.dart';

String get todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

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

  Future<ReportState> awaitData(ProviderContainer container) =>
      container.read(reportProvider.future);

  // ─── Virtual todayDate ───────────────────────────────────────────────────────────

  test('initial state is virtual todayDate when no real business day exists',
      () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.isTodayVirtual, isTrue);
    expect(state.day, isNull);
    expect(state.hasData, isFalse);
    expect(state.productTotals, isEmpty);
    expect(state.isDayToday, isTrue);
    expect(state.canGoPrevious, isFalse);
    expect(state.canGoNext, isFalse);
  });

  test('initial state is virtual todayDate when only past days exist', () async {
    final helper = await createTestDatabaseHelper();
    final db = await helper.database;
    await db.insert('business_days', {
      'date': '2026-01-01',
      'total_revenue': 10.0,
      'sale_count': 1,
      'closed_at': null,
    });
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.isTodayVirtual, isTrue);
    expect(state.canGoPrevious, isTrue); // can navigate to 2026-01-01
    expect(state.canGoNext, isFalse);
  });

  test('initial state shows real todayDate when it exists', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    await repo.getOrCreateToday();
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.isTodayVirtual, isFalse);
    expect(state.day, isNotNull);
    expect(state.day!.date, todayDate);
  });

  test('startDay transitions from virtual to real todayDate', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    final before = await awaitData(container);
    expect(before.isTodayVirtual, isTrue);

    await container.read(reportProvider.notifier).startDay();
    final after = await container.read(reportProvider.future);

    expect(after.isTodayVirtual, isFalse);
    expect(after.day, isNotNull);
    expect(after.day!.date, todayDate);
  });

  // ─── hasData ─────────────────────────────────────────────────────────────────

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
    await repo.getOrCreateToday();
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.hasData, isFalse);
    expect(state.day, isNotNull);
    expect(state.day!.saleCount, 0);
  });

  // ─── With sales ──────────────────────────────────────────────────────────────

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

  // ─── refresh ─────────────────────────────────────────────────────────────────

  test('refresh reloads updated data', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    final before = await awaitData(container);
    expect(before.hasData, isFalse);

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

    await container.read(reportProvider.notifier).refresh();
    final after = await container.read(reportProvider.future);

    expect(after.hasData, isTrue);
    expect(after.day!.saleCount, 1);
  });

  // ─── closeDay ────────────────────────────────────────────────────────────────

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

    expect((await container.read(reportProvider.future)).day!.isClosed,
        isFalse);

    await container.read(reportProvider.notifier).closeDay();
    final closed = await container.read(reportProvider.future);

    expect(closed.day!.isClosed, isTrue);
    expect(closed.day!.closedAt, isNotNull);
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

    await container.read(reportProvider.notifier).closeDay();
    final after = await container.read(reportProvider.future);

    expect(after.day!.closedAt, closedAtBefore);
  });

  test('closeDay is a no-op on virtual todayDate', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    final before = await awaitData(container);
    expect(before.isTodayVirtual, isTrue);

    await container.read(reportProvider.notifier).closeDay();
    final after = await container.read(reportProvider.future);

    expect(after.isTodayVirtual, isTrue);
  });

  // ─── reopenDay ───────────────────────────────────────────────────────────────

  test('reopenDay clears closed_at on today', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final day = await repo.getOrCreateToday();
    await repo.closeBusinessDay(day.id!);

    final container = makeContainer(repo);
    await awaitData(container);

    await container.read(reportProvider.notifier).reopenDay();
    final after = await container.read(reportProvider.future);

    expect(after.day!.isClosed, isFalse);
    expect(after.day!.closedAt, isNull);
  });

  test('reopenDay is a no-op when day is already open', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    await repo.getOrCreateToday();

    final container = makeContainer(repo);
    final before = await awaitData(container);
    expect(before.day!.isClosed, isFalse);

    await container.read(reportProvider.notifier).reopenDay();
    final after = await container.read(reportProvider.future);

    expect(after.day!.isClosed, isFalse);
  });

  test('reopenDay is a no-op when viewing a past day', () async {
    final helper = await createTestDatabaseHelper();
    final db = await helper.database;
    await db.insert('business_days', {
      'date': '2026-01-01',
      'total_revenue': 10.0,
      'sale_count': 1,
      'closed_at': '2026-01-01T23:59:00.000',
    });
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);
    await awaitData(container); // virtual today

    // Navigate to the past day
    await container.read(reportProvider.notifier).goToPreviousDay();
    final pastDay = await container.read(reportProvider.future);
    expect(pastDay.day!.isClosed, isTrue);
    expect(pastDay.isDayToday, isFalse);

    await container.read(reportProvider.notifier).reopenDay();
    final after = await container.read(reportProvider.future);

    // Past day must not be reopened
    expect(after.day!.isClosed, isTrue);
  });

  // ─── Day navigation ──────────────────────────────────────────────────────────

  test('canGoPrevious and canGoNext are false with real todayDate and no past days',
      () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final day = await repo.getOrCreateToday();
    await repo.updateBusinessDay(day.id!, totalRevenue: 5.0, saleCount: 1);
    final container = makeContainer(repo);

    final state = await awaitData(container);

    expect(state.isTodayVirtual, isFalse);
    expect(state.canGoPrevious, isFalse);
    expect(state.canGoNext, isFalse);
  });

  test('goToPreviousDay from virtual todayDate loads the most recent past day',
      () async {
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

    final initial = await awaitData(container);
    expect(initial.isTodayVirtual, isTrue);
    expect(initial.canGoPrevious, isTrue);
    expect(initial.canGoNext, isFalse);

    await container.read(reportProvider.notifier).goToPreviousDay();
    final prev = await container.read(reportProvider.future);

    expect(prev.day!.date, '2026-01-02');
    expect(prev.isTodayVirtual, isFalse);
    expect(prev.canGoPrevious, isTrue);
    expect(prev.canGoNext, isTrue); // can go back to virtual todayDate
  });

  test('goToNextDay from past day with virtual todayDate returns to virtual todayDate',
      () async {
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

    // Virtual todayDate → 2026-01-02 → virtual todayDate
    await container.read(reportProvider.notifier).goToPreviousDay();
    await container.read(reportProvider.notifier).goToNextDay();
    final state = await container.read(reportProvider.future);

    expect(state.isTodayVirtual, isTrue);
  });

  test('goToPreviousDay navigates between past days correctly', () async {
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
    await awaitData(container); // ensure provider is built

    // Virtual todayDate → 2026-01-02 → 2026-01-01
    await container.read(reportProvider.notifier).goToPreviousDay();
    await container.read(reportProvider.notifier).goToPreviousDay();
    final state = await container.read(reportProvider.future);

    expect(state.day!.date, '2026-01-01');
    expect(state.currentDayIndex, 1);
    expect(state.canGoPrevious, isFalse);
    expect(state.canGoNext, isTrue);
  });

  test('goToNextDay on virtual todayDate is a no-op', () async {
    final helper = await createTestDatabaseHelper();
    final db = await helper.database;
    await db.insert('business_days', {
      'date': '2026-01-01',
      'total_revenue': 10.0,
      'sale_count': 1,
      'closed_at': null,
    });
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    await awaitData(container); // starts on virtual todayDate
    await container.read(reportProvider.notifier).goToNextDay(); // no-op
    final state = await container.read(reportProvider.future);

    expect(state.isTodayVirtual, isTrue);
  });

  test('goToPreviousDay on the oldest day is a no-op', () async {
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
    await awaitData(container); // ensure provider is built

    // Navigate to oldest then try to go further.
    await container.read(reportProvider.notifier).goToPreviousDay();
    await container.read(reportProvider.notifier).goToPreviousDay();
    await container.read(reportProvider.notifier).goToPreviousDay(); // no-op
    final state = await container.read(reportProvider.future);

    expect(state.day!.date, '2026-01-01');
  });

  // ─── deleteSale ──────────────────────────────────────────────────────────────

  test('deleteSale reduces saleCount to 0 and removes the sale', () async {
    final helper = await createTestDatabaseHelper();
    final repo = SalesRepository(helper);
    final day = await repo.getOrCreateToday();

    final sale = await repo.insertSaleWithLines(
      sale: Sale(
        dateTime: '2026-01-01T10:00:00.000',
        total: 5.0,
        businessDayId: day.id!,
      ),
      lines: [
        SaleLine(
          saleId: 0,
          nameSnapshot: 'Bière',
          priceSnapshot: 2.5,
          quantity: 2,
          subtotal: 5.0,
        ),
      ],
    );
    await repo.incrementBusinessDay(day.id!, 5.0);

    final container = makeContainer(repo);
    final before = await awaitData(container);
    expect(before.day!.saleCount, 1);
    expect(before.sales.length, 1);

    await container.read(reportProvider.notifier).deleteSale(sale);
    final after = await container.read(reportProvider.future);

    expect(after.day!.saleCount, 0);
    expect(after.sales, isEmpty);
    expect(after.hasData, isFalse);
  });

  test('canGoNext is false with real todayDate and no virtual slot', () async {
    final helper = await createTestDatabaseHelper();
    final db = await helper.database;
    // Insert yesterday AND todayDate so no virtual slot exists.
    await db.insert('business_days', {
      'date': '2026-01-01',
      'total_revenue': 10.0,
      'sale_count': 1,
      'closed_at': null,
    });
    await db.insert('business_days', {
      'date': todayDate,
      'total_revenue': 20.0,
      'sale_count': 2,
      'closed_at': null,
    });
    final repo = SalesRepository(helper);
    final container = makeContainer(repo);

    final state = await awaitData(container);
    expect(state.day!.date, todayDate);
    expect(state.canGoNext, isFalse); // already at real todayDate, no virtual slot
    expect(state.canGoPrevious, isTrue);
  });
}
