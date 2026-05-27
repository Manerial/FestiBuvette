import 'package:intl/intl.dart';
import 'package:ludo_pay_app/core/database/database_helper.dart';
import 'package:ludo_pay_app/features/sales/data/models/business_day.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale_line.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper;

  SalesRepository(this._dbHelper);

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  // ─── Business Days ──────────────────────────────────────────────────────────

  /// Returns today's business day, creating it if it doesn't exist.
  Future<BusinessDay> getOrCreateToday() async {
    final db = await _dbHelper.database;
    final today = _dateFmt.format(DateTime.now());

    final rows = await db.query(
      'business_days',
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );

    if (rows.isNotEmpty) return BusinessDay.fromMap(rows.first);

    final id = await db.insert('business_days', {
      'date': today,
      'total_revenue': 0.0,
      'sale_count': 0,
      'closed_at': null,
    });

    return BusinessDay(id: id, date: today, totalRevenue: 0, saleCount: 0);
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

  // ─── Sales ─────────────────────────────────────────────────────────────────

  /// Inserts a sale AND its lines in an atomic transaction.
  /// Returns the created sale with its id.
  Future<Sale> insertSaleWithLines({
    required Sale sale,
    required List<SaleLine> lines,
  }) async {
    final db = await _dbHelper.database;

    late int saleId;
    await db.transaction((txn) async {
      saleId = await txn.insert('sales', sale.toMap());
      for (final line in lines) {
        final lineWithSaleId = SaleLine(
          saleId: saleId,
          productId: line.productId,
          nameSnapshot: line.nameSnapshot,
          priceSnapshot: line.priceSnapshot,
          quantity: line.quantity,
          subtotal: line.subtotal,
        );
        await txn.insert('sale_lines', lineWithSaleId.toMap());
      }
    });

    return Sale.fromMap(
      {...sale.toMap(), 'id': saleId},
      lines: lines,
    );
  }

  /// Returns all sales for a business day (without their lines).
  Future<List<Sale>> getSalesByDay(int businessDayId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sales',
      where: 'business_day_id = ?',
      whereArgs: [businessDayId],
      orderBy: 'date_time ASC',
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
      int businessDayId) async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
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
    ''', [businessDayId]);
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
        .map((s) => Sale.fromMap(
              s.toMap(),
              lines: linesBySaleId[s.id!] ?? const [],
            ))
        .toList();
  }

  /// Deletes a sale and its lines in an atomic transaction, then updates
  /// the parent business day aggregates accordingly.
  Future<void> deleteSale(Sale sale) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('sale_lines', where: 'sale_id = ?', whereArgs: [sale.id]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [sale.id]);
    });

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS rev, COUNT(*) AS cnt FROM sales WHERE business_day_id = ?',
      [sale.businessDayId],
    );
    final rev = (rows.first['rev'] as num).toDouble();
    final cnt = rows.first['cnt'] as int;
    await updateBusinessDay(sale.businessDayId, totalRevenue: rev, saleCount: cnt);
  }

  /// Returns hourly sales per product for a given business day.
  /// Each row: { hour (int 9–18), name_snapshot, total_quantity }.
  /// Hours outside 9–18 are excluded.
  Future<List<Map<String, dynamic>>> getHourlySalesByProduct(
      int businessDayId) async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
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
    ''', [businessDayId]);
  }

  /// Returns all business days ordered by date descending (most recent first).
  Future<List<BusinessDay>> getAllBusinessDays() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'business_days',
      orderBy: 'date DESC',
    );
    return rows.map(BusinessDay.fromMap).toList();
  }
}
