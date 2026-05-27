import 'package:ludo_pay_app/core/database/database_helper.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale_line.dart';
import 'package:ludo_pay_app/features/sales/data/repositories/sales_repository.dart';

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

    // 3. Get / create today's business day
    final businessDay = await _repo.getOrCreateToday();

    // 3b. Reopen the day automatically if it was closed
    if (businessDay.isClosed) {
      await _repo.reopenBusinessDay(businessDay.id!);
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

    // 5. Insert (atomic transaction)
    final createdSale = await _repo.insertSaleWithLines(
      sale: sale,
      lines: lines,
    );

    // 6. Update business day aggregates
    await _repo.updateBusinessDay(
      businessDay.id!,
      totalRevenue: businessDay.totalRevenue + total,
      saleCount: businessDay.saleCount + 1,
    );

    return createdSale;
  }
}
