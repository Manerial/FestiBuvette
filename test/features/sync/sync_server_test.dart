import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/products/data/repositories/categories_repository.dart';
import 'package:festi_buvette_app/features/products/data/repositories/products_repository.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_server.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SalesRepository salesRepo;
  late ProductsRepository productsRepo;
  late CategoriesRepository categoriesRepo;
  late SyncServer server;
  late Handler handler;
  const testPin = '123456';

  setUpAll(initTestDatabase);

  setUp(() async {
    dbHelper = await createTestDatabaseHelper();
    salesRepo = SalesRepository(dbHelper);
    productsRepo = ProductsRepository(dbHelper);
    categoriesRepo = CategoriesRepository(dbHelper);

    server = SyncServer(
      salesRepo: salesRepo,
      productsRepo: productsRepo,
      categoriesRepo: categoriesRepo,
      onPrint: (_) async => true,
      initialPin: testPin,
    );
    handler = server.buildHandler();
  });

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Request json(String method, String path, [Object? body]) => Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body != null ? jsonEncode(body) : null,
        headers: body != null ? {'content-type': 'application/json'} : {},
      );

  Request auth(String method, String path, String token, [Object? body]) =>
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body != null ? jsonEncode(body) : null,
        headers: {
          'authorization': 'Bearer $token',
          if (body != null) 'content-type': 'application/json',
        },
      );

  Future<String> authenticate() async {
    final response = await handler(json('POST', '/auth', {'pin': testPin}));
    final body = jsonDecode(await response.readAsString()) as Map;
    return body['token'] as String;
  }

  // ─── POST /auth ───────────────────────────────────────────────────────────────

  group('POST /auth', () {
    test('returns 200 and token with valid PIN', () async {
      final response = await handler(json('POST', '/auth', {'pin': testPin}));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['token'], isA<String>());
      expect((body['token'] as String).length, 32); // 16 bytes hex
    });

    test('returns 401 with invalid PIN', () async {
      final response =
          await handler(json('POST', '/auth', {'pin': 'wrong!'}));
      expect(response.statusCode, 401);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['error'], 'invalid_pin');
    });

    test('generates distinct tokens on each call', () async {
      final r1 = await handler(json('POST', '/auth', {'pin': testPin}));
      final r2 = await handler(json('POST', '/auth', {'pin': testPin}));
      final t1 = (jsonDecode(await r1.readAsString()) as Map)['token'];
      final t2 = (jsonDecode(await r2.readAsString()) as Map)['token'];
      expect(t1, isNot(t2));
    });
  });

  // ─── Auth middleware ──────────────────────────────────────────────────────────

  group('auth middleware', () {
    test('rejects request without Authorization header', () async {
      final response =
          await handler(Request('GET', Uri.parse('http://localhost/status')));
      expect(response.statusCode, 401);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['error'], 'missing_token');
    });

    test('rejects request with invalid token', () async {
      final response =
          await handler(auth('GET', '/status', 'invalid_token_xyz'));
      expect(response.statusCode, 401);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['error'], 'invalid_token');
    });

    test('token is invalidated after updatePin', () async {
      final token = await authenticate();
      server.updatePin('654321');
      final response = await handler(auth('GET', '/status', token));
      expect(response.statusCode, 401);
    });
  });

  // ─── GET /status ──────────────────────────────────────────────────────────────

  group('GET /status', () {
    test('returns role and day_started=false when no day exists', () async {
      final token = await authenticate();
      final response = await handler(auth('GET', '/status', token));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['role'], 'control');
      expect(body['day_started'], isFalse);
      expect(body['connected_seconds'], isA<int>());
    });

    test('returns day_started=true when day is in progress', () async {
      await salesRepo.getOrCreateToday();
      final token = await authenticate();
      final response = await handler(auth('GET', '/status', token));
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['day_started'], isTrue);
    });

    test('returns day_started=false when day is closed', () async {
      final day = await salesRepo.getOrCreateToday();
      await salesRepo.closeBusinessDay(day.id!);
      final token = await authenticate();
      final response = await handler(auth('GET', '/status', token));
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['day_started'], isFalse);
    });
  });

  // ─── GET /sync/catalog ────────────────────────────────────────────────────────

  group('GET /sync/catalog', () {
    test('returns empty products and categories', () async {
      final token = await authenticate();
      final response = await handler(auth('GET', '/sync/catalog', token));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['products'], isA<List>());
      expect(body['categories'], isA<List>());
    });

    test('returns inserted products', () async {
      await dbHelper.database.then((db) => db.insert('products', {
            'name': 'Bière',
            'price': 2.5,
            'sort_order': 0,
            'active': 1,
            'is_out_of_stock': 0,
            'created_at': '2026-01-01T00:00:00.000',
          }));
      final token = await authenticate();
      final response = await handler(auth('GET', '/sync/catalog', token));
      final body = jsonDecode(await response.readAsString()) as Map;
      expect((body['products'] as List).length, 1);
      expect((body['products'] as List).first['name'], 'Bière');
    });
  });

  // ─── POST /print ──────────────────────────────────────────────────────────────

  group('POST /print', () {
    test('returns 200 when print callback succeeds', () async {
      final token = await authenticate();
      final response = await handler(auth('POST', '/print', token, {
        'items': [
          {'name': 'Bière', 'price': 2.5, 'quantity': 2},
        ],
      }));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['ok'], isTrue);
    });

    test('returns 503 when print callback fails', () async {
      final failServer = SyncServer(
        salesRepo: salesRepo,
        productsRepo: productsRepo,
        categoriesRepo: categoriesRepo,
        onPrint: (_) async => false,
        initialPin: testPin,
      );
      final failHandler = failServer.buildHandler();
      final tokenResp =
          await failHandler(json('POST', '/auth', {'pin': testPin}));
      final token = (jsonDecode(await tokenResp.readAsString()) as Map)['token']
          as String;

      final response = await failHandler(auth('POST', '/print', token, {
        'items': [
          {'name': 'Bière', 'price': 2.5, 'quantity': 1},
        ],
      }));
      expect(response.statusCode, 503);
    });
  });

  // ─── POST /sales/push ─────────────────────────────────────────────────────────

  group('POST /sales/push', () {
    test('merges sales and returns merged count', () async {
      await salesRepo.getOrCreateToday();
      final token = await authenticate();
      final response = await handler(auth('POST', '/sales/push', token, {
        'sales': [
          {
            'local_id': 1,
            'date_time': '2026-06-01T10:00:00.000',
            'total': 5.0,
            'lines': [
              {
                'name_snapshot': 'Bière',
                'price_snapshot': 2.5,
                'quantity': 2,
              },
            ],
          },
        ],
      }));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['merged'], 1);
    });

    test('duplicate push is idempotent (merged=0 on second call)', () async {
      await salesRepo.getOrCreateToday();
      final token = await authenticate();
      const payload = {
        'sales': [
          {
            'local_id': 42,
            'date_time': '2026-06-01T11:00:00.000',
            'total': 3.0,
            'lines': [
              {'name_snapshot': 'Café', 'price_snapshot': 3.0, 'quantity': 1},
            ],
          },
        ],
      };

      await handler(auth('POST', '/sales/push', token, payload));
      final response =
          await handler(auth('POST', '/sales/push', token, payload));
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['merged'], 0);
    });

    test('returns 400 when no active day exists', () async {
      final token = await authenticate();
      final response = await handler(auth('POST', '/sales/push', token, {
        'sales': [],
      }));
      expect(response.statusCode, 400);
    });

    test('uses device_id from payload as source_device_token', () async {
      await salesRepo.getOrCreateToday();
      final token = await authenticate();
      const secondDeviceId = 'second-device-uuid-abc123';

      await handler(auth('POST', '/sales/push', token, {
        'device_id': secondDeviceId,
        'sales': [
          {
            'local_id': 77,
            'date_time': '2026-06-01T09:00:00.000',
            'total': 3.0,
            'lines': [
              {'name_snapshot': 'Café', 'price_snapshot': 3.0, 'quantity': 1},
            ],
          },
        ],
      }));

      final db = await dbHelper.database;
      final rows = await db.query(
        'sales',
        where: 'source_device_token = ? AND source_local_id = ?',
        whereArgs: [secondDeviceId, 77],
      );
      expect(rows.length, 1);
      expect(rows.first['total'], 3.0);

      // A second push with same device_id + local_id must be idempotent.
      final response = await handler(auth('POST', '/sales/push', token, {
        'device_id': secondDeviceId,
        'sales': [
          {
            'local_id': 77,
            'date_time': '2026-06-01T09:00:00.000',
            'total': 3.0,
            'lines': [],
          },
        ],
      }));
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['merged'], 0);
    });
  });

  // ─── GET /sales/pull ──────────────────────────────────────────────────────────

  group('GET /sales/pull', () {
    test('returns empty lists when no day exists', () async {
      final token = await authenticate();
      final response = await handler(auth('GET', '/sales/pull', token));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['sales'], isEmpty);
      expect(body['sale_lines'], isEmpty);
    });

    test('returns sales and lines for today after push', () async {
      await salesRepo.getOrCreateToday();
      final token = await authenticate();
      await handler(auth('POST', '/sales/push', token, {
        'sales': [
          {
            'local_id': 99,
            'date_time': '2026-06-01T14:00:00.000',
            'total': 7.5,
            'lines': [
              {'name_snapshot': 'Sandwich', 'price_snapshot': 7.5, 'quantity': 1},
            ],
          },
        ],
      }));

      final pullResponse = await handler(auth('GET', '/sales/pull', token));
      final body = jsonDecode(await pullResponse.readAsString()) as Map;
      expect((body['sales'] as List).length, 1);
      expect((body['sale_lines'] as List).length, 1);
      expect((body['sale_lines'] as List).first['name_snapshot'], 'Sandwich');
    });
  });
}
