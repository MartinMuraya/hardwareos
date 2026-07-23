class InventoryLedgerEntry {
  final String id;
  final String businessId;
  final String? branchId;
  final String productId;
  final String productName;
  final String movementType;
  final double quantity;
  final double costAtTime;
  final String referenceId;
  final String performedBy;
  final String? reason;
  final DateTime timestamp;

  InventoryLedgerEntry({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantity,
    required this.costAtTime,
    required this.referenceId,
    required this.performedBy,
    this.reason,
    required this.timestamp,
  });

  factory InventoryLedgerEntry.fromMap(Map<String, dynamic> map) {
    return InventoryLedgerEntry(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      branchId: map['branchId'],
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? 'Unknown',
      movementType: map['movementType'] ?? 'OPENING_BALANCE',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      costAtTime: (map['costAtTime'] as num?)?.toDouble() ?? 0,
      referenceId: map['referenceId'] ?? '',
      performedBy: map['performedBy'] ?? '',
      reason: map['reason'],
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp']) 
          : DateTime.now(),
    );
  }
}
