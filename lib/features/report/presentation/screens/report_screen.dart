import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/features/report/providers/report_provider.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportAsync = ref.watch(reportProvider);

    return reportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e))),
      data: (report) => report.allDays.isNotEmpty
          ? _ReportContent(report: report)
          : _EmptyState(),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            l10n.reportNoSalesToday,
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

// ─── Report view mode ─────────────────────────────────────────────────────────

enum _ReportView { byProduct, byCart }

// Shared formatters (used by _SummaryCard, _ProductView, and _CartView).
final _kCurrencyFmt = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 2,
);
final _kTimeFmt = DateFormat.Hm();

// ─── Report content ───────────────────────────────────────────────────────────

class _ReportContent extends ConsumerStatefulWidget {
  final ReportState report;
  const _ReportContent({required this.report});

  @override
  ConsumerState<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends ConsumerState<_ReportContent> {
  _ReportView _view = _ReportView.byProduct;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(report: report),

        const SizedBox(height: 16),

        // ── View selector ───────────────────────────────────────────────────
        SegmentedButton<_ReportView>(
          segments: [
            ButtonSegment(
              value: _ReportView.byProduct,
              label: Text(l10n.reportByProduct),
              icon: const Icon(Icons.bar_chart_outlined),
            ),
            ButtonSegment(
              value: _ReportView.byCart,
              label: Text(l10n.reportByCart),
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),

        const SizedBox(height: 16),

        // ── Breakdown ───────────────────────────────────────────────────────
        if (_view == _ReportView.byProduct)
          _ProductView(productTotals: report.productTotals)
        else
          _CartView(sales: report.sales),
      ],
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends ConsumerWidget {
  final ReportState report;
  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final day = report.day!;
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMMMMEEEEd(locale).format(
      DateFormat('yyyy-MM-dd').parse(day.date),
    );
    final notifier = ref.read(reportProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Navigation row ──────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: report.canGoPrevious
                      ? () => notifier.goToPreviousDay()
                      : null,
                ),
                Expanded(
                  child: Text(
                    dateStr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: report.canGoNext
                      ? () => notifier.goToNextDay()
                      : null,
                ),
              ],
            ),
            const Divider(height: 16),
            // ── Revenue ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.reportSaleCount(day.saleCount),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  _kCurrencyFmt.format(day.totalRevenue),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            // ── Status ──────────────────────────────────────────────────────
            if (day.isClosed) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _ClosedBadge(closedAt: day.closedAt!),
              ),
            ] else if (report.isDayToday) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: const _CloseDayButton(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Shared line row ──────────────────────────────────────────────────────────

class _ReportLineRow extends StatelessWidget {
  final String name;

  /// Optional unit price shown as a small subtitle under the product name.
  final String? unitPrice;

  final String qty;
  final String amount;
  final bool nameSemibold;
  final double verticalPadding;

  const _ReportLineRow({
    required this.name,
    this.unitPrice,
    required this.qty,
    required this.amount,
    this.nameSemibold = false,
    this.verticalPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: nameSemibold ? FontWeight.w500 : null,
                      ),
                ),
                if (unitPrice != null)
                  Text(
                    unitPrice!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Product view ─────────────────────────────────────────────────────────────

class _ProductView extends StatelessWidget {
  final List<Map<String, dynamic>> productTotals;
  const _ProductView({required this.productTotals});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                SizedBox(
                  width: 48,
                  child: Text(
                    l10n.reportQtyHeader,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '€',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Product rows
          ...productTotals.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final isLast = i == productTotals.length - 1;
            return Column(
              children: [
                _ReportLineRow(
                  name: row['name_snapshot'] as String,
                  unitPrice: _kCurrencyFmt.format(
                      row['price_snapshot'] as num),
                  qty: '× ${row['total_quantity']}',
                  amount: _kCurrencyFmt.format(row['product_total'] as num),
                  nameSemibold: true,
                ),
                if (!isLast) const Divider(height: 1, indent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Cart view ────────────────────────────────────────────────────────────────

class _CartView extends StatelessWidget {
  final List<Sale> sales;
  const _CartView({required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return const SizedBox.shrink();

    return Column(
      children: sales.asMap().entries.map((entry) {
        final i = entry.key;
        final sale = entry.value;
        final time = _kTimeFmt.format(DateTime.parse(sale.dateTime));
        final isLastSale = i == sales.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLastSale ? 0 : 12),
          child: Card(
            child: Column(
              children: [
                // ── Sale header: time + total ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        time,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        _kCurrencyFmt.format(sale.total),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── Sale lines ────────────────────────────────────────────
                ...sale.lines.asMap().entries.map((lineEntry) {
                  final j = lineEntry.key;
                  final line = lineEntry.value;
                  final isLastLine = j == sale.lines.length - 1;
                  return Column(
                    children: [
                      _ReportLineRow(
                        name: line.nameSnapshot,
                        unitPrice: _kCurrencyFmt.format(line.priceSnapshot),
                        qty: '× ${line.quantity}',
                        amount: _kCurrencyFmt.format(line.subtotal),
                        verticalPadding: 10,
                      ),
                      if (!isLastLine) const Divider(height: 1, indent: 16),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Close day button ─────────────────────────────────────────────────────────

class _CloseDayButton extends ConsumerWidget {
  const _CloseDayButton();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reportCloseDayTitle),
        content: Text(l10n.reportCloseDayMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(reportProvider.notifier).closeDay();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton(
      onPressed: () => _confirm(context, ref),
      child: Text(l10n.reportCloseDay),
    );
  }
}

// ─── Closed badge ─────────────────────────────────────────────────────────────

class _ClosedBadge extends StatelessWidget {
  final String closedAt;
  const _ClosedBadge({required this.closedAt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final time = DateFormat.Hm().format(DateTime.parse(closedAt));
    return Chip(
      avatar: const Icon(Icons.lock_outline, size: 16),
      label: Text(l10n.reportDayClosed(time)),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
