class Supplier {
  final String id;
  final String businessId;
  final String name;
  final String phoneNumber;
  final String email;
  final String address;
  final String contactPerson;
  final String paymentTerms;
  final double currentBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phoneNumber,
    this.email = '',
    this.address = '',
    this.contactPerson = '',
    this.paymentTerms = '30 days',
    this.currentBalance = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
    id: map['id'] as String,
    businessId: map['businessId'] as String,
    name: map['name'] as String,
    phoneNumber: map['phoneNumber'] as String,
    email: (map['email'] as String?) ?? '',
    address: (map['address'] as String?) ?? '',
    contactPerson: (map['contactPerson'] as String?) ?? '',
    paymentTerms: (map['paymentTerms'] as String?) ?? '30 days',
    currentBalance: ((map['currentBalance'] as num?) ?? 0).toDouble(),
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}
