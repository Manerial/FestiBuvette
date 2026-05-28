import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

@immutable
class CartState {
  final Map<int, int> quantities;
  final double? tenderedAmount;

  const CartState({this.quantities = const {}, this.tenderedAmount});

  bool get isEmpty => quantities.isEmpty;

  double calculateTotal(List<Product> products) {
    return products.fold(0.0, (sum, p) {
      final qty = quantities[p.id] ?? 0;
      return sum + (p.price * qty);
    });
  }

  /// Returns the change to return to the customer, or null if no tendered
  /// amount was entered. Returns null (not negative) when tendered < total;
  /// use [insufficientTendered] to distinguish that case.
  double? change(double total) {
    if (tenderedAmount == null) return null;
    final diff = tenderedAmount! - total;
    return diff >= 0 ? diff : null;
  }

  /// True when a tendered amount is set but is strictly less than the total.
  bool insufficientTendered(double total) =>
      tenderedAmount != null && tenderedAmount! < total;
}

/// Cart state: quantities map + optional tendered amount.
/// State is never persisted — fully reset after a sale is recorded.
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void increment(int productId) {
    final updated = Map<int, int>.from(state.quantities)
      ..[productId] = (state.quantities[productId] ?? 0) + 1;
    state = CartState(quantities: updated, tenderedAmount: state.tenderedAmount);
  }

  void decrement(int productId) {
    final current = state.quantities[productId] ?? 0;
    if (current <= 0) return;
    final updated = Map<int, int>.from(state.quantities);
    if (current == 1) {
      updated.remove(productId);
    } else {
      updated[productId] = current - 1;
    }
    state = CartState(quantities: updated, tenderedAmount: state.tenderedAmount);
  }

  /// Clears quantities and tendered amount.
  void clear() => state = const CartState();

  void setTenderedAmount(double? amount) =>
      state = CartState(quantities: state.quantities, tenderedAmount: amount);

  int quantity(int productId) => state.quantities[productId] ?? 0;

  bool get isEmpty => state.isEmpty;

  double calculateTotal(List<Product> products) => state.calculateTotal(products);
}
