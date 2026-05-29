import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/core/services/device_id_service.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_client.dart';

/// Orchestrates the three manual sync operations for the second device.
///
/// P2-4: [downloadCatalog] — GET /sync/catalog → replace local products + categories.
/// P2-6: [sendSales]       — collect local sales → POST /sales/push.
/// P2-7: [downloadSales]   — GET /sales/pull → replace today's local sales.
class SyncActionService {
  final DatabaseHelper _dbHelper;

  const SyncActionService(this._dbHelper);

  // ─── P2-4 — Download catalog ────────────────────────────────────────────────

  /// Replaces the second's local products and categories with the control's.
  ///
  /// Products that are referenced by existing sale_lines are deactivated
  /// (not deleted) so historical reports remain accurate.
  Future<void> downloadCatalog(SyncClient client) async {
    final data = await client.get('/sync/catalog');
    final products = (data['products'] as List).cast<Map<String, dynamic>>();
    final categories = (data['categories'] as List).cast<Map<String, dynamic>>();

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Step 1: deactivate active products that have sale_lines.
      await txn.rawUpdate(
        'UPDATE products SET active = 0, category_id = NULL'
        ' WHERE active = 1'
        '   AND id IN (SELECT DISTINCT product_id FROM sale_lines'
        '              WHERE product_id IS NOT NULL)',
      );

      // Step 2: delete the remaining active products (they have no sale_lines).
      await txn.rawDelete('DELETE FROM products WHERE active = 1');

      // Step 3: delete all categories (deactivated products already have
      // category_id = NULL so there are no FK violations).
      await txn.rawDelete('DELETE FROM categories');

      // Step 4: insert new categories; build a mapping from control id → local id.
      final categoryIdMap = <int, int>{};
      for (final cat in categories) {
        final localId = await txn.insert('categories', {
          'name': cat['name'],
          'sort_order': cat['sort_order'] ?? 0,
        });
        if (cat['id'] != null) categoryIdMap[cat['id'] as int] = localId;
      }

      // Step 5: insert new products with remapped category_ids.
      for (final prod in products) {
        final controlCatId = prod['category_id'] as int?;
        final localCatId =
            controlCatId != null ? categoryIdMap[controlCatId] : null;
        await txn.insert('products', {
          'name': prod['name'],
          'price': prod['price'],
          'sort_order': prod['sort_order'] ?? 0,
          'active': prod['active'] ?? 1,
          'is_out_of_stock': prod['is_out_of_stock'] ?? 0,
          'created_at': prod['created_at'] ?? DateTime.now().toIso8601String(),
          'category_id': localCatId,
        });
      }
    });
  }

  // ─── P2-6 — Send sales ──────────────────────────────────────────────────────

  /// Sends today's sales that belong to this device to the control.
  ///
  /// Filters by [deviceId] (UUID) so sales from other devices — downloaded via
  /// [downloadSales] or received from other seconds — are never re-pushed.
  /// The payload includes the device UUID so the control can use the stable
  /// composite key (device_uuid, local_id) for deduplication.
  Future<int> sendSales(SyncClient client) async {
    final deviceId = await DeviceIdService.get();
    final salesRepo = SalesRepository(_dbHelper);
    final today = await salesRepo.getToday();
    if (today == null) return 0;

    final sales = await salesRepo.getSalesForSyncByDay(today.id!, deviceId);
    if (sales.isEmpty) return 0;

    final payload = {
      'device_id': deviceId,
      'sales': sales
          .map((s) => {
                // Prefer source_local_id over id: after a downloadSales the sale
                // gets a new autoincrement id but source_local_id keeps the
                // original value, which is what the control stored as the
                // deduplication key on the first push.
                'local_id': s.sourceLocalId ?? s.id,
                'date_time': s.dateTime,
                'total': s.total,
                'lines': s.lines
                    .map((l) => {
                          'name_snapshot': l.nameSnapshot,
                          'price_snapshot': l.priceSnapshot,
                          'quantity': l.quantity,
                        })
                    .toList(),
              })
          .toList(),
    };

    final result = await client.post('/sales/push', payload);
    return result['merged'] as int? ?? 0;
  }

  // ─── P2-7 — Download sales ──────────────────────────────────────────────────

  /// Replaces today's local sales with the aggregated view from the control.
  /// Previous days are not affected.
  Future<void> downloadSales(SyncClient client) async {
    final salesRepo = SalesRepository(_dbHelper);
    final today = await salesRepo.getToday();
    if (today == null) return;

    final data = await client.get('/sales/pull');
    final salesData = (data['sales'] as List).cast<Map<String, dynamic>>();
    final linesData =
        (data['sale_lines'] as List).cast<Map<String, dynamic>>();

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Delete today's sale_lines and sales.
      final existingIds = (await txn.query(
        'sales',
        columns: ['id'],
        where: 'business_day_id = ?',
        whereArgs: [today.id],
      ))
          .map((r) => r['id'] as int)
          .toList();

      if (existingIds.isNotEmpty) {
        final placeholders = List.filled(existingIds.length, '?').join(',');
        await txn.rawDelete(
            'DELETE FROM sale_lines WHERE sale_id IN ($placeholders)',
            existingIds);
      }
      await txn.delete('sales',
          where: 'business_day_id = ?', whereArgs: [today.id]);

      // Insert received sales, preserving each sale's (device_uuid, local_id)
      // so this device knows they originated elsewhere and won't re-push them.
      for (final saleData in salesData) {
        final localSaleId = await txn.insert('sales', {
          'date_time': saleData['date_time'],
          'total': saleData['total'],
          'business_day_id': today.id,
          // Preserve the originating device UUID from the control's response.
          // Falls back to the control's sale id if the field is absent
          // (e.g. control sales recorded before UUID tracking).
          'source_device_token': saleData['source_device_token'],
          'source_local_id': saleData['source_local_id'],
        });

        final controlSaleId = saleData['id'];
        for (final line in linesData
            .where((l) => l['sale_id'] == controlSaleId)) {
          await txn.insert('sale_lines', {
            'sale_id': localSaleId,
            'product_id': null,
            'name_snapshot': line['name_snapshot'],
            'price_snapshot': line['price_snapshot'],
            'quantity': line['quantity'],
            'subtotal': (line['price_snapshot'] as num).toDouble() *
                (line['quantity'] as num).toInt(),
          });
        }
      }

      // Update business day aggregates.
      final totalRevenue = salesData.fold<double>(
          0, (sum, s) => sum + (s['total'] as num).toDouble());
      await txn.update(
        'business_days',
        {'total_revenue': totalRevenue, 'sale_count': salesData.length},
        where: 'id = ?',
        whereArgs: [today.id],
      );
    });
  }
}
