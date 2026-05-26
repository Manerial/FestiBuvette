class Product {
  final int? id;
  final String name;
  final double price;
  final int order;
  final bool active;
  final String createdAt;

  const Product({
    this.id,
    required this.name,
    required this.price,
    required this.order,
    this.active = true,
    required this.createdAt,
  });

  Product copyWith({
    int? id,
    String? name,
    double? price,
    int? order,
    bool? active,
    String? createdAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        order: order ?? this.order,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'price': price,
        'sort_order': order,
        'active': active ? 1 : 0,
        'created_at': createdAt,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        order: map['sort_order'] as int,
        active: (map['active'] as int) == 1,
        createdAt: map['created_at'] as String,
      );

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $price, order: $order)';
}
