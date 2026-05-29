import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/sales/data/models/business_day.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class ReportState {
  final BusinessDay? day;

  /// True when no real BusinessDay exists for today — the UI shows a virtual
  /// "not started" entry instead of sales data.
  final bool isTodayVirtual;

  /// Each entry: { name_snapshot, total_quantity, product_total }
  final List<Map<String, dynamic>> productTotals;

  /// Individual sales for the day, each with its lines pre-loaded.
  final List<Sale> sales;

  /// All real business days in the DB, ordered by date DESC (index 0 = most recent).
  final List<BusinessDay> allDays;

  /// Index of the currently displayed day within [allDays].
  /// Irrelevant when [isTodayVirtual] is true.
  final int currentDayIndex;

  /// Distinct product names that appear in the day's snapshots, sorted alphabetically.
  final List<String> hourlyProducts;

  /// Hourly breakdown: hour (9–18) → product name → quantity sold.
  final Map<int, Map<String, int>> hourlyData;

  const ReportState({
    this.day,
    this.isTodayVirtual = false,
    required this.productTotals,
    this.sales = const [],
    this.allDays = const [],
    this.currentDayIndex = 0,
    this.hourlyProducts = const [],
    this.hourlyData = const {},
  });

  /// True when there is a business day with at least one sale.
  bool get hasData => day != null && day!.saleCount > 0;

  /// True when a virtual today slot exists (no real BusinessDay for today).
  /// Used by the cart to gate the submit button.
  bool get hasVirtualSlot {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return allDays.isEmpty || allDays.first.date != today;
  }

  /// Today's real BusinessDay, or null if it doesn't exist or isn't started.
  /// Always reflects today regardless of which day is currently viewed.
  BusinessDay? get todayBusinessDay {
    if (isTodayVirtual) return null;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (allDays.isNotEmpty && allDays.first.date == today) {
      return allDays.first;
    }
    return null;
  }

  /// Can navigate to an older day.
  bool get canGoPrevious {
    if (isTodayVirtual) return allDays.isNotEmpty;
    return currentDayIndex < allDays.length - 1;
  }

  /// Can navigate to a more recent day.
  bool get canGoNext {
    if (isTodayVirtual) return false;
    if (currentDayIndex > 0) return true;
    return hasVirtualSlot;
  }

  /// True when the displayed day is today's date (real or virtual).
  bool get isDayToday {
    if (isTodayVirtual) return true;
    if (day == null) return false;
    return day!.date == DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final reportProvider =
    AsyncNotifierProvider<ReportNotifier, ReportState>(ReportNotifier.new);

/// True when today has an active (not closed) BusinessDay.
/// Used by the cart and products screen to gate writes.
final isCatalogLockedProvider = Provider<bool>((ref) {
  final day = ref.watch(
    reportProvider.select((async) => async.valueOrNull?.todayBusinessDay),
  );
  return day != null && !day.isClosed;
});

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ReportNotifier extends AsyncNotifier<ReportState> {
  final SalesRepository? _repoOverride;

  /// Default constructor — uses the production singleton.
  ReportNotifier() : _repoOverride = null;

  /// Named constructor for tests — injects a custom repository.
  ReportNotifier.withRepository(SalesRepository repo) : _repoOverride = repo;

  SalesRepository get _repo =>
      _repoOverride ?? SalesRepository(DatabaseHelper.instance);

  /// -1 = showing virtual today; 0+ = index in allDays.
  int _currentIndex = -1;

  @override
  Future<ReportState> build() => _load();

  Future<ReportState> _load() async {
    final allDays = await _repo.getAllBusinessDays();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayIsReal = allDays.isNotEmpty && allDays.first.date == today;

    // Reconcile _currentIndex with DB reality.
    if (_currentIndex < 0) {
      // Was virtual — if today just became real, land on it.
      if (todayIsReal) _currentIndex = 0;
    } else if (allDays.isEmpty) {
      _currentIndex = -1;
    } else {
      _currentIndex = _currentIndex.clamp(0, allDays.length - 1);
    }

    if (_currentIndex < 0) {
      return ReportState(
        isTodayVirtual: true,
        productTotals: const [],
        allDays: allDays,
        currentDayIndex: 0,
      );
    }

    final day = allDays[_currentIndex];

    // Load product totals, individual sales, and hourly data in parallel.
    final results = await Future.wait([
      _repo.getTotalsByProduct(day.id!),
      _repo.getSalesWithLinesByDay(day.id!),
      _repo.getHourlySalesByProduct(day.id!),
    ]);

    final hourlyRaw = results[2] as List<Map<String, dynamic>>;
    final productNames = <String>{};
    final hourlyData = <int, Map<String, int>>{};
    for (final row in hourlyRaw) {
      final hour = (row['hour'] as num).toInt();
      final name = row['name_snapshot'] as String;
      final qty = (row['total_quantity'] as num).toInt();
      productNames.add(name);
      (hourlyData[hour] ??= {})[name] = qty;
    }
    final hourlyProducts = productNames.toList()..sort();

    return ReportState(
      isTodayVirtual: false,
      day: day,
      productTotals: results[0] as List<Map<String, dynamic>>,
      sales: results[1] as List<Sale>,
      allDays: allDays,
      currentDayIndex: _currentIndex,
      hourlyProducts: hourlyProducts,
      hourlyData: hourlyData,
    );
  }

  /// Reloads data from the database, keeping the current position.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Navigates one day into the past.
  Future<void> goToPreviousDay() async {
    if (!(state.valueOrNull?.canGoPrevious ?? false)) return;
    _currentIndex++; // -1 → 0 (virtual to first real), n → n+1 (older)
    state = await AsyncValue.guard(_load);
  }

  /// Navigates one day into the future (toward today).
  Future<void> goToNextDay() async {
    if (!(state.valueOrNull?.canGoNext ?? false)) return;
    _currentIndex--; // 0 → -1 (first real to virtual), n → n-1 (newer)
    state = await AsyncValue.guard(_load);
  }

  /// Deletes [sale] and refreshes the current day view.
  Future<void> deleteSale(Sale sale) async {
    await _repo.deleteSale(sale);
    state = await AsyncValue.guard(_load);
  }

  /// Creates today's BusinessDay and switches to it.
  Future<void> startDay() async {
    await _repo.getOrCreateToday();
    _currentIndex = 0;
    state = await AsyncValue.guard(_load);
  }

  /// Closes the current business day and reloads.
  Future<void> closeDay() async {
    final current = state.valueOrNull;
    if (current == null || current.isTodayVirtual) return;
    if (current.day == null || current.day!.isClosed) return;
    await _repo.closeBusinessDay(current.day!.id!);
    state = await AsyncValue.guard(_load);
  }

  /// Reopens the current business day (today only).
  Future<void> reopenDay() async {
    final current = state.valueOrNull;
    if (current == null || current.isTodayVirtual) return;
    if (current.day == null || !current.day!.isClosed) return;
    if (!current.isDayToday) return;
    await _repo.reopenBusinessDay(current.day!.id!);
    state = await AsyncValue.guard(_load);
  }
}
