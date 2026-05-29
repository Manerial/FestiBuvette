import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/core/services/device_id_service.dart';
import 'package:festi_buvette_app/features/products/data/repositories/categories_repository.dart';
import 'package:festi_buvette_app/features/products/data/repositories/products_repository.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_action_service.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_client.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SyncActionService service;
  late SalesRepository salesRepo;
  late ProductsRepository productsRepo;
  late CategoriesRepository categoriesRepo;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initTestDatabase();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'device_id': 'test-device-uuid'});
    DeviceIdService.resetCache();
    dbHelper = await createTestDatabaseHelper();
    service = SyncActionService(dbHelper);
    salesRepo = SalesRepository(dbHelper);
    productsRepo = ProductsRepository(dbHelper);
    categoriesRepo = CategoriesRepository(dbHelper);
  });

  SyncClient mockClient(Map<String, dynamic> responseBody) => SyncClient(
        baseUrl: 'http://192.168.43.1:8080',
        token: 'testtoken',
        client: MockClient(
            (_) async => http.Response(jsonEncode(responseBody), 200)),
      );

  // ─── P2-4 — downloadCatalog ──────────────────────────────────────────────────

  group('downloadCatalog', () {
    test('inserts products and categories from control response', () async {
      final client = mockClient({
        'products': [
          {
            'name': 'Bière',
            'price': 2.5,
            'sort_order': 0,
            'active': 1,
            'is_out_of_stock': 0,
            'created_at': '2026-01-01T00:00:00.000',
            'category_id': 1,
          },
        ],
        'categories': [
          {'id': 1, 'name': 'Boissons', 'sort_order': 0},
        ],
      });

      await service.downloadCatalog(client);

      final products = await productsRepo.getAllActive();
      final categories = await categoriesRepo.getAll();

      expect(products.length, 1);
      expect(products.first.name, 'Bière');
      expect(categories.length, 1);
      expect(categories.first.name, 'Boissons');
    });

    test('remaps category_id from control to local id', () async {
      final client = mockClient({
        'products': [
          {
            'name': 'Sandwich',
            'price': 5.0,
            'sort_order': 0,
            'active': 1,
            'is_out_of_stock': 0,
            'created_at': '2026-01-01T00:00:00.000',
            'category_id': 99, // control's id — will be remapped
          },
        ],
        'categories': [
          {'id': 99, 'name': 'Food', 'sort_order': 0},
        ],
      });

      await service.downloadCatalog(client);

      final products = await productsRepo.getAllActive();
      final categories = await categoriesRepo.getAll();

      expect(categories.length, 1);
      final localCatId = categories.first.id;
      expect(products.first.categoryId, localCatId);
    });

    test('deactivates products with sale_lines instead of deleting', () async {
      // Insert a product and a sale that references it.
      final db = await dbHelper.database;
      final productId = await db.insert('products', {
        'name': 'OldBeer',
        'price': 2.0,
        'sort_order': 0,
        'active': 1,
        'is_out_of_stock': 0,
        'created_at': '2026-01-01T00:00:00.000',
      });
      final day = await salesRepo.getOrCreateToday();
      final saleId = await db.insert('sales', {
        'date_time': '2026-01-01T10:00:00.000',
        'total': 2.0,
        'business_day_id': day.id,
      });
      await db.insert('sale_lines', {
        'sale_id': saleId,
        'product_id': productId,
        'name_snapshot': 'OldBeer',
        'price_snapshot': 2.0,
        'quantity': 1,
        'subtotal': 2.0,
      });

      await service.downloadCatalog(mockClient({'products': [], 'categories': []}));

      // OldBeer should still exist but be deactivated.
      final rows = await db.query('products',
          where: 'id = ?', whereArgs: [productId]);
      expect(rows.length, 1);
      expect(rows.first['active'], 0);
    });

    test('deletes products without sale_lines', () async {
      final db = await dbHelper.database;
      await db.insert('products', {
        'name': 'UnusedProduct',
        'price': 1.0,
        'sort_order': 0,
        'active': 1,
        'is_out_of_stock': 0,
        'created_at': '2026-01-01T00:00:00.000',
      });

      await service.downloadCatalog(mockClient({'products': [], 'categories': []}));

      final active = await productsRepo.getAllActive();
      expect(active, isEmpty);
    });
  });

  // ─── P2-6 — sendSales ────────────────────────────────────────────────────────

  group('sendSales', () {
    test('returns 0 when no business day exists', () async {
      final client = mockClient({'merged': 0});
      expect(await service.sendSales(client), 0);
    });

    test('sends today sales and returns merged count', () async {
      final day = await salesRepo.getOrCreateToday();
      final db = await dbHelper.database;
      final saleId = await db.insert('sales', {
        'date_time': '2026-01-01T10:00:00.000',
        'total': 5.0,
        'business_day_id': day.id,
      });
      await db.insert('sale_lines', {
        'sale_id': saleId,
        'product_id': null,
        'name_snapshot': 'Bière',
        'price_snapshot': 2.5,
        'quantity': 2,
        'subtotal': 5.0,
      });

      Map<String, dynamic>? sentPayload;
      final capturingClient = SyncClient(
        baseUrl: 'http://192.168.43.1:8080',
        token: 'tok',
        client: MockClient((req) async {
          sentPayload = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{"merged":1}', 200);
        }),
      );

      final merged = await service.sendSales(capturingClient);
      expect(merged, 1);
      expect(sentPayload, isNotNull);

      final sales = (sentPayload!['sales'] as List).cast<Map>();
      expect(sales.length, 1);
      expect(sales.first['local_id'], saleId);
      expect(sales.first['total'], 5.0);
      final lines = (sales.first['lines'] as List).cast<Map>();
      expect(lines.first['name_snapshot'], 'Bière');
    });
  });

  // ─── P2-7 — downloadSales ────────────────────────────────────────────────────

  group('downloadSales', () {
    test('no-op when no business day exists', () async {
      // Should complete without throwing.
      await service.downloadSales(mockClient({'sales': [], 'sale_lines': []}));
    });

    test('replaces today sales with control data', () async {
      final day = await salesRepo.getOrCreateToday();
      final db = await dbHelper.database;

      // Local existing sale to be replaced.
      await db.insert('sales', {
        'date_time': '2026-01-01T08:00:00.000',
        'total': 3.0,
        'business_day_id': day.id,
      });

      await service.downloadSales(mockClient({
        'sales': [
          {
            'id': 100, // control's id
            'date_time': '2026-06-01T10:00:00.000',
            'total': 7.5,
            'business_day_id': day.id,
          },
        ],
        'sale_lines': [
          {
            'id': 200,
            'sale_id': 100, // references control's sale id
            'name_snapshot': 'Sandwich',
            'price_snapshot': 7.5,
            'quantity': 1,
            'subtotal': 7.5,
          },
        ],
      }));

      final sales = await salesRepo.getSalesWithLinesByDay(day.id!);
      expect(sales.length, 1);
      expect(sales.first.total, 7.5);
      expect(sales.first.lines.length, 1);
      expect(sales.first.lines.first.nameSnapshot, 'Sandwich');
    });

    test('updates business day aggregates after download', () async {
      final day = await salesRepo.getOrCreateToday();

      await service.downloadSales(mockClient({
        'sales': [
          {'id': 1, 'date_time': '2026-06-01T10:00:00.000', 'total': 4.0, 'business_day_id': day.id},
          {'id': 2, 'date_time': '2026-06-01T11:00:00.000', 'total': 6.0, 'business_day_id': day.id},
        ],
        'sale_lines': [],
      }));

      final updated = await salesRepo.getToday();
      expect(updated!.totalRevenue, closeTo(10.0, 0.001));
      expect(updated.saleCount, 2);
    });

    test('does not affect previous business days', () async {
      final db = await dbHelper.database;
      // Insert a past business day with a sale.
      final pastDayId = await db.insert('business_days', {
        'date': '2026-05-01',
        'total_revenue': 50.0,
        'sale_count': 5,
        'closed_at': '2026-05-01T23:59:00.000',
      });
      await db.insert('sales', {
        'date_time': '2026-05-01T10:00:00.000',
        'total': 10.0,
        'business_day_id': pastDayId,
      });

      await salesRepo.getOrCreateToday();
      await service.downloadSales(mockClient({'sales': [], 'sale_lines': []}));

      // Past day untouched.
      final pastSales = await salesRepo.getSalesByDay(pastDayId);
      expect(pastSales.length, 1);
    });
  });

  // ─── Regression: push after download uses source_local_id ───────────────────

  group('sendSales after downloadSales preserves original local_id', () {
    // After downloadSales the second's own sales are re-inserted with a new
    // autoincrement id. sendSales must use source_local_id (the original id)
    // as local_id so the control's composite key (device_uuid, source_local_id)
    // still matches → no duplicate.
    test('local_id in payload matches source_local_id, not the new db id',
        () async {
      const localDeviceId = 'test-device-uuid';
      final day = await salesRepo.getOrCreateToday();
      final db = await dbHelper.database;

      // Simulate the state after a first push + download:
      // The control re-sends the second's own sale with its original ids.
      await service.downloadSales(mockClient({
        'sales': [
          {
            'id': 50,
            'date_time': '2026-06-01T10:00:00.000',
            'total': 4.0,
            'business_day_id': day.id,
            'source_device_token': localDeviceId, // second's own sale
            'source_local_id': 50,                // original id before download
          },
        ],
        'sale_lines': [
          {
            'id': 1,
            'sale_id': 50,
            'name_snapshot': 'Bière',
            'price_snapshot': 4.0,
            'quantity': 1,
          },
        ],
      }));

      // After download, the sale has a NEW db id but source_local_id = 50.
      final rows = await db.query('sales',
          where: 'source_device_token = ?', whereArgs: [localDeviceId]);
      expect(rows.length, 1);
      final newDbId = rows.first['id'] as int;
      expect(rows.first['source_local_id'], 50);
      // The new autoincrement id should differ from the original (50 was the
      // control's id, not necessarily reassigned locally).
      // Regardless, local_id in the push payload must be source_local_id.

      Map<String, dynamic>? pushed;
      final capturingClient = SyncClient(
        baseUrl: 'http://192.168.43.1:8080',
        token: 'tok',
        client: MockClient((req) async {
          pushed = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{"merged":0}', 200);
        }),
      );

      await service.sendSales(capturingClient);

      final sentSales = (pushed!['sales'] as List).cast<Map>();
      expect(sentSales.length, 1);
      // Must use source_local_id (50), not the new autoincrement db id.
      expect(sentSales.first['local_id'], 50);
      expect(sentSales.first['local_id'], isNot(equals(newDbId)),
          reason: 'local_id must be the original id, not the re-inserted db id');
    });
  });

  // ─── Regression: no duplicates after download + push ─────────────────────────

  group('sendSales after downloadSales', () {
    // New design: locally-created sales carry source_device_token = device UUID.
    // Downloaded sales carry the originating device's UUID from the server response.
    // sendSales() filters by device UUID so downloaded sales are never re-pushed.
    test('does not re-send downloaded sales — only device-UUID-tagged ones',
        () async {
      const localDeviceId = 'test-device-uuid'; // set in setUp
      const controlDeviceId = 'control-device-uuid-abc';
      final day = await salesRepo.getOrCreateToday();
      final db = await dbHelper.database;

      // 1. Download 2 sales from the control.
      //    The control's response includes source_device_token of each sale.
      await service.downloadSales(mockClient({
        'sales': [
          {
            'id': 100,
            'date_time': '2026-06-01T10:00:00.000',
            'total': 5.0,
            'business_day_id': day.id,
            'source_device_token': controlDeviceId,
            'source_local_id': 100,
          },
          {
            'id': 101,
            'date_time': '2026-06-01T11:00:00.000',
            'total': 7.0,
            'business_day_id': day.id,
            'source_device_token': controlDeviceId,
            'source_local_id': 101,
          },
        ],
        'sale_lines': [],
      }));
      // DB now has 2 downloaded sales with source_device_token = controlDeviceId.

      // 2. Create a local sale tagged with this device's UUID (as SaleService does).
      final localSaleId = await db.insert('sales', {
        'date_time': '2026-06-01T12:00:00.000',
        'total': 2.0,
        'business_day_id': day.id,
        'source_device_token': localDeviceId,
        'source_local_id': 99, // would be the sale's own id in practice
      });
      await db.insert('sale_lines', {
        'sale_id': localSaleId,
        'product_id': null,
        'name_snapshot': 'Eau',
        'price_snapshot': 2.0,
        'quantity': 1,
        'subtotal': 2.0,
      });

      // 3. Capture what gets pushed.
      Map<String, dynamic>? pushed;
      final capturingClient = SyncClient(
        baseUrl: 'http://192.168.43.1:8080',
        token: 'tok',
        client: MockClient((req) async {
          pushed = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{"merged":1}', 200);
        }),
      );

      await service.sendSales(capturingClient);

      // Only the local sale (device UUID = localDeviceId) should be sent.
      // The 2 downloaded sales (device UUID = controlDeviceId) must be excluded.
      expect(pushed!['device_id'], localDeviceId);
      final sentSales = (pushed!['sales'] as List).cast<Map>();
      expect(sentSales.length, 1);
      expect(sentSales.first['total'], 2.0);
    });
  });
}
