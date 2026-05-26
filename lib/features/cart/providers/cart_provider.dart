import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';

final cartProvider =
    NotifierProvider<CartNotifier, Map<int, int>>(CartNotifier.new);

/// Cart state: map productId → quantity.
/// Only products with qty > 0 are present in the map.
/// State is never persisted — reset to zero after printing.
class CartNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => {};

  void increment(int productId) {
    state = {...state, productId: (state[productId] ?? 0) + 1};
  }

  void decrement(int productId) {
    final current = state[productId] ?? 0;
    if (current <= 0) return;
    if (current == 1) {
      final updated = Map<int, int>.from(state)..remove(productId);
      state = updated;
    } else {
      state = {...state, productId: current - 1};
    }
  }

  void clear() => state = {};

  int quantity(int productId) => state[productId] ?? 0;

  bool get isEmpty => state.isEmpty;

  /// Calculates the cart total from the product catalogue.
  double calculateTotal(List<Product> products) {
    return products.fold(0.0, (sum, p) {
      final qty = state[p.id] ?? 0;
      return sum + (p.price * qty);
    });
  }
}
