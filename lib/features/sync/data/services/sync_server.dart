import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:festi_buvette_app/features/products/data/repositories/categories_repository.dart';
import 'package:festi_buvette_app/features/products/data/repositories/products_repository.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';
import 'package:festi_buvette_app/features/sync/data/models/connected_device.dart';

typedef PrintCallback = Future<bool> Function(List<Map<String, dynamic>> items);

class SyncServer {
  static const int port = 8080;

  final SalesRepository salesRepo;
  final ProductsRepository productsRepo;
  final CategoriesRepository categoriesRepo;
  final PrintCallback onPrint;

  String _pin;
  final Map<String, ConnectedDevice> _connectedSeconds = {};
  HttpServer? _httpServer;

  /// Called whenever the connected-seconds count changes.
  void Function(int connectedCount)? onConnectedSecondsChanged;

  SyncServer({
    required this.salesRepo,
    required this.productsRepo,
    required this.categoriesRepo,
    required this.onPrint,
    required String initialPin,
  }) : _pin = initialPin;

  bool get isRunning => _httpServer != null;
  int get connectedSecondsCount => _connectedSeconds.length;

  /// Updates the PIN and invalidates all existing tokens.
  void updatePin(String pin) {
    _pin = pin;
    _connectedSeconds.clear();
    onConnectedSecondsChanged?.call(0);
  }

  Future<void> start() async {
    if (_httpServer != null) return;
    _httpServer = await shelf_io.serve(
      buildHandler(),
      InternetAddress.anyIPv4,
      port,
      shared: false,
    );
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
    _connectedSeconds.clear();
  }

  // ─── Handler (also used in unit tests) ─────────────────────────────────────

  Handler buildHandler() {
    final router = Router()
      ..post('/auth', _handleAuth)
      ..get('/status', _handleStatus)
      ..get('/sync/catalog', _handleGetCatalog)
      ..post('/print', _handlePrint)
      ..post('/sales/push', _handleSalesPush)
      ..get('/sales/pull', _handleSalesPull);

    return Pipeline()
        .addMiddleware(_authMiddleware())
        .addHandler(router.call);
  }

  // ─── Auth middleware ────────────────────────────────────────────────────────

  Middleware _authMiddleware() => (innerHandler) {
        return (Request request) {
          // '/auth' or 'auth' depending on how the Request is created
          if (request.url.pathSegments.isNotEmpty &&
              request.url.pathSegments.first == 'auth') {
            return innerHandler(request);
          }

          final auth = request.headers['authorization'];
          if (auth == null || !auth.startsWith('Bearer ')) {
            return Future.value(Response(
              401,
              body: '{"error":"missing_token"}',
              headers: {'content-type': 'application/json'},
            ));
          }
          final token = auth.substring(7);
          if (!_connectedSeconds.containsKey(token)) {
            return Future.value(Response(
              401,
              body: '{"error":"invalid_token"}',
              headers: {'content-type': 'application/json'},
            ));
          }
          return innerHandler(request);
        };
      };

  // ─── Route handlers ─────────────────────────────────────────────────────────

  Future<Response> _handleAuth(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      if (body['pin'] != _pin) {
        return Response(
          401,
          body: '{"error":"invalid_pin"}',
          headers: {'content-type': 'application/json'},
        );
      }
      final token = _generateToken();
      final info = request.context['shelf.io.connection_info']
          as HttpConnectionInfo?;
      _connectedSeconds[token] = ConnectedDevice(
        token: token,
        ip: info?.remoteAddress.address ?? 'unknown',
        connectedAt: DateTime.now().toIso8601String(),
      );
      onConnectedSecondsChanged?.call(_connectedSeconds.length);
      return Response.ok(
        jsonEncode({'token': token}),
        headers: {'content-type': 'application/json'},
      );
    } catch (_) {
      return Response(
        400,
        body: '{"error":"invalid_request"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _handleStatus(Request request) async {
    final day = await salesRepo.getToday();
    return Response.ok(
      jsonEncode({
        'role': 'control',
        'day_started': day != null && !day.isClosed,
        'connected_seconds': _connectedSeconds.length,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleGetCatalog(Request request) async {
    final products = await productsRepo.getAllActive();
    final categories = await categoriesRepo.getAll();
    return Response.ok(
      jsonEncode({
        'products': products.map((p) => p.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handlePrint(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final items = (body['items'] as List).cast<Map<String, dynamic>>();
      final ok = await onPrint(items);
      return ok
          ? Response.ok(
              '{"ok":true}',
              headers: {'content-type': 'application/json'},
            )
          : Response(
              503,
              body: '{"error":"print_failed"}',
              headers: {'content-type': 'application/json'},
            );
    } catch (_) {
      return Response(
        400,
        body: '{"error":"invalid_request"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _handleSalesPush(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final salesData = (body['sales'] as List).cast<Map<String, dynamic>>();

      // Use the device UUID from the payload as the stable identifier.
      // This replaces the bearer token so deduplication survives PIN rotations.
      final deviceId = body['device_id'] as String?
          ?? request.headers['authorization']!.substring(7);

      final day = await salesRepo.getToday();
      if (day == null) {
        return Response(
          400,
          body: '{"error":"no_active_day"}',
          headers: {'content-type': 'application/json'},
        );
      }

      int mergedCount = 0;
      for (final saleData in salesData) {
        final lines = (saleData['lines'] as List).cast<Map<String, dynamic>>();
        mergedCount += await salesRepo.mergeReceivedSale(
          businessDayId: day.id!,
          deviceToken: deviceId,
          localId: saleData['local_id'] as int,
          dateTime: saleData['date_time'] as String,
          total: (saleData['total'] as num).toDouble(),
          lines: lines,
        );
      }

      return Response.ok(
        jsonEncode({'merged': mergedCount}),
        headers: {'content-type': 'application/json'},
      );
    } catch (_) {
      return Response(
        400,
        body: '{"error":"invalid_request"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _handleSalesPull(Request request) async {
    final day = await salesRepo.getToday();
    if (day == null) {
      return Response.ok(
        jsonEncode({'sales': [], 'sale_lines': []}),
        headers: {'content-type': 'application/json'},
      );
    }

    // Use the raw query that exposes source_device_token + source_local_id
    // so the second can reconstruct the composite key when downloading.
    final salesRaw = await salesRepo.getSalesForPullByDay(day.id!);
    final salesWithLines = await salesRepo.getSalesWithLinesByDay(day.id!);

    return Response.ok(
      jsonEncode({
        'sales': salesRaw,
        'sale_lines': salesWithLines
            .expand((s) => s.lines)
            .map((l) => {
                  'id': l.id,
                  'sale_id': l.saleId,
                  if (l.productId != null) 'product_id': l.productId,
                  'name_snapshot': l.nameSnapshot,
                  'price_snapshot': l.priceSnapshot,
                  'quantity': l.quantity,
                  'subtotal': l.subtotal,
                })
            .toList(),
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static String _generateToken() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
