import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';
import 'package:ludo_pay_app/features/cart/providers/cart_provider.dart';
import 'package:ludo_pay_app/features/printer/data/services/ticket_service.dart';
import 'package:ludo_pay_app/features/printer/providers/printer_provider.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/presentation/widgets/category_filter_bar.dart';
import 'package:ludo_pay_app/features/products/providers/categories_provider.dart';
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

class _CartContent extends ConsumerStatefulWidget {
  final List<Product> products;
  const _CartContent({required this.products});

  @override
  ConsumerState<_CartContent> createState() => _CartContentState();
}

class _CartContentState extends ConsumerState<_CartContent> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    // If selected category was deleted, fall back to "All".
    final effectiveCategoryId =
        categories.any((c) => c.id == _selectedCategoryId)
            ? _selectedCategoryId
            : null;

    final filtered = effectiveCategoryId == null
        ? widget.products
        : widget.products
            .where((p) => p.categoryId == effectiveCategoryId)
            .toList();

    return Column(
      children: [
        if (categories.isNotEmpty)
          CategoryFilterBar(
            categories: categories,
            selectedCategoryId: effectiveCategoryId,
            onSelect: (id) => setState(() => _selectedCategoryId = id),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) => _ProductRow(
              product: filtered[index],
              quantity: cartState.quantities[filtered[index].id] ?? 0,
            ),
          ),
        ),
        // Footer always uses all products to compute total correctly,
        // regardless of the active category filter.
        _Footer(products: widget.products, cartState: cartState),
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

class _Footer extends ConsumerStatefulWidget {
  final List<Product> products;
  final CartState cartState;

  const _Footer({required this.products, required this.cartState});

  @override
  ConsumerState<_Footer> createState() => _FooterState();
}

class _FooterState extends ConsumerState<_Footer> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  // ── Record sale (shared by print+record and record-only flows) ────────────

  Future<void> _recordSale(BuildContext context) async {
    await SaleService().record(
      products: widget.products,
      quantities: widget.cartState.quantities,
    );
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

  Future<void> _printAndRecord(BuildContext context) async {
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
          await _recordSale(context);
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
        products: widget.products,
        quantities: widget.cartState.quantities,
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

      if (context.mounted) await _recordSale(context);
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

  Future<void> _confirmClear(BuildContext context) async {
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
  Widget build(BuildContext context) {
    final total = widget.cartState.calculateTotal(widget.products);
    final empty = widget.cartState.isEmpty;
    final isPrinting =
        ref.watch(printerProvider).valueOrNull?.isPrinting ?? false;
    final isInsufficient = widget.cartState.insufficientTendered(total);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300 && !_expanded) setState(() => _expanded = true);
        if (velocity > 300 && _expanded) setState(() => _expanded = false);
      },
      child: Container(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle + always-visible total ───────────────────────
              GestureDetector(
                onTap: _toggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _TotalRow(total: total),
                    ],
                  ),
                ),
              ),
              // ── Expandable section (widget stays in tree → state preserved)
              ClipRect(
                child: IgnorePointer(
                  ignoring: !_expanded,
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    heightFactor: _expanded ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TenderedRow(total: total, empty: empty),
                          const SizedBox(height: 12),
                          _ActionRow(
                            empty: empty,
                            isPrinting: isPrinting,
                            isInsufficient: isInsufficient,
                            onClear: () => _confirmClear(context),
                            onPrint: () => _printAndRecord(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Total row ────────────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final double total;
  const _TotalRow({required this.total});

  static final _fmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
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
          _fmt.format(total),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}

// ─── Tendered amount row ──────────────────────────────────────────────────────

class _TenderedRow extends ConsumerStatefulWidget {
  final double total;
  final bool empty;

  const _TenderedRow({required this.total, required this.empty});

  @override
  ConsumerState<_TenderedRow> createState() => _TenderedRowState();
}

class _TenderedRowState extends ConsumerState<_TenderedRow> {
  final _controller = TextEditingController();

  static final _fmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Reset the input field when the cart (and therefore tenderedAmount) is cleared.
    ref.listen(
      cartProvider.select((s) => s.tenderedAmount),
      (_, next) {
        if (next == null && _controller.text.isNotEmpty) {
          _controller.clear();
        }
      },
    );

    final cartState = ref.watch(cartProvider);
    final change = cartState.change(widget.total);
    final isInsufficient = cartState.insufficientTendered(widget.total);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !widget.empty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  labelText: l10n.tenderedAmount,
                  suffixText: '€',
                  isDense: true,
                  errorText: isInsufficient ? l10n.insufficientAmount : null,
                ),
                onChanged: (value) {
                  final parsed =
                      double.tryParse(value.replaceAll(',', '.').trim());
                  ref.read(cartProvider.notifier).setTenderedAmount(parsed);
                },
              ),
            ),
          ],
        ),
        if (change != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.changeDue,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),
              Text(
                _fmt.format(change),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final bool empty;
  final bool isPrinting;
  final bool isInsufficient;
  final VoidCallback onClear;
  final VoidCallback onPrint;

  const _ActionRow({
    required this.empty,
    required this.isPrinting,
    required this.isInsufficient,
    required this.onClear,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.clear),
            onPressed: empty || isPrinting ? null : onClear,
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
            onPressed: empty || isPrinting || isInsufficient ? null : onPrint,
          ),
        ),
      ],
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
