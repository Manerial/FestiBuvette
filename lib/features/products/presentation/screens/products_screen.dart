import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/providers/products_provider.dart';
import 'package:ludo_pay_app/features/products/presentation/widgets/product_form_dialog.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e))),
      data: (products) => Stack(
        children: [
          products.isEmpty
              ? _EmptyState(ref: ref)
              : _ProductList(products: products, ref: ref),
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'fab_products',
              tooltip: l10n.addProductTooltip,
              onPressed: () => showProductFormDialog(context, ref),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reorderable list ────────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  final List<Product> products;
  final WidgetRef ref;

  const _ProductList({required this.products, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 88), // space for FAB
      itemCount: products.length,
      onReorderItem: (oldIndex, newIndex) =>
          ref.read(productsProvider.notifier).reorder(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductTile(
          key: ValueKey(product.id),
          product: product,
          index: index,
          ref: ref,
        );
      },
    );
  }
}

// ─── Product tile ────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final int index;
  final WidgetRef ref;

  const _ProductTile({
    super.key,
    required this.product,
    required this.index,
    required this.ref,
  });

  static final _priceFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  Future<bool?> _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteProductTitle),
        content: Text(l10n.deleteProductMessage(product.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(product.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          ref.read(productsProvider.notifier).delete(product.id!),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(_priceFmt.format(product.price)),
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: Colors.grey),
        ),
        onTap: () => showProductFormDialog(context, ref, product: product),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final WidgetRef ref;

  const _EmptyState({required this.ref});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            l10n.noProducts,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tapPlusToAddProduct,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
