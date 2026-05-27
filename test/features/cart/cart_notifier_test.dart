import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_pay_app/features/cart/providers/cart_provider.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';

void main() {
  // ─── Helpers ───────────────────────────────────────────────────────────────

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  Product product(int id, double price) => Product(
        id: id,
        name: 'Product $id',
        price: price,
        order: 0,
        createdAt: '2026-01-01T00:00:00.000',
      );

  // ─── Initial state ─────────────────────────────────────────────────────────

  test('initial state is empty with no tendered amount', () {
    final container = makeContainer();
    final state = container.read(cartProvider);
    expect(state.quantities, isEmpty);
    expect(state.isEmpty, isTrue);
    expect(state.tenderedAmount, isNull);
  });

  // ─── increment ─────────────────────────────────────────────────────────────

  test('increment adds product with quantity 1', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    expect(container.read(cartProvider).quantities, {1: 1});
  });

  test('increment called twice reaches quantity 2', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(1);
    expect(container.read(cartProvider).quantities, {1: 2});
  });

  test('increment on two different products creates two entries', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(2);
    expect(container.read(cartProvider).quantities, {1: 1, 2: 1});
  });

  test('increment preserves tenderedAmount', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).setTenderedAmount(10.0);
    container.read(cartProvider.notifier).increment(1);
    expect(container.read(cartProvider).tenderedAmount, 10.0);
  });

  // ─── decrement ─────────────────────────────────────────────────────────────

  test('decrement reduces quantity by 1', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).decrement(1);
    expect(container.read(cartProvider).quantities, {1: 1});
  });

  test('decrement removes product when quantity reaches zero', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).decrement(1);
    expect(container.read(cartProvider).quantities, isEmpty);
  });

  test('decrement is a no-op when product is not in cart', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).decrement(99);
    expect(container.read(cartProvider).quantities, isEmpty);
  });

  test('decrement preserves tenderedAmount', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).setTenderedAmount(5.0);
    container.read(cartProvider.notifier).decrement(1);
    expect(container.read(cartProvider).tenderedAmount, 5.0);
  });

  // ─── clear ─────────────────────────────────────────────────────────────────

  test('clear empties the cart', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(2);
    container.read(cartProvider.notifier).clear();
    expect(container.read(cartProvider).quantities, isEmpty);
  });

  test('clear also resets tenderedAmount', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).setTenderedAmount(20.0);
    container.read(cartProvider.notifier).clear();
    expect(container.read(cartProvider).tenderedAmount, isNull);
  });

  // ─── isEmpty / quantity ────────────────────────────────────────────────────

  test('isEmpty is true on empty cart and false after increment', () {
    final container = makeContainer();
    expect(container.read(cartProvider.notifier).isEmpty, isTrue);
    container.read(cartProvider.notifier).increment(1);
    expect(container.read(cartProvider.notifier).isEmpty, isFalse);
  });

  test('quantity returns 0 for unknown product', () {
    final container = makeContainer();
    expect(container.read(cartProvider.notifier).quantity(42), 0);
  });

  test('quantity returns current quantity for known product', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(1);
    expect(container.read(cartProvider.notifier).quantity(1), 2);
  });

  // ─── calculateTotal ────────────────────────────────────────────────────────

  test('calculateTotal returns 0 for empty cart', () {
    final container = makeContainer();
    final products = [product(1, 2.5), product(2, 1.0)];
    expect(container.read(cartProvider.notifier).calculateTotal(products), 0.0);
  });

  test('calculateTotal computes correct total', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1); // 2.5 × 1
    container.read(cartProvider.notifier).increment(1); // 2.5 × 2
    container.read(cartProvider.notifier).increment(2); // 1.0 × 1

    final products = [product(1, 2.5), product(2, 1.0)];
    final total = container.read(cartProvider.notifier).calculateTotal(products);

    expect(total, closeTo(6.0, 0.001)); // 2.5*2 + 1.0*1
  });

  test('calculateTotal ignores products not in cart', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);

    // Product 2 is in catalogue but not in cart
    final products = [product(1, 2.5), product(2, 5.0)];
    expect(
      container.read(cartProvider.notifier).calculateTotal(products),
      closeTo(2.5, 0.001),
    );
  });

  // ─── setTenderedAmount ─────────────────────────────────────────────────────

  test('setTenderedAmount updates tenderedAmount', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).setTenderedAmount(10.0);
    expect(container.read(cartProvider).tenderedAmount, 10.0);
  });

  test('setTenderedAmount(null) clears tenderedAmount', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).setTenderedAmount(10.0);
    container.read(cartProvider.notifier).setTenderedAmount(null);
    expect(container.read(cartProvider).tenderedAmount, isNull);
  });

  test('setTenderedAmount preserves quantities', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(2);
    container.read(cartProvider.notifier).setTenderedAmount(5.0);
    expect(container.read(cartProvider).quantities, {1: 1, 2: 1});
  });

  // ─── CartState.change ──────────────────────────────────────────────────────

  test('change returns null when no tendered amount', () {
    const state = CartState();
    expect(state.change(5.0), isNull);
  });

  test('change returns correct value when tendered > total', () {
    const state = CartState(tenderedAmount: 10.0);
    expect(state.change(7.5), closeTo(2.5, 0.001));
  });

  test('change returns 0 when tendered equals total exactly', () {
    const state = CartState(tenderedAmount: 5.0);
    expect(state.change(5.0), closeTo(0.0, 0.001));
  });

  test('change returns null when tendered < total', () {
    const state = CartState(tenderedAmount: 3.0);
    expect(state.change(5.0), isNull);
  });

  // ─── CartState.insufficientTendered ───────────────────────────────────────

  test('insufficientTendered is false when no tendered amount', () {
    const state = CartState();
    expect(state.insufficientTendered(5.0), isFalse);
  });

  test('insufficientTendered is true when tendered < total', () {
    const state = CartState(tenderedAmount: 3.0);
    expect(state.insufficientTendered(5.0), isTrue);
  });

  test('insufficientTendered is false when tendered equals total', () {
    const state = CartState(tenderedAmount: 5.0);
    expect(state.insufficientTendered(5.0), isFalse);
  });

  test('insufficientTendered is false when tendered > total', () {
    const state = CartState(tenderedAmount: 10.0);
    expect(state.insufficientTendered(5.0), isFalse);
  });
}
