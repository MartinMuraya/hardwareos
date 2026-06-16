class PurchaseOrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double unitCost;
  final double total;

  const PurchaseOrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitCost,
    required this.total,
  });

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) => PurchaseOrderItem(
    productId: (map['productId'] as String?) ?? '',
    name: map['name'] as String,
    quantity: ((map['quantity'] as num?) ?? 0).toInt(),
    unitCost: ((map['unitCost'] as num?) ?? 0).toDouble(),
    total: ((map['total'] as num?) ?? 0).toDouble(),
  );
}

class PurchaseOrder {
  final String id;
  final String businessId;
  final String poNumber;
  final String supplierId;
  final String supplierName;
  final List<PurchaseOrderItem> items;
  final double subtotal;
  final double total;
  final String status;
  final String notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? receivedAt;

  const PurchaseOrder({
    required this.id,
    required this.businessId,
    required this.poNumber,
    this.supplierId = '',
    required this.supplierName,
    required this.items,
    required this.subtotal,
    required this.total,
    this.status = 'draft',
    this.notes = '',
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.receivedAt,
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? [];
    return PurchaseOrder(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      poNumber: (map['poNumber'] as String?) ?? '',
      supplierId: (map['supplierId'] as String?) ?? '',
      supplierName: (map['supplierName'] as String?) ?? '',
      items: rawItems.map((e) => PurchaseOrderItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
      total: ((map['total'] as num?) ?? 0).toDouble(),
      status: (map['status'] as String?) ?? 'draft',
      notes: (map['notes'] as String?) ?? '',
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      receivedAt: map['receivedAt'] != null ? DateTime.tryParse(map['receivedAt'].toString()) : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Draft';
      case 'sent': return 'Sent';
      case 'received': return 'Received';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  bool get isReceivable => status == 'draft' || status == 'sent';
  bool get isEditable => status == 'draft';
}
