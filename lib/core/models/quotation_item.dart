class QuotationItem {
  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;

  const QuotationItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory QuotationItem.fromMap(Map<String, dynamic> map) => QuotationItem(
    productId: (map['productId'] as String?) ?? '',
    name: map['name'] as String,
    quantity: ((map['quantity'] as num?) ?? 0).toInt(),
    unitPrice: ((map['unitPrice'] as num?) ?? 0).toDouble(),
    total: ((map['total'] as num?) ?? 0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'total': total,
  };
}
