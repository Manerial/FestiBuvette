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

  test('initial state is empty', () {
    final container = makeContainer();
    expect(container.read(cartProvider), isEmpty);
  });

  // ─── increment ─────────────────────────────────────────────────────────────

  test('increment adds product with quantity 1', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    expect(container.read(cartProvider), {1: 1});
  });

  test('increment called twice reaches quantity 2', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(1);
    expect(container.read(cartProvider), {1: 2});
  });

  test('increment on two different products creates two entries', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(2);
    expect(container.read(cartProvider), {1: 1, 2: 1});
  });

  // ─── decrement ─────────────────────────────────────────────────────────────

  test('decrement reduces quantity by 1', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).decrement(1);
    expect(container.read(cartProvider), {1: 1});
  });

  test('decrement removes product when quantity reaches zero', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).decrement(1);
    expect(container.read(cartProvider), isEmpty);
  });

  test('decrement is a no-op when product is not in cart', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).decrement(99);
    expect(container.read(cartProvider), isEmpty);
  });

  // ─── clear ─────────────────────────────────────────────────────────────────

  test('clear empties the cart', () {
    final container = makeContainer();
    container.read(cartProvider.notifier).increment(1);
    container.read(cartProvider.notifier).increment(2);
    container.read(cartProvider.notifier).clear();
    expect(container.read(cartProvider), isEmpty);
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
}
