class Branch {
  final String id;
  final String businessId;
  final String name;
  final String address;
  final String? managerId;
  final String phone;
  final bool active;
  final DateTime createdAt;

  const Branch({
    required this.id,
    required this.businessId,
    required this.name,
    required this.address,
    this.managerId,
    required this.phone,
    required this.active,
    required this.createdAt,
  });

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      managerId: map['managerId'] as String?,
      phone: map['phone'] as String? ?? '',
      active: map['active'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class StockTransfer {
  final String id;
  final String businessId;
  final String fromBranchId;
  final String toBranchId;
  final String productId;
  final String productName;
  final int quantity;
  final String status;
  final String requestedBy;
  final String requestedByName;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime createdAt;
  final DateTime? completedAt;

  const StockTransfer({
    required this.id,
    required this.businessId,
    required this.fromBranchId,
    required this.toBranchId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.status,
    required this.requestedBy,
    required this.requestedByName,
    this.approvedBy,
    this.approvedByName,
    required this.createdAt,
    this.completedAt,
  });

  factory StockTransfer.fromMap(Map<String, dynamic> map) {
    return StockTransfer(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      fromBranchId: map['fromBranchId'] as String,
      toBranchId: map['toBranchId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String? ?? '',
      quantity: ((map['quantity'] ?? 0) as num).toInt(),
      status: map['status'] as String? ?? 'pending',
      requestedBy: map['requestedBy'] as String,
      requestedByName: map['requestedByName'] as String? ?? '',
      approvedBy: map['approvedBy'] as String?,
      approvedByName: map['approvedByName'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null,
    );
  }

  bool get isPending => status == 'pending';
}
