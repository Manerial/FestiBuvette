import 'package:festi_buvette_app/features/products/data/models/category.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/products/presentation/widgets/category_filter_bar.dart';
import 'package:festi_buvette_app/features/products/presentation/widgets/category_form_dialog.dart';
import 'package:festi_buvette_app/features/products/presentation/widgets/product_form_dialog.dart';
import 'package:festi_buvette_app/features/products/providers/categories_provider.dart';
import 'package:festi_buvette_app/features/products/providers/products_provider.dart';
import 'package:festi_buvette_app/features/report/providers/report_provider.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  int? _selectedCategoryId;
  bool _showCategories = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final locked = ref.watch(isCatalogLockedProvider);

    // If the selected category was deleted, fall back to "All".
    // The uncategorized sentinel (-1) is always valid.
    final isUncategorized =
        _selectedCategoryId == CategoryFilterBar.uncategorizedId;
    final isCategorized = categories.any((c) => c.id == _selectedCategoryId);
    final effectiveCategoryId = (isUncategorized || isCategorized)
        ? _selectedCategoryId
        : null;

    return Column(
      children: [
        // ── Catalog locked banner ──────────────────────────────────────────
        if (locked) _CatalogLockedBanner(),

        // ── View switcher ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.productsTab)),
              ButtonSegment(value: true, label: Text(l10n.categoriesTabLabel)),
            ],
            selected: {_showCategories},
            onSelectionChanged: (v) =>
                setState(() => _showCategories = v.first),
          ),
        ),
        // ── Active view ────────────────────────────────────────────────────
        Expanded(
          child: _showCategories
              ? _CategoriesSection(locked: locked)
              : _ProductsSection(
                  selectedCategoryId: effectiveCategoryId,
                  onSelect: (id) => setState(() => _selectedCategoryId = id),
                  locked: locked,
                ),
        ),
      ],
    );
  }
}

// ─── Catalog locked banner ────────────────────────────────────────────────────

class _CatalogLockedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: cs.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(
              l10n.catalogLocked,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Products section ─────────────────────────────────────────────────────────

class _ProductsSection extends ConsumerWidget {
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelect;
  final bool locked;

  const _ProductsSection({
    required this.selectedCategoryId,
    required this.onSelect,
    required this.locked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e))),
      data: (products) {
        final hasUncategorized = categories.isNotEmpty;
        final filtered = switch (selectedCategoryId) {
          null => products,
          CategoryFilterBar.uncategorizedId =>
            products.where((p) => p.categoryId == null).toList(),
          _ =>
            products.where((p) => p.categoryId == selectedCategoryId).toList(),
        };

        return Column(
          children: [
            CategoryFilterBar(
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onSelect: onSelect,
              hasUncategorized: hasUncategorized,
            ),
            Expanded(
              child: Stack(
                children: [
                  if (products.isEmpty)
                    _EmptyProductsState(locked: locked)
                  else if (filtered.isEmpty)
                    const _EmptyCategoryState()
                  else
                    _ProductList(products: filtered, locked: locked),
                  if (!locked)
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'fab_products',
                        tooltip: l10n.addProductTooltip,
                        onPressed: () => showProductFormDialog(
                          context,
                          defaultCategoryId:
                              selectedCategoryId ==
                                  CategoryFilterBar.uncategorizedId
                              ? null
                              : selectedCategoryId,
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
}

// ─── Categories section ───────────────────────────────────────────────────────

class _CategoriesSection extends ConsumerWidget {
  final bool locked;

  const _CategoriesSection({required this.locked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Stack(
      children: [
        if (categories.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.label_outline,
                  size: 72,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noCategoriesYet,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                if (!locked)
                  Text(
                    l10n.tapPlusToAddCategory,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: categories.length,
            onReorderItem: (o, n) =>
                ref.read(categoriesProvider.notifier).reorder(o, n),
            itemBuilder: (_, i) => _CategoryTile(
              key: ValueKey(categories[i].id),
              category: categories[i],
              index: i,
              locked: locked,
            ),
          ),
        if (!locked)
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'fab_categories',
              tooltip: l10n.addCategoryTooltip,
              onPressed: () => showCategoryFormDialog(context, ref),
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }
}

// ─── Category tile ────────────────────────────────────────────────────────────

class _CategoryTile extends ConsumerWidget {
  final Category category;
  final int index;
  final bool locked;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.index,
    required this.locked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _ReorderableTile(
      index: index,
      title: category.name,
      deleteDialogTitle: l10n.deleteCategoryTitle,
      deleteDialogMessage: l10n.deleteCategoryMessage,
      onEdit: () => showCategoryFormDialog(context, ref, category: category),
      onDeleteConfirmed: () =>
          ref.read(categoriesProvider.notifier).delete(category.id!),
      locked: locked,
    );
  }
}

// ─── Shared reorderable tile ──────────────────────────────────────────────────

class _ReorderableTile extends StatelessWidget {
  final int index;
  final String title;
  final String? subtitle;
  final String deleteDialogTitle;
  final String deleteDialogMessage;
  final VoidCallback onEdit;
  final VoidCallback onDeleteConfirmed;
  final Widget? leadingTrailingAction;
  final bool locked;

  const _ReorderableTile({
    required this.index,
    required this.title,
    this.subtitle,
    required this.deleteDialogTitle,
    required this.deleteDialogMessage,
    required this.onEdit,
    required this.onDeleteConfirmed,
    this.leadingTrailingAction,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final editDeleteButtons = locked
        ? const <Widget>[]
        : [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () => _handleDelete(context),
            ),
          ];

    final trailingWidgets = [?leadingTrailingAction, ...editDeleteButtons];

    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle, color: Colors.grey),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailingWidgets.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: trailingWidgets),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deleteDialogTitle),
        content: Text(deleteDialogMessage),
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
      onDeleteConfirmed();
    }
  }
}

// ─── Reorderable product list ─────────────────────────────────────────────────

class _ProductList extends ConsumerWidget {
  final List<Product> products;
  final bool locked;

  const _ProductList({required this.products, required this.locked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: products.length,
      onReorderItem: (oldIndex, newIndex) => ref
          .read(productsProvider.notifier)
          .reorder(oldIndex, newIndex, visibleProducts: products),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductTile(
          key: ValueKey(product.id),
          product: product,
          index: index,
          locked: locked,
        );
      },
    );
  }
}

// ─── Product tile ─────────────────────────────────────────────────────────────

class _ProductTile extends ConsumerWidget {
  final Product product;
  final int index;
  final bool locked;

  const _ProductTile({
    super.key,
    required this.product,
    required this.index,
    required this.locked,
  });

  static final _priceFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _ReorderableTile(
      index: index,
      title: product.name,
      subtitle: product.isOutOfStock
          ? '${_priceFmt.format(product.price)} · ${l10n.outOfStock}'
          : _priceFmt.format(product.price),
      deleteDialogTitle: l10n.deleteProductTitle,
      deleteDialogMessage: l10n.deleteProductMessage(product.name),
      onEdit: () => showProductFormDialog(context, product: product),
      onDeleteConfirmed: () =>
          ref.read(productsProvider.notifier).delete(product.id!),
      leadingTrailingAction: IconButton(
        icon: product.isOutOfStock
            ? const Icon(Icons.add_shopping_cart)
            : const Icon(Icons.remove_shopping_cart),
        color: product.isOutOfStock ? Colors.orange : Colors.grey,
        tooltip: product.isOutOfStock
            ? l10n.markAsInStock
            : l10n.markAsOutOfStock,
        onPressed: () =>
            ref.read(productsProvider.notifier).toggleOutOfStock(product.id!),
      ),
      locked: locked,
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _EmptyProductsState extends StatelessWidget {
  final bool locked;

  const _EmptyProductsState({required this.locked});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noProducts,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          if (!locked) ...[
            const SizedBox(height: 8),
            Text(
              l10n.tapPlusToAddProduct,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
