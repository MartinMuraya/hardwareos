class CashSession {
  final String id;
  final String businessId;
  final String? branchId;
  final String openedBy;
  final String openedByName;
  final double openingFloat;
  final double cashSales;
  final double cashRefunds;
  final double expectedCash;
  final double actualCash;
  final double variance;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status;

  const CashSession({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.openedBy,
    required this.openedByName,
    required this.openingFloat,
    required this.cashSales,
    required this.cashRefunds,
    required this.expectedCash,
    required this.actualCash,
    required this.variance,
    required this.openedAt,
    this.closedAt,
    required this.status,
  });

  factory CashSession.fromMap(Map<String, dynamic> map) {
    return CashSession(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String?,
      openedBy: map['openedBy'] as String,
      openedByName: map['openedByName'] as String? ?? '',
      openingFloat: ((map['openingFloat'] ?? 0) as num).toDouble(),
      cashSales: ((map['cashSales'] ?? 0) as num).toDouble(),
      cashRefunds: ((map['cashRefunds'] ?? 0) as num).toDouble(),
      expectedCash: ((map['expectedCash'] ?? 0) as num).toDouble(),
      actualCash: ((map['actualCash'] ?? 0) as num).toDouble(),
      variance: ((map['variance'] ?? 0) as num).toDouble(),
      openedAt: DateTime.tryParse(map['openedAt']?.toString() ?? '') ?? DateTime.now(),
      closedAt: map['closedAt'] != null ? DateTime.tryParse(map['closedAt'].toString()) : null,
      status: map['status'] as String? ?? 'open',
    );
  }

  bool get isOpen => status == 'open';
}
