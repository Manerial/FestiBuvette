import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:festi_buvette_app/features/products/data/models/category.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';

/// Builds ESC/POS byte sequences for the 58mm NETUM NT-1809DD thermal printer.
class TicketService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  // ─── Private helpers ───────────────────────────────────────────────────────

  static List<int> _productLine(Generator gen, String name, int qty) =>
      gen.row([
        PosColumn(
          text: name,
          width: 9,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: 'X$qty',
          width: 3,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

  static List<int> _categoryHeader(Generator gen, String label) => gen.text(
        '** ${label.toUpperCase()} **',
        styles: const PosStyles(bold: true),
        linesAfter: 1,
      );

  // ─── Core renderer ─────────────────────────────────────────────────────────

  /// Shared renderer. Each [line] carries the name, qty, and optional
  /// categoryId used for grouping when [categories] is non-empty.
  Future<List<int>> _buildTicket({
    required String businessName,
    required DateTime dateTime,
    required List<({String name, int qty, int? categoryId})> lines,
    List<Category> categories = const [],
    required String otherCategoryLabel,
    required String thankYouLabel,
  }) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    // ── Header ────────────────────────────────────────────────────────────
    bytes.addAll(gen.text(
      businessName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    ));
    bytes.addAll(gen.text(
      _dateFmt.format(dateTime),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.text(
      _timeFmt.format(dateTime),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.hr());

    // ── Lines ─────────────────────────────────────────────────────────────
    if (categories.isEmpty) {
      for (final line in lines) {
        bytes.addAll(_productLine(gen, line.name, line.qty));
        bytes.addAll(gen.emptyLines(1));
      }
    } else {
      for (final category in categories) {
        final group = lines.where((l) => l.categoryId == category.id).toList();
        if (group.isEmpty) continue;
        bytes.addAll(_categoryHeader(gen, category.name));
        for (final line in group) {
          bytes.addAll(_productLine(gen, line.name, line.qty));
          bytes.addAll(gen.emptyLines(1));
        }
      }
      final uncategorized = lines.where((l) => l.categoryId == null).toList();
      if (uncategorized.isNotEmpty) {
        bytes.addAll(_categoryHeader(gen, otherCategoryLabel));
        for (final line in uncategorized) {
          bytes.addAll(_productLine(gen, line.name, line.qty));
          bytes.addAll(gen.emptyLines(1));
        }
      }
    }

    // ── Footer ────────────────────────────────────────────────────────────
    bytes.addAll(gen.hr());
    bytes.addAll(gen.text(
      thankYouLabel,
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.feed(3));
    bytes.addAll(gen.cut());

    return bytes;
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Builds an order ticket from the current cart contents.
  Future<List<int>> buildReceiptFromCart({
    required String businessName,
    required DateTime dateTime,
    required List<Product> products,
    required Map<int, int> quantities,
    List<Category> categories = const [],
    required String otherCategoryLabel,
    required String thankYouLabel,
  }) =>
      _buildTicket(
        businessName: businessName,
        dateTime: dateTime,
        lines: products
            .where((p) => (quantities[p.id] ?? 0) > 0)
            .map((p) => (
                  name: p.name,
                  qty: quantities[p.id]!,
                  categoryId: p.categoryId,
                ))
            .toList(),
        categories: categories,
        otherCategoryLabel: otherCategoryLabel,
        thankYouLabel: thankYouLabel,
      );

  /// Builds an order ticket from a previously recorded [Sale] (uses snapshots).
  /// Printed flat — category info is not snapshotted in sale lines.
  Future<List<int>> buildReceiptFromSale({
    required String businessName,
    required Sale sale,
    required String thankYouLabel,
  }) =>
      _buildTicket(
        businessName: businessName,
        dateTime: DateTime.parse(sale.dateTime),
        lines: sale.lines
            .map((l) => (
                  name: l.nameSnapshot,
                  qty: l.quantity,
                  categoryId: null as int?,
                ))
            .toList(),
        otherCategoryLabel: '',
        thankYouLabel: thankYouLabel,
      );

  // ─── Test page ─────────────────────────────────────────────────────────────

  /// Builds a short test page to verify printer connectivity.
  Future<List<int>> buildTestPage(String businessName) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    final now = DateTime.now();

    bytes.addAll(gen.text(
      '=== TEST ===',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(gen.emptyLines(1));
    bytes.addAll(gen.text(
      businessName,
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.text(
      '${_dateFmt.format(now)} ${_timeFmt.format(now)}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.emptyLines(1));
    bytes.addAll(gen.text(
      'Imprimante OK',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.feed(3));
    bytes.addAll(gen.cut());

    return bytes;
  }
}
