import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/products/data/models/category.dart';
import 'package:festi_buvette_app/features/products/data/repositories/categories_repository.dart';

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  late final CategoriesRepository _repo;

  @override
  Future<List<Category>> build() async {
    _repo = CategoriesRepository(DatabaseHelper.instance);
    return _repo.getAll();
  }

  Future<void> add(String name) async {
    final order = await _repo.nextOrder();
    final category = Category(name: name, order: order);
    await _repo.insert(category);
    state = AsyncData(await _repo.getAll());
  }

  /// Updates the name of an existing category.
  /// Named [edit] to avoid conflict with AsyncNotifierBase.update.
  Future<void> edit(Category category) async {
    await _repo.update(category);
    state = AsyncData(await _repo.getAll());
  }

  /// Reorders the list after drag & drop and persists the new order.
  /// Uses [onReorderItem] from Flutter 3.41+: [newIndex] is already adjusted.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final categories = List<Category>.from(state.valueOrNull ?? []);
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);
    // Optimistic update → the list reacts immediately.
    state = AsyncData(categories);
    // Persist in background.
    await _repo.updateOrders(categories);
  }

  /// Deletes a category. Products in it become uncategorized.
  Future<void> delete(int id) async {
    await _repo.delete(id);
    state = AsyncData(await _repo.getAll());
  }
}
