import 'dart:math' as math;

import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/features/printer/data/services/ticket_service.dart';
import 'package:festi_buvette_app/features/printer/providers/printer_provider.dart';
import 'package:festi_buvette_app/features/report/providers/report_provider.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportAsync = ref.watch(reportProvider);

    return reportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e))),
      data: (report) => _ReportContent(report: report),
    );
  }
}

// ─── Report view mode ─────────────────────────────────────────────────────────

enum _ReportView { byProduct, byCart, byHour }

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
  _ReportView _view = _ReportView.byCart;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(report: report),

        const SizedBox(height: 16),

        if (report.isTodayVirtual) ...[
          // ── Not started state ────────────────────────────────────────────
          const _NotStartedState(),
        ] else ...[
          // ── View selector ────────────────────────────────────────────────
          SegmentedButton<_ReportView>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _ReportView.byCart,
                label: Text(l10n.reportByCart),
              ),
              ButtonSegment(
                value: _ReportView.byProduct,
                label: Text(l10n.reportByProduct),
              ),
              ButtonSegment(
                value: _ReportView.byHour,
                label: Text(l10n.reportByHour),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),

          const SizedBox(height: 16),

          // ── Breakdown ────────────────────────────────────────────────────
          if (_view == _ReportView.byProduct)
            _ProductView(productTotals: report.productTotals)
          else if (_view == _ReportView.byCart)
            _CartView(sales: report.sales)
          else
            _HourlyView(
              products: report.hourlyProducts,
              hourlyData: report.hourlyData,
            ),
        ],
      ],
    );
  }
}

// ─── Not started state ────────────────────────────────────────────────────────

class _NotStartedState extends ConsumerWidget {
  const _NotStartedState();

  Future<void> _startDay(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.startDay),
        content: Text(l10n.startDayConfirm),
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
      await ref.read(reportProvider.notifier).startDay();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.today_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              l10n.dayNotStarted,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _startDay(context, ref),
              child: Text(l10n.startDay),
            ),
          ],
        ),
      ),
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
    final locale = Localizations.localeOf(context).toString();
    final notifier = ref.read(reportProvider.notifier);

    final String dateStr;
    final int saleCount;
    final double revenue;

    if (report.isTodayVirtual) {
      dateStr = DateFormat.yMMMMEEEEd(locale).format(DateTime.now());
      saleCount = 0;
      revenue = 0.0;
    } else {
      final day = report.day!;
      dateStr = DateFormat.yMMMMEEEEd(
        locale,
      ).format(DateFormat('yyyy-MM-dd').parse(day.date));
      saleCount = day.saleCount;
      revenue = day.totalRevenue;
    }

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
                  l10n.reportSaleCount(saleCount),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  _kCurrencyFmt.format(revenue),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            // ── Status (real days only) ──────────────────────────────────────
            if (!report.isTodayVirtual) ...[
              if (report.day!.isClosed) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ClosedBadge(closedAt: report.day!.closedAt!),
                ),
                if (report.isDayToday) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const _ReopenDayButton(),
                  ),
                ],
              ] else if (report.isDayToday) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: const _CloseDayButton(),
                ),
              ],
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
                  unitPrice: _kCurrencyFmt.format(row['price_snapshot'] as num),
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

class _CartView extends ConsumerWidget {
  final List<Sale> sales;

  const _CartView({required this.sales});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sales.isEmpty) return const SizedBox.shrink();

    return Column(
      children: sales.asMap().entries.map((entry) {
        final i = entry.key;
        final sale = entry.value;
        final isLastSale = i == sales.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLastSale ? 0 : 12),
          child: _SaleTile(sale: sale),
        );
      }).toList(),
    );
  }
}

// ─── Sale tile ────────────────────────────────────────────────────────────────

class _SaleTile extends ConsumerWidget {
  final Sale sale;

  const _SaleTile({required this.sale});

  Future<void> _deleteSale(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reportDeleteSaleTitle),
        content: Text(
          l10n.reportDeleteSaleMessage(_kCurrencyFmt.format(sale.total)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(reportProvider.notifier).deleteSale(sale);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.reportDeleteSaleSuccess)));
      }
    }
  }

  Future<void> _reprintSale(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final printerState = ref.read(printerProvider).valueOrNull;

    if (printerState == null || !printerState.isConnected) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.printerNotConnected)));
      }
      return;
    }

    final businessName =
        ref.read(settingsProvider).valueOrNull?.appName ?? AppConstants.appName;
    final bytes = await TicketService().buildReceiptFromSale(
      businessName: businessName,
      sale: sale,
      thankYouLabel: l10n.ticketThankYou,
      totalLabel: l10n.total,
    );
    final success = await ref.read(printerProvider.notifier).printBytes(bytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.reportReprintSuccess : l10n.reportReprintError,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = _kTimeFmt.format(DateTime.parse(sale.dateTime));

    return Card(
      child: Column(
        children: [
          // ── Sale header: time + total + actions ───────────────────────
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 4,
              top: 4,
              bottom: 4,
            ),
            child: Row(
              children: [
                Text(
                  time,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  _kCurrencyFmt.format(sale.total),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.print_outlined),
                  tooltip: AppLocalizations.of(context)!.print,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _reprintSale(context, ref),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: AppLocalizations.of(context)!.delete,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteSale(context, ref),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Sale lines ────────────────────────────────────────────────
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
    );
  }
}

// ─── Hourly chart view ────────────────────────────────────────────────────────

class _HourlyView extends StatefulWidget {
  final List<String> products;
  final Map<int, Map<String, int>> hourlyData;

  const _HourlyView({required this.products, required this.hourlyData});

  @override
  State<_HourlyView> createState() => _HourlyViewState();
}

class _HourlyViewState extends State<_HourlyView> {
  late Set<String> _selected;

  static const _kHours = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18];

  static const _kColors = [
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF8BC34A),
  ];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.products);
  }

  @override
  void didUpdateWidget(_HourlyView old) {
    super.didUpdateWidget(old);
    if (!setEquals(Set.from(widget.products), Set.from(old.products))) {
      setState(() => _selected = Set.from(widget.products));
    }
  }

  Color _colorFor(int index) => _kColors[index % _kColors.length];

  double _barWidth(int count) => switch (count) {
    1 => 16,
    2 => 12,
    3 => 9,
    _ => math.max(4.0, 36.0 / count),
  };

  List<BarChartGroupData> _buildGroups(List<String> ordered) {
    return _kHours.asMap().entries.map((e) {
      final xIndex = e.key;
      final hour = e.value;
      final hourData = widget.hourlyData[hour] ?? {};

      return BarChartGroupData(
        x: xIndex,
        barsSpace: 2,
        barRods: ordered.asMap().entries.map((pe) {
          return BarChartRodData(
            toY: (hourData[pe.value] ?? 0).toDouble(),
            color: _colorFor(pe.key),
            width: _barWidth(ordered.length),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          );
        }).toList(),
      );
    }).toList();
  }

  void _showFilter(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        var localSelected = Set<String>.from(_selected);
        return StatefulBuilder(
          builder: (ctx, setStateSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(
                  children: [
                    Text(
                      l10n.reportHourlyFilterTitle,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final all = Set<String>.from(widget.products);
                        setStateSheet(() => localSelected = all);
                        setState(() => _selected = Set.from(all));
                      },
                      child: Text(l10n.reportHourlySelectAll),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.products
                      .map(
                        (p) => CheckboxListTile(
                          value: localSelected.contains(p),
                          title: Text(p),
                          onChanged: (v) {
                            setStateSheet(() {
                              if (v == true) {
                                localSelected.add(p);
                              } else {
                                localSelected.remove(p);
                              }
                            });
                            setState(() {
                              if (v == true) {
                                _selected.add(p);
                              } else {
                                _selected.remove(p);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ordered = widget.products.where(_selected.contains).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Filter button ──────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: Text('${ordered.length} / ${widget.products.length}'),
                onPressed: widget.products.isEmpty
                    ? null
                    : () => _showFilter(context, l10n),
              ),
            ),
            const SizedBox(height: 12),

            if (widget.products.isEmpty || ordered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    l10n.reportHourlyNoData,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              // ── Chart ──────────────────────────────────────────────────
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    minY: 0,
                    barGroups: _buildGroups(ordered),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            Theme.of(context).colorScheme.inverseSurface,
                        getTooltipItem: (group, _, rod, rodIndex) {
                          final hour = _kHours[group.x];
                          final product = ordered[rodIndex];
                          final qty = rod.toY.toInt();
                          return BarTooltipItem(
                            '$product\n${hour}h : $qty',
                            TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, _) => Text(
                            '${value.toInt() + 9}h',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            if (value % 1 != 0) return const SizedBox.shrink();
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Legend ─────────────────────────────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: ordered.asMap().entries.map((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _colorFor(e.key),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        e.value,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Reopen day button ────────────────────────────────────────────────────────

class _ReopenDayButton extends ConsumerWidget {
  const _ReopenDayButton();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reopenDay),
        content: Text(l10n.reopenDayConfirm),
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
      await ref.read(reportProvider.notifier).reopenDay();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton(
      onPressed: () => _confirm(context, ref),
      child: Text(l10n.reopenDay),
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
