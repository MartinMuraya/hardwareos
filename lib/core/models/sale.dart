class SaleItem {
  final String productId;
  final String name;
  final int quantity;
  final double sellingPrice;
  final double costPrice;

  const SaleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.sellingPrice,
    required this.costPrice,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
    productId:    map['productId'] as String,
    name:         map['name'] as String,
    quantity:     ((map['quantity'] ?? 0) as num).toInt(),
    sellingPrice: ((map['sellingPrice'] ?? 0) as num).toDouble(),
    costPrice:    ((map['costPrice'] ?? 0) as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'productId':    productId,
    'name':         name,
    'quantity':     quantity,
    'sellingPrice': sellingPrice,
    'costPrice':    costPrice,
  };

  double get lineTotal  => sellingPrice * quantity;
  double get lineProfit => (sellingPrice - costPrice) * quantity;
}

class Sale {
  final String id;
  final String businessId;
  final List<SaleItem> items;
  final double total;
  final double profit;
  final String paymentMethod;
  final String note;
  final DateTime createdAt;

  const Sale({
    required this.id,
    required this.businessId,
    required this.items,
    required this.total,
    required this.profit,
    required this.paymentMethod,
    required this.note,
    required this.createdAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return Sale(
      id:            map['id'] as String,
      businessId:    map['businessId'] as String,
      items:         rawItems.map((i) => SaleItem.fromMap(Map<String, dynamic>.from(i as Map))).toList(),
      total:         ((map['total'] ?? 0) as num).toDouble(),
      profit:        ((map['profit'] ?? 0) as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      note:          map['note'] as String? ?? '',
      createdAt:     DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
