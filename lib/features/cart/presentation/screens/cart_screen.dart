import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/features/cart/providers/cart_provider.dart';
import 'package:festi_buvette_app/features/printer/data/services/ticket_service.dart';
import 'package:festi_buvette_app/features/printer/providers/printer_provider.dart';
import 'package:festi_buvette_app/features/products/data/models/product.dart';
import 'package:festi_buvette_app/features/products/presentation/widgets/category_filter_bar.dart';
import 'package:festi_buvette_app/features/products/providers/categories_provider.dart';
import 'package:festi_buvette_app/features/products/providers/products_provider.dart';
import 'package:festi_buvette_app/features/report/providers/report_provider.dart';
import 'package:festi_buvette_app/features/sales/services/sale_service.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_exception.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_role.dart';
import 'package:festi_buvette_app/features/sync/providers/sync_provider.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';

void _triggerHaptic(WidgetRef ref) {
  if (ref.read(settingsProvider).valueOrNull?.hapticFeedback ?? true) {
    Vibration.vibrate(duration: 40);
  }
}

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
    final gridView =
        ref.watch(settingsProvider).valueOrNull?.cartGridView ?? true;

    // If selected category was deleted, fall back to "All".
    final effectiveCategoryId =
        categories.any((c) => c.id == _selectedCategoryId)
            ? _selectedCategoryId
            : null;

    // Out-of-stock products are not purchasable — exclude from the cart entirely.
    final available =
        widget.products.where((p) => !p.isOutOfStock).toList();

    final filtered = effectiveCategoryId == null
        ? available
        : available
            .where((p) => p.categoryId == effectiveCategoryId)
            .toList();

    return Column(
      children: [
        // ── Category filter ────────────────────────────────────────────
        if (categories.isNotEmpty)
          CategoryFilterBar(
            categories: categories,
            selectedCategoryId: effectiveCategoryId,
            onSelect: (id) => setState(() => _selectedCategoryId = id),
          ),
        // ── Product list or grid ───────────────────────────────────────
        Expanded(
          child: gridView
              ? GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ProductGridTile(
                    product: filtered[index],
                    quantity: cartState.quantities[filtered[index].id] ?? 0,
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ProductRow(
                    product: filtered[index],
                    quantity: cartState.quantities[filtered[index].id] ?? 0,
                  ),
                ),
        ),
        // Footer uses available products (OOS excluded) to compute total.
        _Footer(products: available, cartState: cartState),
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
            onPressed: inCart
                ? () {
                    _triggerHaptic(ref);
                    notifier.decrement(product.id!);
                  }
                : null,
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
            onPressed: () {
              _triggerHaptic(ref);
              notifier.increment(product.id!);
            },
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// ─── Product grid tile ────────────────────────────────────────────────────────

class _ProductGridTile extends ConsumerWidget {
  final Product product;
  final int quantity;

  const _ProductGridTile({required this.product, required this.quantity});

  static final _priceFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final inCart = quantity > 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: inCart ? 3 : 1,
      color: inCart ? colorScheme.primaryContainer : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Name + price ─────────────────────────────────────────
            Column(
              children: [
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        inCart ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: inCart
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceFmt.format(product.price),
                  style: TextStyle(
                    fontSize: 12,
                    color: inCart
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            // ── Controls ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 28),
                  onPressed: inCart
                      ? () {
                          _triggerHaptic(ref);
                          notifier.decrement(product.id!);
                        }
                      : null,
                  color: colorScheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: inCart ? colorScheme.primary : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  onPressed: () {
                    _triggerHaptic(ref);
                    notifier.increment(product.id!);
                  },
                  color: colorScheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
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

class _FooterState extends ConsumerState<_Footer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _contentKey = GlobalKey();
  double _dragStartDy = 0;
  double _dragStartValue = 0;

  // True while the second device is waiting for the control to print.
  bool _isSending = false;

  bool get _expanded => _controller.value > 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_expanded) {
      _controller.animateTo(0, curve: Curves.easeInOut);
    } else {
      _controller.animateTo(1, curve: Curves.easeInOut);
    }
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartDy = details.globalPosition.dy;
    _dragStartValue = _controller.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final renderBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    final height = renderBox?.size.height ?? 200.0;
    final delta = _dragStartDy - details.globalPosition.dy;
    _controller.value = (_dragStartValue + delta / height).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300 || (_controller.value >= 0.5 && velocity <= 300)) {
      _controller.animateTo(1, curve: Curves.easeOut);
    } else {
      _controller.animateTo(0, curve: Curves.easeOut);
    }
  }

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

  // ── Second mode: delegate print to control, record locally ───────────────

  Future<void> _printAndRecordSecond(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(cartProvider.notifier).isEmpty) return;

    final syncClient = ref.read(syncProvider.notifier).client;
    if (syncClient == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.syncConnectionFailed),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    // Build the items payload from the current cart.
    final items = widget.products
        .where((p) => (widget.cartState.quantities[p.id] ?? 0) > 0)
        .map((p) => {
              'product_id': p.id,
              'name': p.name,
              'price': p.price,
              'quantity': widget.cartState.quantities[p.id]!,
            })
        .toList();

    if (mounted) setState(() => _isSending = true);
    try {
      await syncClient.post('/print', {'items': items});
      // Print succeeded → record locally + clear cart.
      if (context.mounted) await _recordSale(context);
    } on SyncServerException {
      // 503 print_failed → ask operator whether to record anyway.
      if (mounted) setState(() => _isSending = false);
      if (!context.mounted) return;
      final recordOnly = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.printerNotConnectedTitle),
          content: Text(l10n.syncPrintFailed),
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
      if (recordOnly == true && context.mounted) await _recordSale(context);
      return;
    } on SyncNetworkException {
      // Network error → cart preserved, do not record.
      if (mounted) setState(() => _isSending = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.syncConnectionFailed),
          backgroundColor: Colors.red,
        ));
      }
      return;
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.errorMessage(e)),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    if (mounted) setState(() => _isSending = false);
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
      final categories =
          ref.read(categoriesProvider).valueOrNull ?? [];
      final bytes = await TicketService().buildReceiptFromCart(
        businessName: businessName,
        dateTime: DateTime.now(),
        products: widget.products,
        quantities: widget.cartState.quantities,
        categories: categories,
        otherCategoryLabel: l10n.ticketOtherCategory,
        thankYouLabel: l10n.ticketThankYou,
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
    final todayDay = ref.watch(
      reportProvider.select((async) => async.valueOrNull?.todayBusinessDay),
    );
    final isDayActive = todayDay != null && !todayDay.isClosed;

    final syncRole = ref.watch(
      settingsProvider.select(
          (s) => s.valueOrNull?.syncRole ?? SyncRole.standalone),
    );
    final isSyncConnected = ref.watch(
      syncProvider.select(
          (s) => s.connectionStatus == SyncConnectionStatus.connected),
    );
    final isSecondMode = syncRole == SyncRole.second && isSyncConnected;
    final effectivePrinting = isSecondMode ? _isSending : isPrinting;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle + always-visible total ─────────────────────────
            GestureDetector(
              onTap: _toggle,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
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
            AnimatedBuilder(
              animation: _controller,
              builder: (ctx, child) => ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _controller.value,
                  child: IgnorePointer(
                    ignoring: _controller.value < 0.01,
                    child: child!,
                  ),
                ),
              ),
              child: Padding(
                key: _contentKey,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CartSummary(
                      products: widget.products,
                      quantities: widget.cartState.quantities,
                    ),
                    _TenderedRow(total: total, empty: empty),
                    const SizedBox(height: 12),
                    _ActionRow(
                      empty: empty,
                      isPrinting: effectivePrinting,
                      isInsufficient: isInsufficient,
                      isDayActive: isDayActive,
                      onClear: () => _confirmClear(context),
                      onPrint: () => isSecondMode
                          ? _printAndRecordSecond(context)
                          : _printAndRecord(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

class _TenderedRow extends ConsumerWidget {
  final double total;
  final bool empty;

  const _TenderedRow({required this.total, required this.empty});

  static const _kBillAmounts = [5, 10, 20, 50];

  static final _fmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  void _selectBill(WidgetRef ref, int amount) {
    final current = ref.read(cartProvider).tenderedAmount;
    ref.read(cartProvider.notifier).setTenderedAmount(
          current == amount.toDouble() ? null : amount.toDouble(),
        );
  }

  Future<void> _showCustomInput(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final previousAmount = ref.read(cartProvider).tenderedAmount;
    final controller = TextEditingController(
      text: previousAmount != null ? previousAmount.toStringAsFixed(2) : '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tenderedAmount),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          decoration: const InputDecoration(suffixText: '€', isDense: true),
          onChanged: (value) {
            final parsed = double.tryParse(value.replaceAll(',', '.').trim());
            ref.read(cartProvider.notifier).setTenderedAmount(parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).setTenderedAmount(previousAmount);
              Navigator.pop(ctx);
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cartState = ref.watch(cartProvider);
    final change = cartState.change(total);
    final isInsufficient = cartState.insufficientTendered(total);
    final tendered = cartState.tenderedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        Text(
          l10n.tenderedAmount,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        // ── Bill buttons + custom input ────────────────────────────────────
        Row(
          children: [
            ..._kBillAmounts.map((amount) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _BillButton(
                      label: '$amount €',
                      isSelected: tendered == amount.toDouble(),
                      enabled: !empty,
                      onTap: () => _selectBill(ref, amount),
                    ),
                  ),
                )),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: empty ? null : () => _showCustomInput(context, ref),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.tenderedAmount,
            ),
          ],
        ),
        // ── Validation error ───────────────────────────────────────────────
        if (isInsufficient) ...[
          const SizedBox(height: 4),
          Text(
            l10n.insufficientAmount,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
        // ── Change ─────────────────────────────────────────────────────────
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

// ─── Bill button ──────────────────────────────────────────────────────────────

class _BillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _BillButton({
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  static const _kStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    minimumSize: WidgetStatePropertyAll(Size(0, 36)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
  );

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return FilledButton(
        onPressed: enabled ? onTap : null,
        style: _kStyle,
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: _kStyle,
      child: Text(label),
    );
  }
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final bool empty;
  final bool isPrinting;
  final bool isInsufficient;
  final bool isDayActive;
  final VoidCallback onClear;
  final VoidCallback onPrint;

  const _ActionRow({
    required this.empty,
    required this.isPrinting,
    required this.isInsufficient,
    required this.isDayActive,
    required this.onClear,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canPrint = !empty && !isPrinting && !isInsufficient && isDayActive;

    Widget printBtn = FilledButton.icon(
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
      onPressed: canPrint ? onPrint : null,
    );

    if (!isDayActive) {
      printBtn = Tooltip(
        message: l10n.dayNotStarted,
        child: printBtn,
      );
    }

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
        Expanded(flex: 2, child: printBtn),
      ],
    );
  }
}

// ─── Cart summary ─────────────────────────────────────────────────────────────

class _CartSummary extends StatelessWidget {
  final List<Product> products;
  final Map<int, int> quantities;

  const _CartSummary({required this.products, required this.quantities});

  @override
  Widget build(BuildContext context) {
    final items = products
        .where((p) => (quantities[p.id] ?? 0) > 0)
        .map((p) => (name: p.name, qty: quantities[p.id]!))
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.name),
                        Text(
                          '× ${item.qty}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 20),
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
