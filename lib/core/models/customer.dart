class Customer {
  final String id;
  final String businessId;
  final String fullName;
  final String phoneNumber;
  final String nationalId;
  final double creditLimit;
  final double currentBalance;
  final double totalDebt;
  final bool isFundi;
  final double loyaltyPoints;
  final DateTime? paymentDueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.businessId,
    required this.fullName,
    required this.phoneNumber,
    this.nationalId = '',
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.totalDebt = 0,
    this.isFundi = false,
    this.loyaltyPoints = 0,
    this.paymentDueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'] as String,
    businessId: map['businessId'] as String,
    fullName: map['fullName'] as String,
    phoneNumber: map['phoneNumber'] as String,
    nationalId: (map['nationalId'] as String?) ?? '',
    creditLimit: ((map['creditLimit'] as num?) ?? 0).toDouble(),
    currentBalance: ((map['currentBalance'] as num?) ?? 0).toDouble(),
    totalDebt: ((map['totalDebt'] as num?) ?? 0).toDouble(),
    isFundi: (map['isFundi'] as bool?) ?? false,
    loyaltyPoints: ((map['loyaltyPoints'] as num?) ?? 0).toDouble(),
    paymentDueDate: map['paymentDueDate'] != null ? DateTime.parse(map['paymentDueDate'] as String) : null,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'businessId': businessId,
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'nationalId': nationalId,
    'creditLimit': creditLimit,
    'currentBalance': currentBalance,
    'totalDebt': totalDebt,
    'isFundi': isFundi,
    'loyaltyPoints': loyaltyPoints,
    'paymentDueDate': paymentDueDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  bool get isOverLimit => creditLimit > 0 && currentBalance > creditLimit;

  double get availableCredit => creditLimit > 0
      ? (creditLimit - currentBalance).clamp(0, creditLimit)
      : double.infinity;
}
