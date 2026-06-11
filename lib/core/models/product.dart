class Product {
  final String id;
  final String businessId;
  final String name;
  final String sku;
  final String category;
  final int quantity;
  final double costPrice;
  final double sellingPrice;
  final int reorderLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    required this.reorderLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id:           map['id'] as String,
      businessId:   map['businessId'] as String,
      name:         map['name'] as String,
      sku:          map['sku'] as String? ?? '',
      category:     map['category'] as String? ?? 'General',
      quantity:     (map['quantity'] as num).toInt(),
      costPrice:    (map['costPrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      reorderLevel: (map['reorderLevel'] as num).toInt(),
      createdAt:    DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt:    DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  double get margin =>
      sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;

  bool get isLowStock    => quantity <= reorderLevel && quantity > 0;
  bool get isOutOfStock  => quantity <= 0;
  bool get isCritical    => quantity <= (reorderLevel * 0.5).ceil();

  Product copyWith({int? quantity}) {
    return Product(
      id: id, businessId: businessId, name: name, sku: sku,
      category: category, costPrice: costPrice, sellingPrice: sellingPrice,
      reorderLevel: reorderLevel, createdAt: createdAt, updatedAt: updatedAt,
      quantity: quantity ?? this.quantity,
    );
  }
}
