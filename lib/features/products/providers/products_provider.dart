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
  Future<void> add(String name, double price, {int? categoryId}) async {
    final order = await _repo.nextOrder();
    final product = Product(
      name: name,
      price: price,
      order: order,
      categoryId: categoryId,
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
  ///
  /// [visibleProducts] is the list actually shown in the UI (may be a filtered
  /// subset of the full catalogue).  When a category filter is active the
  /// indices [oldIndex]/[newIndex] refer to positions inside that subset, so
  /// the method redistributes only those slots in the complete list while
  /// leaving non-visible products in place.
  Future<void> reorder(
    int oldIndex,
    int newIndex, {
    required List<Product> visibleProducts,
  }) async {
    // Apply the move inside the visible slice.
    final newVisible = List<Product>.from(visibleProducts);
    final moved = newVisible.removeAt(oldIndex);
    newVisible.insert(newIndex, moved);

    final allProducts = List<Product>.from(state.valueOrNull ?? []);

    if (newVisible.length == allProducts.length) {
      // No filter active — newVisible IS the full list.
      state = AsyncData(newVisible);
      await _repo.updateOrders(newVisible);
    } else {
      // Filter active: replace each "slot" that belonged to a visible product
      // with the next item from the reordered visible list, preserving the
      // relative positions of non-visible products.
      final visibleIds = {for (final p in visibleProducts) p.id};
      int vi = 0;
      final newAll = allProducts.map((p) {
        if (visibleIds.contains(p.id)) return newVisible[vi++];
        return p;
      }).toList();

      // Optimistic update → UI does not "jump".
      state = AsyncData(newAll);
      await _repo.updateOrders(newAll);
    }
  }

  /// Deletes (physically or logically) a product.
  Future<void> delete(int id) async {
    await _repo.softDelete(id);
    state = AsyncData(await _repo.getAllActive());
  }
}
