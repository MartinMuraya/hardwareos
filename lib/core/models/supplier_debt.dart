class SupplierDebt {
  final String id;
  final String businessId;
  final String supplierId;
  final String supplierName;
  final String? purchaseOrderId;
  final double totalAmount;
  final double amountPaid;
  final double outstanding;
  final DateTime? paymentDueDate;
  final String status; // 'pending' | 'partial' | 'paid' | 'overdue'
  final DateTime createdAt;

  const SupplierDebt({
    required this.id,
    required this.businessId,
    required this.supplierId,
    required this.supplierName,
    this.purchaseOrderId,
    required this.totalAmount,
    required this.amountPaid,
    required this.outstanding,
    this.paymentDueDate,
    required this.status,
    required this.createdAt,
  });

  bool get isOverdue =>
      status != 'paid' &&
      paymentDueDate != null &&
      DateTime.now().isAfter(paymentDueDate!);

  factory SupplierDebt.fromMap(Map<String, dynamic> map) {
    final total = ((map['totalAmount'] ?? 0) as num).toDouble();
    final paid = ((map['amountPaid'] ?? 0) as num).toDouble();
    final out = ((map['outstanding'] ?? (total - paid)) as num).toDouble();

    return SupplierDebt(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      supplierId: map['supplierId'] as String,
      supplierName: map['supplierName'] as String? ?? 'Unknown Supplier',
      purchaseOrderId: map['purchaseOrderId'] as String?,
      totalAmount: total,
      amountPaid: paid,
      outstanding: out,
      paymentDueDate: DateTime.tryParse(map['paymentDueDate']?.toString() ?? ''),
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'businessId': businessId,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'purchaseOrderId': purchaseOrderId,
    'totalAmount': totalAmount,
    'amountPaid': amountPaid,
    'outstanding': outstanding,
    'paymentDueDate': paymentDueDate?.toIso8601String(),
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}
