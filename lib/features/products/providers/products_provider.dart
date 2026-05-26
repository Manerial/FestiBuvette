import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/core/database/database_helper.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/data/repositories/products_repository.dart';

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  late final ProductsRepository _repo;

  @override
  Future<List<Product>> build() async {
    _repo = ProductsRepository(DatabaseHelper.instance);
    return _repo.getAllActive();
  }

  /// Adds a new product at the end of the list.
  Future<void> add(String name, double price) async {
    final order = await _repo.nextOrder();
    final product = Product(
      name: name,
      price: price,
      order: order,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _repo.insert(product);
    state = AsyncData(await _repo.getAllActive());
  }

  /// Updates the name and/or price of a product.
  /// Named [edit] to avoid conflict with AsyncNotifierBase.update.
  Future<void> edit(Product product) async {
    await _repo.update(product);
    state = AsyncData(await _repo.getAllActive());
  }

  /// Reorders the list after drag & drop and persists the new order.
  /// Uses [onReorderItem] from Flutter 3.41+: [newIndex] is already adjusted.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final products = List<Product>.from(state.valueOrNull ?? []);
    final item = products.removeAt(oldIndex);
    products.insert(newIndex, item);
    // Optimistic update → UI does not "jump"
    state = AsyncData(products);
    // Persist in background
    await _repo.updateOrders(products);
  }

  /// Deletes (physically or logically) a product.
  Future<void> delete(int id) async {
    await _repo.softDelete(id);
    state = AsyncData(await _repo.getAllActive());
  }
}
