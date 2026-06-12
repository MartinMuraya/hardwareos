class SystemNotification {
  final String id;
  final String type;
  final String businessId;
  final String businessName;
  final String? plan;
  final int? amount;
  final DateTime createdAt;

  const SystemNotification({
    required this.id,
    required this.type,
    required this.businessId,
    required this.businessName,
    this.plan,
    this.amount,
    required this.createdAt,
  });

  factory SystemNotification.fromMap(Map<String, dynamic> map) {
    return SystemNotification(
      id: map['id'] as String,
      type: map['type'] as String,
      businessId: map['businessId'] as String,
      businessName: map['businessName'] as String,
      plan: map['plan'] as String?,
      amount: map['amount'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
