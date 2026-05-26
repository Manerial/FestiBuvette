import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';
import 'package:ludo_pay_app/features/sales/services/sale_service.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/providers/products_provider.dart';
import 'package:ludo_pay_app/features/cart/providers/cart_provider.dart';

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
        // Scrollable product list
        Expanded(
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) => _ProductRow(
              product: products[index],
              quantity: quantities[products[index].id] ?? 0,
            ),
          ),
        ),
        // Fixed footer: total + buttons
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
          // Minus button
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: inCart ? () => notifier.decrement(product.id!) : null,
            color: Theme.of(context).colorScheme.primary,
          ),
          // Quantity
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
          // Plus button
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

  Future<void> _print(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cartProvider.notifier);
    if (notifier.isEmpty) return;

    try {
      await SaleService().record(
        products: products,
        quantities: quantities,
      );
      notifier.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.saleRecorded),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                  // Clear
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.clear),
                      onPressed:
                          empty ? null : () => _confirmClear(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Print
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.print_outlined),
                      label: Text(l10n.print),
                      onPressed: empty ? null : () => _print(context, ref),
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
