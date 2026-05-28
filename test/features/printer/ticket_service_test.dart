import 'package:flutter_test/flutter_test.dart';
import 'package:festi_buvette_app/features/printer/data/services/ticket_service.dart';
import 'package:festi_buvette_app/features/products/data/models/category.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale_line.dart';

void main() {
  // CapabilityProfile.load() uses rootBundle — requires the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = TicketService();

  // Mirrors the French l10n values used in production.
  const thankYou = 'Merci !';
  const other = 'AUTRES';

  final products = [
    const Product(id: 1, name: 'Café', price: 1.50, order: 0, createdAt: '2025-01-01'),
    const Product(id: 2, name: 'Croissant', price: 1.20, order: 1, createdAt: '2025-01-01'),
  ];

  // ESC/POS bytes contain Latin-1 encoded text — readable via fromCharCodes.
  String decode(List<int> bytes) => String.fromCharCodes(bytes);

  // ─── buildReceiptFromCart ────────────────────────────────────────────────

  test('buildReceiptFromCart returns non-empty bytes', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Mon Café',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 2, 2: 1},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    expect(bytes, isNotEmpty);
  });

  test('buildReceiptFromCart skips products with qty 0', () async {
    final bytesAll = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 1, 2: 1},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final bytesSome = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 1, 2: 0},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    expect(bytesSome.length, lessThan(bytesAll.length));
  });

  test('buildReceiptFromCart with empty cart still returns bytes (header + cut)',
      () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    expect(bytes, isNotEmpty);
  });

  test('buildReceiptFromCart encodes product names', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 2, 2: 1},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, contains('Café'));
    expect(content, contains('Croissant'));
  });

  test('buildReceiptFromCart encodes quantity as "Xn" (not "nx")', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 3, 2: 1},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, contains('X3'));
    expect(content, contains('X1'));
    expect(content, isNot(contains('3x')));
    expect(content, isNot(contains('1x')));
  });

  test('buildReceiptFromCart does not include prices or TOTAL', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 2, 2: 1},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, isNot(contains('EUR')));
    expect(content, isNot(contains('TOTAL')));
  });

  test('buildReceiptFromCart includes footer "Merci !"', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: products,
      quantities: {1: 1},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    expect(decode(bytes), contains(thankYou));
  });

  // ─── buildReceiptFromCart — category grouping ────────────────────────────

  const drinks = Category(id: 1, name: 'Boissons', order: 0);
  const snacks = Category(id: 2, name: 'Snacks', order: 1);

  final mixedProducts = [
    const Product(id: 1, name: 'Bière', price: 2.00, order: 0, createdAt: '2025-01-01', categoryId: 1),
    const Product(id: 2, name: 'Coca', price: 1.50, order: 1, createdAt: '2025-01-01', categoryId: 1),
    const Product(id: 3, name: 'Chips', price: 1.00, order: 2, createdAt: '2025-01-01', categoryId: 2),
    const Product(id: 4, name: 'Sans catégorie', price: 0.50, order: 3, createdAt: '2025-01-01'),
  ];

  test('buildReceiptFromCart groups products under category headers', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: mixedProducts,
      quantities: {1: 2, 2: 1, 3: 3, 4: 1},
      categories: const [drinks, snacks],
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, contains('** BOISSONS **'));
    expect(content, contains('** SNACKS **'));
    expect(content, contains('** AUTRES **'));
  });

  test('buildReceiptFromCart category headers appear in sort_order', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: mixedProducts,
      quantities: {1: 1, 3: 1},
      categories: const [drinks, snacks],
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content.indexOf('** BOISSONS **'), lessThan(content.indexOf('** SNACKS **')));
  });

  test('buildReceiptFromCart skips categories with no items in cart', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: mixedProducts,
      quantities: {1: 1},
      categories: const [drinks, snacks],
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, contains('** BOISSONS **'));
    expect(content, isNot(contains('** SNACKS **')));
  });

  test('buildReceiptFromCart uncategorized products go under otherCategoryLabel', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: mixedProducts,
      quantities: {4: 2},
      categories: const [drinks, snacks],
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, contains('** AUTRES **'));
    expect(content, isNot(contains('** BOISSONS **')));
    expect(content, isNot(contains('** SNACKS **')));
  });

  test('buildReceiptFromCart with no categories prints flat (no headers)', () async {
    final bytes = await service.buildReceiptFromCart(
      businessName: 'Test',
      dateTime: DateTime(2025, 1, 15, 10, 30),
      products: mixedProducts,
      quantities: {1: 1, 3: 1},
      otherCategoryLabel: other,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, isNot(contains('**')));
  });

  // ─── buildReceiptFromSale ────────────────────────────────────────────────

  final sale = Sale(
    id: 42,
    dateTime: '2025-01-15T14:30:00.000',
    total: 4.20,
    businessDayId: 1,
    lines: const [
      SaleLine(
        saleId: 42,
        productId: 1,
        nameSnapshot: 'Bière',
        priceSnapshot: 2.00,
        quantity: 2,
        subtotal: 4.00,
      ),
      SaleLine(
        saleId: 42,
        productId: 2,
        nameSnapshot: 'Chips',
        priceSnapshot: 0.20,
        quantity: 1,
        subtotal: 0.20,
      ),
    ],
  );

  test('buildReceiptFromSale encodes name snapshots', () async {
    final bytes = await service.buildReceiptFromSale(
      businessName: 'Test',
      sale: sale,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, contains('Bière'));
    expect(content, contains('Chips'));
  });

  test('buildReceiptFromSale encodes quantity as "Xn"', () async {
    final bytes = await service.buildReceiptFromSale(
      businessName: 'Test',
      sale: sale,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, contains('X2'));
    expect(content, contains('X1'));
    expect(content, isNot(contains('2x')));
  });

  test('buildReceiptFromSale does not include prices or TOTAL', () async {
    final bytes = await service.buildReceiptFromSale(
      businessName: 'Test',
      sale: sale,
      thankYouLabel: thankYou,
    );
    final content = decode(bytes);
    expect(content, isNot(contains('EUR')));
    expect(content, isNot(contains('TOTAL')));
  });

  test('buildReceiptFromSale includes footer "Merci !"', () async {
    final bytes = await service.buildReceiptFromSale(
      businessName: 'Test',
      sale: sale,
      thankYouLabel: thankYou,
    );
    expect(decode(bytes), contains(thankYou));
  });

  // ─── buildTestPage ───────────────────────────────────────────────────────

  test('buildTestPage returns non-empty bytes', () async {
    final bytes = await service.buildTestPage('FestiBuvette');
    expect(bytes, isNotEmpty);
  });

  test('buildTestPage with different business names returns different bytes',
      () async {
    final bytes1 = await service.buildTestPage('FestiBuvette');
    final bytes2 = await service.buildTestPage('Mon Bistrot');
    expect(bytes1, isNot(equals(bytes2)));
  });
}
