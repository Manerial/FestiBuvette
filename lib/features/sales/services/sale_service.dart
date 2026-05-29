import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/core/services/device_id_service.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale_line.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';

class SaleService {
  final SalesRepository _repo;

  SaleService() : _repo = SalesRepository(DatabaseHelper.instance);

  /// Constructor for unit tests — injects a [SalesRepository] directly.
  SaleService.withRepository(this._repo);

  /// Records a complete sale to the database.
  ///
  /// [products] : full catalogue of active products.
  /// [quantities] : map productId → quantity (only quantities > 0 are processed).
  ///
  /// Returns the created sale.
  /// Throws an [Exception] if the cart is empty.
  Future<Sale> record({
    required List<Product> products,
    required Map<int, int> quantities,
  }) async {
    // 1. Filter non-zero lines
    final lineData = products
        .where((p) => (quantities[p.id] ?? 0) > 0)
        .map((p) {
          final qty = quantities[p.id]!;
          return (product: p, quantity: qty);
        })
        .toList();

    if (lineData.isEmpty) {
      throw Exception('Cart is empty.');
    }

    // 2. Calculate total
    final total = lineData.fold<double>(
      0.0,
      (sum, e) => sum + (e.product.price * e.quantity),
    );

    // 3. Get today's business day — throw if not started or closed
    final businessDay = await _repo.getToday();
    if (businessDay == null) {
      throw Exception('No active business day. Start the day first.');
    }
    if (businessDay.isClosed) {
      throw Exception('Business day is closed.');
    }

    // 4. Build objects
    final now = DateTime.now().toIso8601String();
    final sale = Sale(
      dateTime: now,
      total: total,
      businessDayId: businessDay.id!,
    );

    final lines = lineData
        .map((e) => SaleLine(
              saleId: 0, // replaced by repository
              productId: e.product.id!,
              nameSnapshot: e.product.name,
              priceSnapshot: e.product.price,
              quantity: e.quantity,
              subtotal: e.product.price * e.quantity,
            ))
        .toList();

    // 5. Insert (atomic transaction) — tag with device UUID so the sale can be
    //    pushed and deduplicated across the fleet via (device_uuid, local_id).
    final deviceId = await DeviceIdService.get();
    final createdSale = await _repo.insertSaleWithLines(
      sale: sale,
      lines: lines,
      deviceId: deviceId,
    );

    // 6. Update business day aggregates (atomic increment — safe on double-tap)
    await _repo.incrementBusinessDay(businessDay.id!, total);

    return createdSale;
  }
}
