import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/core/database/database_helper.dart';
import 'package:ludo_pay_app/features/sales/data/models/business_day.dart';
import 'package:ludo_pay_app/features/sales/data/repositories/sales_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class ReportState {
  final BusinessDay? day;

  /// Each entry: { name_snapshot, total_quantity, product_total }
  final List<Map<String, dynamic>> productTotals;

  const ReportState({
    this.day,
    required this.productTotals,
  });

  /// True when there is a business day with at least one sale.
  bool get hasData => day != null && day!.saleCount > 0;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final reportProvider =
    AsyncNotifierProvider<ReportNotifier, ReportState>(ReportNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ReportNotifier extends AsyncNotifier<ReportState> {
  final SalesRepository? _repoOverride;

  /// Default constructor — uses the production singleton.
  ReportNotifier() : _repoOverride = null;

  /// Named constructor for tests — injects a custom repository.
  ReportNotifier.withRepository(SalesRepository repo) : _repoOverride = repo;

  SalesRepository get _repo =>
      _repoOverride ?? SalesRepository(DatabaseHelper.instance);

  @override
  Future<ReportState> build() => _load();

  Future<ReportState> _load() async {
    final day = await _repo.getToday();
    if (day == null) return const ReportState(productTotals: []);
    final totals = await _repo.getTotalsByProduct(day.id!);
    return ReportState(day: day, productTotals: totals);
  }

  /// Reloads data from the database.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Closes the current business day and reloads.
  Future<void> closeDay() async {
    final current = state.valueOrNull;
    if (current?.day == null || current!.day!.isClosed) return;
    await _repo.closeBusinessDay(current.day!.id!);
    state = await AsyncValue.guard(_load);
  }
}
