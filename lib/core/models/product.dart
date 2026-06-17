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
  final bool isBulkParent;
  final bool isBulkChild;
  final String? parentProductId;
  final double? conversionRatio;
  final String? baseUnit;
  final String? sellingUnit;
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
    this.isBulkParent = false,
    this.isBulkChild = false,
    this.parentProductId,
    this.conversionRatio,
    this.baseUnit,
    this.sellingUnit,
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
      quantity:     ((map['quantity'] ?? 0) as num).toInt(),
      costPrice:    ((map['costPrice'] ?? map['buyingPrice'] ?? 0) as num).toDouble(),
      sellingPrice: ((map['sellingPrice'] ?? 0) as num).toDouble(),
      reorderLevel: ((map['reorderLevel'] ?? 0) as num).toInt(),
      isBulkParent: map['isBulkParent'] == true,
      isBulkChild: map['isBulkChild'] == true,
      parentProductId: map['parentProductId'] as String?,
      conversionRatio: (map['conversionRatio'] as num?)?.toDouble(),
      baseUnit: map['baseUnit'] as String?,
      sellingUnit: map['sellingUnit'] as String?,
      createdAt:    DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt:    DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  double get margin =>
      sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;

  bool get isLowStock    => quantity <= reorderLevel && quantity > 0;
  bool get isOutOfStock  => quantity <= 0;
  bool get isCritical    => quantity <= (reorderLevel * 0.5).ceil();

  String get bulkLabel {
    if (isBulkParent) return 'Bulk Parent';
    if (isBulkChild) return 'Bulk Child';
    return '';
  }

  Product copyWith({int? quantity}) {
    return Product(
      id: id, businessId: businessId, name: name, sku: sku,
      category: category, costPrice: costPrice, sellingPrice: sellingPrice,
      reorderLevel: reorderLevel, createdAt: createdAt, updatedAt: updatedAt,
      quantity: quantity ?? this.quantity,
      isBulkParent: isBulkParent, isBulkChild: isBulkChild,
      parentProductId: parentProductId, conversionRatio: conversionRatio,
      baseUnit: baseUnit, sellingUnit: sellingUnit,
    );
  }
}
