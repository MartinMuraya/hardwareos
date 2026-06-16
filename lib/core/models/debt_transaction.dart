class DebtTransaction {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String type; // 'credit_sale' | 'debt_payment' | 'debt_adjustment'
  final double amount;
  final String referenceId;
  final double previousBalance;
  final double newBalance;
  final String note;
  final DateTime createdAt;

  const DebtTransaction({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.type,
    required this.amount,
    this.referenceId = '',
    required this.previousBalance,
    required this.newBalance,
    this.note = '',
    required this.createdAt,
  });

  factory DebtTransaction.fromMap(Map<String, dynamic> map) => DebtTransaction(
    id: map['id'] as String,
    businessId: map['businessId'] as String,
    customerId: map['customerId'] as String,
    customerName: (map['customerName'] as String?) ?? '',
    type: map['type'] as String,
    amount: ((map['amount'] as num?) ?? 0).toDouble(),
    referenceId: (map['referenceId'] as String?) ?? '',
    previousBalance: ((map['previousBalance'] as num?) ?? 0).toDouble(),
    newBalance: ((map['newBalance'] as num?) ?? 0).toDouble(),
    note: (map['note'] as String?) ?? '',
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  bool get isIncrease => amount > 0;
  bool get isDecrease => amount < 0;

  String get typeLabel {
    switch (type) {
      case 'credit_sale': return 'Credit Sale';
      case 'debt_payment': return 'Debt Payment';
      case 'debt_adjustment': return 'Adjustment';
      default: return type;
    }
  }
}
