import 'sale_line.dart';

class Sale {
  final int? id;
  final String dateTime; // ISO 8601
  final double total;
  final int businessDayId;
  final List<SaleLine> lines;

  const Sale({
    this.id,
    required this.dateTime,
    required this.total,
    required this.businessDayId,
    this.lines = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date_time': dateTime,
        'total': total,
        'business_day_id': businessDayId,
      };

  factory Sale.fromMap(Map<String, dynamic> map,
          {List<SaleLine> lines = const []}) =>
      Sale(
        id: map['id'] as int?,
        dateTime: map['date_time'] as String,
        total: (map['total'] as num).toDouble(),
        businessDayId: map['business_day_id'] as int,
        lines: lines,
      );
}
