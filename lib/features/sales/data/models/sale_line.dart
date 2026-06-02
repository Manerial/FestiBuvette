class SaleLine {
  final int? id;
  final int saleId;

  /// Null for sales received from a second device (no product ID mapping guaranteed).
  final int? productId;
  final String nameSnapshot; // product name at time of sale
  final double priceSnapshot; // product price at time of sale
  final int quantity;
  final double subtotal;

  const SaleLine({
    this.id,
    required this.saleId,
    this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sale_id': saleId,
    'product_id': productId,
    'name_snapshot': nameSnapshot,
    'price_snapshot': priceSnapshot,
    'quantity': quantity,
    'subtotal': subtotal,
  };

  factory SaleLine.fromMap(Map<String, dynamic> map) => SaleLine(
    id: map['id'] as int?,
    saleId: map['sale_id'] as int,
    productId: map['product_id'] as int?,
    nameSnapshot: map['name_snapshot'] as String,
    priceSnapshot: (map['price_snapshot'] as num).toDouble(),
    quantity: map['quantity'] as int,
    subtotal: (map['subtotal'] as num).toDouble(),
  );
}
