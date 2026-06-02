import 'sale_line.dart';

class Sale {
  final int? id;
  final String dateTime; // ISO 8601
  final double total;
  final int businessDayId;
  final List<SaleLine> lines;

  /// The original local DB id on the device that created this sale.
  /// Set to [id] when a sale is first recorded locally, and preserved when the
  /// sale is downloaded from the control so that [sendSales] can use the
  /// stable composite key (source_device_token, source_local_id) for
  /// deduplication — even after the local [id] changes on re-insert.
  final int? sourceLocalId;

  const Sale({
    this.id,
    required this.dateTime,
    required this.total,
    required this.businessDayId,
    this.lines = const [],
    this.sourceLocalId,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date_time': dateTime,
    'total': total,
    'business_day_id': businessDayId,
    if (sourceLocalId != null) 'source_local_id': sourceLocalId,
  };

  factory Sale.fromMap(
    Map<String, dynamic> map, {
    List<SaleLine> lines = const [],
  }) => Sale(
    id: map['id'] as int?,
    dateTime: map['date_time'] as String,
    total: (map['total'] as num).toDouble(),
    businessDayId: map['business_day_id'] as int,
    lines: lines,
    sourceLocalId: map['source_local_id'] as int?,
  );
}
