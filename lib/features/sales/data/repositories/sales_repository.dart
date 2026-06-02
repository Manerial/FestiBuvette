import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/sales/data/models/business_day.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale_line.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper;

  SalesRepository(this._dbHelper);

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  // ─── Business Days ──────────────────────────────────────────────────────────

  /// Returns today's business day, creating it if it doesn't exist.
  /// Safe under concurrent calls: INSERT OR IGNORE prevents UNIQUE violations.
  Future<BusinessDay> getOrCreateToday() async {
    final db = await _dbHelper.database;
    final today = _dateFmt.format(DateTime.now());

    await db.insert('business_days', {
      'date': today,
      'total_revenue': 0.0,
      'sale_count': 0,
      'closed_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final rows = await db.query(
      'business_days',
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );
    return BusinessDay.fromMap(rows.first);
  }

  /// Updates totalRevenue and saleCount for a business day.
  Future<void> updateBusinessDay(
    int businessDayId, {
    required double totalRevenue,
    required int saleCount,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'business_days',
      {'total_revenue': totalRevenue, 'sale_count': saleCount},
      where: 'id = ?',
      whereArgs: [businessDayId],
    );
  }

  /// Increments total_revenue and sale_count atomically.
  /// Use this when recording a sale — safe under concurrent calls unlike
  /// [updateBusinessDay], which writes absolute values.
  Future<void> incrementBusinessDay(int businessDayId, double amount) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE business_days'
      ' SET total_revenue = total_revenue + ?,'
      '     sale_count    = sale_count + 1'
      ' WHERE id = ?',
      [amount, businessDayId],
    );
  }

  /// Closes a business day.
  Future<void> closeBusinessDay(int businessDayId) async {
    final db = await _dbHelper.database;
    await db.update(
      'business_days',
      {'closed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [businessDayId],
    );
  }

  /// Reopens a previously closed business day (sets closed_at back to NULL).
  Future<void> reopenBusinessDay(int businessDayId) async {
    final db = await _dbHelper.database;
    await db.update(
      'business_days',
      {'closed_at': null},
      where: 'id = ?',
      whereArgs: [businessDayId],
    );
  }

  /// Closes all past business days that were left open.
  /// Sets closed_at to the end of that day (23:59:00.000).
  /// [today] must be an ISO date string (yyyy-MM-dd). Called once on app launch.
  Future<void> autoCloseUnclosedPastDays(String today) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      "UPDATE business_days"
      " SET closed_at = date || 'T23:59:00.000'"
      " WHERE date < ? AND closed_at IS NULL",
      [today],
    );
  }

  // ─── Sales ─────────────────────────────────────────────────────────────────

  /// Inserts a sale AND its lines in an atomic transaction.
  /// When [deviceId] is provided, [source_device_token] is set to it and
  /// [source_local_id] is set to the auto-generated sale id — forming the
  /// composite key (device_uuid, local_id) that uniquely identifies this sale
  /// across the whole fleet.
  /// Returns the created sale with its id.
  Future<Sale> insertSaleWithLines({
    required Sale sale,
    required List<SaleLine> lines,
    String? deviceId,
  }) async {
    final db = await _dbHelper.database;

    late int saleId;
    await db.transaction((txn) async {
      saleId = await txn.insert('sales', sale.toMap());
      if (deviceId != null) {
        await txn.update(
          'sales',
          {'source_device_token': deviceId, 'source_local_id': saleId},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }
      for (final line in lines) {
        await txn.insert(
          'sale_lines',
          SaleLine(
            saleId: saleId,
            productId: line.productId,
            nameSnapshot: line.nameSnapshot,
            priceSnapshot: line.priceSnapshot,
            quantity: line.quantity,
            subtotal: line.subtotal,
          ).toMap(),
        );
      }
    });

    return Sale.fromMap({...sale.toMap(), 'id': saleId}, lines: lines);
  }

  /// Returns all sales for a business day (without their lines).
  Future<List<Sale>> getSalesByDay(int businessDayId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sales',
      where: 'business_day_id = ?',
      whereArgs: [businessDayId],
      orderBy: 'date_time DESC',
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  /// Returns lines for a given sale.
  Future<List<SaleLine>> getLinesBySale(int saleId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sale_lines',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return rows.map(SaleLine.fromMap).toList();
  }

  /// Aggregated totals by product for a given business day.
  /// Returns a list of maps {name_snapshot, total_quantity, product_total}.
  Future<List<Map<String, dynamic>>> getTotalsByProduct(
    int businessDayId,
  ) async {
    final db = await _dbHelper.database;
    return db.rawQuery(
      '''
      SELECT
        sl.name_snapshot,
        MIN(sl.price_snapshot) AS price_snapshot,
        SUM(sl.quantity)       AS total_quantity,
        SUM(sl.subtotal)       AS product_total
      FROM sale_lines sl
      JOIN sales s ON s.id = sl.sale_id
      WHERE s.business_day_id = ?
      GROUP BY sl.product_id, sl.name_snapshot
      ORDER BY total_quantity DESC
    ''',
      [businessDayId],
    );
  }

  /// Returns today's business day if it exists (without creating it).
  Future<BusinessDay?> getToday() async {
    final db = await _dbHelper.database;
    final today = _dateFmt.format(DateTime.now());
    final rows = await db.query(
      'business_days',
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );
    return rows.isEmpty ? null : BusinessDay.fromMap(rows.first);
  }

  /// Returns all sales for a day as raw maps including [source_device_token]
  /// and [source_local_id]. Used by the HTTP server's /sales/pull endpoint so
  /// the second device can preserve the composite device-key when storing.
  Future<List<Map<String, dynamic>>> getSalesForPullByDay(
    int businessDayId,
  ) async {
    final db = await _dbHelper.database;
    return db.rawQuery(
      'SELECT id, date_time, total, business_day_id,'
      ' source_device_token, source_local_id'
      ' FROM sales WHERE business_day_id = ?'
      ' ORDER BY date_time DESC',
      [businessDayId],
    );
  }

  /// Returns sales eligible for pushing to the control:
  /// - Sales tagged with [deviceId] (created on this device with UUID tracking)
  /// - Legacy sales with source_device_token IS NULL (created before UUID
  ///   tracking was introduced)
  ///
  /// Explicitly excludes sales from other devices (downloaded from control or
  /// received from another second) so they are never re-pushed as duplicates.
  Future<List<Sale>> getSalesForSyncByDay(
    int businessDayId,
    String deviceId,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sales',
      where:
          'business_day_id = ?'
          ' AND (source_device_token IS NULL OR source_device_token = ?)',
      whereArgs: [businessDayId, deviceId],
      orderBy: 'date_time DESC',
    );
    final sales = rows.map((r) => Sale.fromMap(r)).toList();
    if (sales.isEmpty) return [];

    final saleIds = sales.map((s) => s.id!).toList();
    final placeholders = List.filled(saleIds.length, '?').join(', ');
    final lineRows = await db.rawQuery(
      'SELECT * FROM sale_lines WHERE sale_id IN ($placeholders) ORDER BY sale_id, id',
      saleIds,
    );
    final linesBySaleId = <int, List<SaleLine>>{};
    for (final row in lineRows) {
      (linesBySaleId[row['sale_id'] as int] ??= []).add(SaleLine.fromMap(row));
    }
    return sales
        .map(
          (s) =>
              Sale.fromMap(s.toMap(), lines: linesBySaleId[s.id!] ?? const []),
        )
        .toList();
  }

  /// Returns all sales for a business day, each with its lines pre-loaded.
  /// Uses 2 queries instead of N+1 for performance.
  Future<List<Sale>> getSalesWithLinesByDay(int businessDayId) async {
    final sales = await getSalesByDay(businessDayId);
    if (sales.isEmpty) return [];

    final db = await _dbHelper.database;
    final saleIds = sales.map((s) => s.id!).toList();
    final placeholders = List.filled(saleIds.length, '?').join(', ');

    final lineRows = await db.rawQuery(
      'SELECT * FROM sale_lines WHERE sale_id IN ($placeholders) ORDER BY sale_id, id',
      saleIds,
    );

    final linesBySaleId = <int, List<SaleLine>>{};
    for (final row in lineRows) {
      (linesBySaleId[row['sale_id'] as int] ??= []).add(SaleLine.fromMap(row));
    }

    return sales
        .map(
          (s) =>
              Sale.fromMap(s.toMap(), lines: linesBySaleId[s.id!] ?? const []),
        )
        .toList();
  }

  /// Deletes a sale and its lines in an atomic transaction, then updates
  /// the parent business day aggregates accordingly.
  Future<void> deleteSale(Sale sale) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'sale_lines',
        where: 'sale_id = ?',
        whereArgs: [sale.id],
      );
      await txn.delete('sales', where: 'id = ?', whereArgs: [sale.id]);
    });

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS rev, COUNT(*) AS cnt FROM sales WHERE business_day_id = ?',
      [sale.businessDayId],
    );
    final rev = (rows.first['rev'] as num).toDouble();
    final cnt = rows.first['cnt'] as int;
    await updateBusinessDay(
      sale.businessDayId,
      totalRevenue: rev,
      saleCount: cnt,
    );
  }

  /// Returns hourly sales per product for a given business day.
  /// Each row: { hour (int 9–18), name_snapshot, total_quantity }.
  /// Hours outside 9–18 are excluded.
  Future<List<Map<String, dynamic>>> getHourlySalesByProduct(
    int businessDayId,
  ) async {
    final db = await _dbHelper.database;
    return db.rawQuery(
      '''
      SELECT
        CAST(strftime('%H', s.date_time) AS INTEGER) AS hour,
        sl.name_snapshot,
        SUM(sl.quantity) AS total_quantity
      FROM sale_lines sl
      JOIN sales s ON s.id = sl.sale_id
      WHERE s.business_day_id = ?
        AND CAST(strftime('%H', s.date_time) AS INTEGER) BETWEEN 9 AND 18
      GROUP BY hour, sl.name_snapshot
      ORDER BY hour ASC, sl.name_snapshot ASC
    ''',
      [businessDayId],
    );
  }

  /// Merges a sale received from a second device into the control's SQLite.
  /// Returns 1 if the sale was inserted, 0 if it was a duplicate.
  /// Deduplication is based on [deviceToken] + [localId].
  Future<int> mergeReceivedSale({
    required int businessDayId,
    required String deviceToken,
    required int localId,
    required String dateTime,
    required double total,
    required List<Map<String, dynamic>> lines,
  }) async {
    final db = await _dbHelper.database;

    final existing = await db.rawQuery(
      'SELECT id FROM sales WHERE source_device_token = ? AND source_local_id = ?',
      [deviceToken, localId],
    );
    if (existing.isNotEmpty) return 0;

    await db.transaction((txn) async {
      final saleId = await txn.insert('sales', {
        'date_time': dateTime,
        'total': total,
        'business_day_id': businessDayId,
        'source_device_token': deviceToken,
        'source_local_id': localId,
      });
      for (final line in lines) {
        final price = (line['price_snapshot'] as num).toDouble();
        final qty = line['quantity'] as int;
        await txn.insert('sale_lines', {
          'sale_id': saleId,
          'product_id': null,
          'name_snapshot': line['name_snapshot'],
          'price_snapshot': price,
          'quantity': qty,
          'subtotal': price * qty,
        });
      }
      await txn.rawUpdate(
        'UPDATE business_days'
        ' SET total_revenue = total_revenue + ?,'
        '     sale_count    = sale_count + 1'
        ' WHERE id = ?',
        [total, businessDayId],
      );
    });
    return 1;
  }

  /// Returns all business days ordered by date descending (most recent first).
  Future<List<BusinessDay>> getAllBusinessDays() async {
    final db = await _dbHelper.database;
    final rows = await db.query('business_days', orderBy: 'date DESC');
    return rows.map(BusinessDay.fromMap).toList();
  }
}
