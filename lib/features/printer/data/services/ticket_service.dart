import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale.dart';

/// Builds ESC/POS byte sequences for the 58mm NETUM NT-1809DD thermal printer.
class TicketService {
  // ESC/POS encoding is Latin-1: the '€' symbol (U+20AC) is outside that range.
  // Use a plain decimal format and append 'EUR' as a plain ASCII suffix.
  static final _decimalFmt = NumberFormat('#,##0.00', 'fr_FR');

  static String _price(double amount) => '${_decimalFmt.format(amount)} EUR';

  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  // ─── Receipt ───────────────────────────────────────────────────────────────

  /// Builds a full sale receipt from the cart contents.
  Future<List<int>> buildReceiptFromCart({
    required String businessName,
    required DateTime dateTime,
    required List<Product> products,
    required Map<int, int> quantities,
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

    // ── Product lines ─────────────────────────────────────────────────────
    double total = 0;
    for (final product in products) {
      final qty = quantities[product.id] ?? 0;
      if (qty == 0) continue;
      final lineTotal = product.price * qty;
      total += lineTotal;

      bytes.addAll(gen.row([
        PosColumn(
          text: '${qty}x ${product.name}',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _price(lineTotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    // ── Total ─────────────────────────────────────────────────────────────
    bytes.addAll(gen.hr());
    bytes.addAll(gen.row([
      PosColumn(
        text: 'TOTAL',
        width: 7,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: _price(total),
        width: 5,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));
    bytes.addAll(gen.emptyLines(1));

    // ── Footer ────────────────────────────────────────────────────────────
    bytes.addAll(gen.text(
      'Merci !',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.feed(3));
    bytes.addAll(gen.cut());

    return bytes;
  }

  // ─── Reprint from sale ─────────────────────────────────────────────────────

  /// Builds a receipt from a previously recorded [Sale] (uses snapshots).
  Future<List<int>> buildReceiptFromSale({
    required String businessName,
    required Sale sale,
  }) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    final dateTime = DateTime.parse(sale.dateTime);

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

    // ── Sale lines ────────────────────────────────────────────────────────
    for (final line in sale.lines) {
      bytes.addAll(gen.row([
        PosColumn(
          text: '${line.quantity}x ${line.nameSnapshot}',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _price(line.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    // ── Total ─────────────────────────────────────────────────────────────
    bytes.addAll(gen.hr());
    bytes.addAll(gen.row([
      PosColumn(
        text: 'TOTAL',
        width: 7,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: _price(sale.total),
        width: 5,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));
    bytes.addAll(gen.emptyLines(1));

    // ── Footer ────────────────────────────────────────────────────────────
    bytes.addAll(gen.text(
      'Merci !',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(gen.feed(3));
    bytes.addAll(gen.cut());

    return bytes;
  }

  // ─── Test page ─────────────────────────────────────────────────────────────

  /// Builds a short test page to verify printer connectivity.
  Future<List<int>> buildTestPage(String businessName) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

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
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
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
