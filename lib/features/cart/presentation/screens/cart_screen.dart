import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';
import 'package:ludo_pay_app/features/cart/providers/cart_provider.dart';
import 'package:ludo_pay_app/features/printer/data/services/ticket_service.dart';
import 'package:ludo_pay_app/features/printer/providers/printer_provider.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/providers/products_provider.dart';
import 'package:ludo_pay_app/features/sales/services/sale_service.dart';
import 'package:ludo_pay_app/features/settings/providers/settings_provider.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e))),
      data: (products) => products.isEmpty
          ? const _EmptyCatalog()
          : _CartContent(products: products),
    );
  }
}

// ─── Main content ─────────────────────────────────────────────────────────────

class _CartContent extends ConsumerWidget {
  final List<Product> products;
  const _CartContent({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantities = ref.watch(cartProvider);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) => _ProductRow(
              product: products[index],
              quantity: quantities[products[index].id] ?? 0,
            ),
          ),
        ),
        _Footer(products: products, quantities: quantities),
      ],
    );
  }
}

// ─── Product row ──────────────────────────────────────────────────────────────

class _ProductRow extends ConsumerWidget {
  final Product product;
  final int quantity;

  const _ProductRow({required this.product, required this.quantity});

  static final _priceFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final inCart = quantity > 0;

    return ListTile(
      title: Text(
        product.name,
        style: TextStyle(
          fontWeight: inCart ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(_priceFmt.format(product.price)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: inCart ? () => notifier.decrement(product.id!) : null,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: inCart ? FontWeight.bold : FontWeight.normal,
                color: inCart
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => notifier.increment(product.id!),
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends ConsumerWidget {
  final List<Product> products;
  final Map<int, int> quantities;

  const _Footer({required this.products, required this.quantities});

  static final _totalFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  // ── Record sale (shared by print+record and record-only flows) ────────────

  Future<void> _recordSale(BuildContext context, WidgetRef ref) async {
    await SaleService().record(products: products, quantities: quantities);
    ref.read(cartProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.saleRecorded),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Print + record (main flow) ────────────────────────────────────────────

  Future<void> _printAndRecord(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final cartNotifier = ref.read(cartProvider.notifier);
    if (cartNotifier.isEmpty) return;

    final printerState = ref.read(printerProvider).valueOrNull;

    // ── No printer connected → dialog ──────────────────────────────────────
    if (printerState == null || !printerState.isConnected) {
      if (!context.mounted) return;
      final recordOnly = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.printerNotConnectedTitle),
          content: Text(l10n.printerNotConnectedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.printerRecordWithoutPrinting),
            ),
          ],
        ),
      );
      if (recordOnly == true && context.mounted) {
        try {
          await _recordSale(context, ref);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.errorMessage(e)),
              backgroundColor: Colors.red,
            ));
          }
        }
      }
      return;
    }

    // ── Printer connected → print then record ──────────────────────────────
    try {
      final businessName = ref.read(settingsProvider).valueOrNull?.appName ??
          AppConstants.appName;
      final bytes = await TicketService().buildReceiptFromCart(
        businessName: businessName,
        dateTime: DateTime.now(),
        products: products,
        quantities: quantities,
      );

      final printed =
          await ref.read(printerProvider.notifier).printBytes(bytes);

      if (!printed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.printerPrintError),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      if (context.mounted) await _recordSale(context, ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.errorMessage(e)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Clear cart with confirmation ──────────────────────────────────────────

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearCartTitle),
        content: Text(l10n.clearCartMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final total = ref.read(cartProvider.notifier).calculateTotal(products);
    final empty = ref.watch(cartProvider).isEmpty;
    final isPrinting =
        ref.watch(printerProvider).valueOrNull?.isPrinting ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.total,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                  ),
                  Text(
                    _totalFmt.format(total),
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.clear),
                      onPressed: empty || isPrinting
                          ? null
                          : () => _confirmClear(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(l10n.print),
                      onPressed: empty || isPrinting
                          ? null
                          : () => _printAndRecord(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty catalogue ──────────────────────────────────────────────────────────

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            l10n.noProductsInCatalogue,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addProductsFromTab,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
