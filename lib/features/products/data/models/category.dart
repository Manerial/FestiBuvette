class Category {
  final int? id;
  final String name;
  final int order;

  const Category({this.id, required this.name, required this.order});

  Category copyWith({int? id, String? name, int? order}) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    order: order ?? this.order,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'sort_order': order,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as int?,
    name: map['name'] as String,
    order: map['sort_order'] as int,
  );

  @override
  String toString() => 'Category(id: $id, name: $name, order: $order)';
}
