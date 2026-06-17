class ReturnItem {
  final String productId;
  final String name;
  final int quantity;
  final double sellingPrice;
  final double costPrice;

  const ReturnItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.sellingPrice,
    required this.costPrice,
  });

  factory ReturnItem.fromMap(Map<String, dynamic> map) => ReturnItem(
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
}

class ReturnRecord {
  final String id;
  final String businessId;
  final String saleId;
  final String customerId;
  final String customerName;
  final List<ReturnItem> items;
  final double subtotal;
  final double refundAmount;
  final String reason;
  final String notes;
  final String processedBy;
  final String processedByName;
  final DateTime createdAt;

  const ReturnRecord({
    required this.id,
    required this.businessId,
    required this.saleId,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.subtotal,
    required this.refundAmount,
    required this.reason,
    required this.notes,
    required this.processedBy,
    required this.processedByName,
    required this.createdAt,
  });

  factory ReturnRecord.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return ReturnRecord(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      saleId: map['saleId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      items: rawItems.map((i) => ReturnItem.fromMap(Map<String, dynamic>.from(i as Map))).toList(),
      subtotal: ((map['subtotal'] ?? 0) as num).toDouble(),
      refundAmount: ((map['refundAmount'] ?? 0) as num).toDouble(),
      reason: map['reason'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      processedBy: map['processedBy'] as String,
      processedByName: map['processedByName'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
