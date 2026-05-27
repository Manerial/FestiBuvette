import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_pay_app/features/report/providers/report_provider.dart';
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

class _EmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

// ─── Report content ───────────────────────────────────────────────────────────

class _ReportContent extends ConsumerWidget {
  final ReportState report;
  const _ReportContent({required this.report});


  static final _currencyFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final day = report.day!;
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMMMMEEEEd(locale).format(
      DateFormat('yyyy-MM-dd').parse(day.date),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary card ────────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date row with navigation arrows ──────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '←',
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: report.canGoPrevious
                          ? () => ref
                              .read(reportProvider.notifier)
                              .goToPreviousDay()
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        dateStr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '→',
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: report.canGoNext
                          ? () => ref
                              .read(reportProvider.notifier)
                              .goToNextDay()
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Revenue + count ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currencyFmt.format(day.totalRevenue),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          Text(
                            l10n.reportSaleCount(day.saleCount),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Close day status / button — only relevant for today.
                    if (day.isClosed)
                      _ClosedBadge(closedAt: day.closedAt!)
                    else if (report.isDayToday)
                      _CloseDayButton(day: day),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Product breakdown ───────────────────────────────────────────────
        Text(
          l10n.reportByProduct.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // Header row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        l10n.reportQtyHeader,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '€',
                        textAlign: TextAlign.right,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Product rows
              ...report.productTotals.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                final isLast = i == report.productTotals.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row['name_snapshot'] as String,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '× ${row['total_quantity']}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              _currencyFmt
                                  .format(row['product_total'] as num),
                              textAlign: TextAlign.right,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 16),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Close day button ─────────────────────────────────────────────────────────

class _CloseDayButton extends ConsumerWidget {
  final dynamic day;
  const _CloseDayButton({required this.day});

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
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
