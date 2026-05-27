import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/core/database/database_helper.dart';
import 'package:ludo_pay_app/features/sales/data/models/business_day.dart';
import 'package:ludo_pay_app/features/sales/data/models/sale.dart';
import 'package:ludo_pay_app/features/sales/data/repositories/sales_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class ReportState {
  final BusinessDay? day;

  /// Each entry: { name_snapshot, total_quantity, product_total }
  final List<Map<String, dynamic>> productTotals;

  /// Individual sales for the day, each with its lines pre-loaded.
  final List<Sale> sales;

  /// All business days in the DB, ordered by date DESC (index 0 = most recent).
  final List<BusinessDay> allDays;

  /// Index of the currently displayed day within [allDays].
  final int currentDayIndex;

  const ReportState({
    this.day,
    required this.productTotals,
    this.sales = const [],
    this.allDays = const [],
    this.currentDayIndex = 0,
  });

  /// True when there is a business day with at least one sale.
  bool get hasData => day != null && day!.saleCount > 0;

  /// Can navigate to an older day.
  bool get canGoPrevious => currentDayIndex < allDays.length - 1;

  /// Can navigate to a more recent day.
  bool get canGoNext => currentDayIndex > 0;

  /// True when the displayed day is today's date.
  bool get isDayToday {
    if (day == null) return false;
    return day!.date == DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
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

  /// Tracks which day is currently on screen across refreshes.
  int _currentIndex = 0;

  @override
  Future<ReportState> build() => _load();

  Future<ReportState> _load([int? index]) async {
    final allDays = await _repo.getAllBusinessDays();

    if (allDays.isEmpty) {
      _currentIndex = 0;
      return const ReportState(productTotals: []);
    }

    final targetIndex = (index ?? _currentIndex).clamp(0, allDays.length - 1);
    _currentIndex = targetIndex;

    final day = allDays[targetIndex];

    // Load product totals and individual sales in parallel.
    final results = await Future.wait([
      _repo.getTotalsByProduct(day.id!),
      _repo.getSalesWithLinesByDay(day.id!),
    ]);

    return ReportState(
      day: day,
      productTotals: results[0] as List<Map<String, dynamic>>,
      sales: results[1] as List<Sale>,
      allDays: allDays,
      currentDayIndex: targetIndex,
    );
  }

  /// Reloads data from the database, keeping the current day on screen.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Navigates one day into the past.
  Future<void> goToPreviousDay() async {
    if (!(state.valueOrNull?.canGoPrevious ?? false)) return;
    // Keep current state visible while loading — no full-screen spinner.
    final next = await AsyncValue.guard(() => _load(_currentIndex + 1));
    state = next;
  }

  /// Navigates one day into the future (toward today).
  Future<void> goToNextDay() async {
    if (!(state.valueOrNull?.canGoNext ?? false)) return;
    final next = await AsyncValue.guard(() => _load(_currentIndex - 1));
    state = next;
  }

  /// Closes the current business day and reloads.
  Future<void> closeDay() async {
    final current = state.valueOrNull;
    if (current?.day == null || current!.day!.isClosed) return;
    await _repo.closeBusinessDay(current.day!.id!);
    state = await AsyncValue.guard(_load);
  }
}
