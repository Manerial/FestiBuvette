import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/features/products/data/models/category.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/presentation/widgets/category_filter_bar.dart';
import 'package:ludo_pay_app/features/products/presentation/widgets/category_form_dialog.dart';
import 'package:ludo_pay_app/features/products/presentation/widgets/product_form_dialog.dart';
import 'package:ludo_pay_app/features/products/providers/categories_provider.dart';
import 'package:ludo_pay_app/features/products/providers/products_provider.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    // If the selected category was deleted, fall back to "All".
    final effectiveCategoryId =
        categories.any((c) => c.id == _selectedCategoryId)
            ? _selectedCategoryId
            : null;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e))),
      data: (products) {
        final filtered = effectiveCategoryId == null
            ? products
            : products
                .where((p) => p.categoryId == effectiveCategoryId)
                .toList();

        return Column(
          children: [
            CategoryFilterBar(
              categories: categories,
              selectedCategoryId: effectiveCategoryId,
              onSelect: (id) => setState(() => _selectedCategoryId = id),
              showManageButton: true,
              onManage: () => _showManageCategories(context),
            ),
            Expanded(
              child: Stack(
                children: [
                  if (products.isEmpty)
                    _EmptyState(ref: ref)
                  else if (filtered.isEmpty)
                    const _EmptyCategoryState()
                  else
                    _ProductList(products: filtered, ref: ref),
                  Positioned(
                    bottom: 24,
                    right: 16,
                    child: FloatingActionButton(
                      heroTag: 'fab_products',
                      tooltip: l10n.addProductTooltip,
                      onPressed: () => showProductFormDialog(
                        context,
                        defaultCategoryId: effectiveCategoryId,
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showManageCategories(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CategoryManagementSheet(),
    );
  }
}

// ─── Category management bottom sheet ────────────────────────────────────────

class _CategoryManagementSheet extends ConsumerWidget {
  const _CategoryManagementSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.manageCategories,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.add),
                  onPressed: () => showCategoryFormDialog(context, ref),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.noCategoriesYet,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                itemBuilder: (_, i) => _CategoryTile(category: categories[i]),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Category tile ────────────────────────────────────────────────────────────

class _CategoryTile extends ConsumerWidget {
  final Category category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                showCategoryFormDialog(context, ref, category: category),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
            onPressed: () => _confirmDelete(context, ref, l10n),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCategoryTitle),
        content: Text(l10n.deleteCategoryMessage),
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
    if (confirmed == true) {
      await ref.read(categoriesProvider.notifier).delete(category.id!);
    }
  }
}

// ─── Reorderable list ─────────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  final List<Product> products;
  final WidgetRef ref;

  const _ProductList({required this.products, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
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

// ─── Product tile ─────────────────────────────────────────────────────────────

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
        onTap: () => showProductFormDialog(context, product: product),
      ),
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

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

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list_off, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            l10n.noProductsInCategory,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
