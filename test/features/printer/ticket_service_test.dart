import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_pay_app/features/printer/data/services/ticket_service.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';

void main() {
  // CapabilityProfile.load() uses rootBundle — requires the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = TicketService();

  final products = [
    const Product(id: 1, name: 'Café', price: 1.50, order: 0, createdAt: '2025-01-01'),
    const Product(id: 2, name: 'Croissant', price: 1.20, order: 1, createdAt: '2025-01-01'),
  ];

  // ─── buildReceiptFromCart ────────────────────────────────────────────────

  test('buildReceiptFromCart returns non-empty bytes', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Mon Café',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 2, 2: 1},
    );
    expect(bytes, isNotEmpty);
  });

  test('buildReceiptFromCart skips products with qty 0', () async {
    final bytesAll = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 1, 2: 1},
    );
    final bytesSome = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 1, 2: 0},
    );
    // Receipt with fewer items should be shorter.
    expect(bytesSome.length, lessThan(bytesAll.length));
  });

  test('buildReceiptFromCart with empty cart still returns bytes (header + cut)',
      () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {},
    );
    expect(bytes, isNotEmpty);
  });

  // ─── buildTestPage ───────────────────────────────────────────────────────

  test('buildTestPage returns non-empty bytes', () async {
    final bytes = await service.buildTestPage('LudoPay');
    expect(bytes, isNotEmpty);
  });

  test('buildTestPage with different business names returns different bytes',
      () async {
    final bytes1 = await service.buildTestPage('LudoPay');
    final bytes2 = await service.buildTestPage('Mon Bistrot');
    expect(bytes1, isNot(equals(bytes2)));
  });
}
