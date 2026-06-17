class StockAdjustment {
  final String id;
  final String businessId;
  final String productId;
  final String productName;
  final int previousQty;
  final int newQty;
  final int difference;
  final String reason;
  final String notes;
  final String adjustedBy;
  final String adjustedByName;
  final DateTime createdAt;

  const StockAdjustment({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.productName,
    required this.previousQty,
    required this.newQty,
    required this.difference,
    required this.reason,
    required this.notes,
    required this.adjustedBy,
    required this.adjustedByName,
    required this.createdAt,
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String? ?? '',
      previousQty: ((map['previousQty'] ?? 0) as num).toInt(),
      newQty: ((map['newQty'] ?? 0) as num).toInt(),
      difference: ((map['difference'] ?? 0) as num).toInt(),
      reason: map['reason'] as String? ?? 'Other',
      notes: map['notes'] as String? ?? '',
      adjustedBy: map['adjustedBy'] as String,
      adjustedByName: map['adjustedByName'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
