class Product {
  final int? id;
  final String name;
  final double price;
  final int order;
  final bool active;
  final bool isOutOfStock;
  final String createdAt;
  final int? categoryId;

  const Product({
    this.id,
    required this.name,
    required this.price,
    required this.order,
    this.active = true,
    this.isOutOfStock = false,
    required this.createdAt,
    this.categoryId,
  });

  // Sentinel used to allow explicitly setting categoryId to null via copyWith.
  static const _noValue = Object();

  Product copyWith({
    int? id,
    String? name,
    double? price,
    int? order,
    bool? active,
    bool? isOutOfStock,
    String? createdAt,
    Object? categoryId = _noValue,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        order: order ?? this.order,
        active: active ?? this.active,
        isOutOfStock: isOutOfStock ?? this.isOutOfStock,
        createdAt: createdAt ?? this.createdAt,
        categoryId: identical(categoryId, _noValue)
            ? this.categoryId
            : categoryId as int?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'price': price,
        'sort_order': order,
        'active': active ? 1 : 0,
        'is_out_of_stock': isOutOfStock ? 1 : 0,
        'created_at': createdAt,
        'category_id': categoryId,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        order: map['sort_order'] as int,
        active: (map['active'] as int) == 1,
        isOutOfStock: (map['is_out_of_stock'] as int? ?? 0) == 1,
        createdAt: map['created_at'] as String,
        categoryId: map['category_id'] as int?,
      );

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $price, order: $order, isOutOfStock: $isOutOfStock, categoryId: $categoryId)';
}
