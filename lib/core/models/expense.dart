class Expense {
  final String id;
  final String businessId;
  final String category;
  final double amount;
  final String note;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.businessId,
    required this.category,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id:         map['id'] as String,
    businessId: map['businessId'] as String,
    category:   map['category'] as String,
    amount:     ((map['amount'] ?? 0) as num).toDouble(),
    note:       map['note'] as String? ?? map['description'] as String? ?? '',
    createdAt:  DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}
