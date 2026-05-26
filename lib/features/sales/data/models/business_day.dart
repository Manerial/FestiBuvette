class BusinessDay {
  final int? id;
  final String date; // ISO format: "2026-05-26"
  final double totalRevenue;
  final int saleCount;
  final String? closedAt;

  const BusinessDay({
    this.id,
    required this.date,
    required this.totalRevenue,
    required this.saleCount,
    this.closedAt,
  });

  bool get isClosed => closedAt != null;

  BusinessDay copyWith({
    int? id,
    String? date,
    double? totalRevenue,
    int? saleCount,
    String? closedAt,
  }) =>
      BusinessDay(
        id: id ?? this.id,
        date: date ?? this.date,
        totalRevenue: totalRevenue ?? this.totalRevenue,
        saleCount: saleCount ?? this.saleCount,
        closedAt: closedAt ?? this.closedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'total_revenue': totalRevenue,
        'sale_count': saleCount,
        'closed_at': closedAt,
      };

  factory BusinessDay.fromMap(Map<String, dynamic> map) => BusinessDay(
        id: map['id'] as int?,
        date: map['date'] as String,
        totalRevenue: (map['total_revenue'] as num).toDouble(),
        saleCount: map['sale_count'] as int,
        closedAt: map['closed_at'] as String?,
      );
}
