class User {
  final String uid;
  final String businessId;
  final String role;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final double? commissionRate;
  final double? commissionBalance;

  const User({
    required this.uid,
    required this.businessId,
    required this.role,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.commissionRate,
    this.commissionBalance,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid:         map['uid'] as String,
      businessId:  map['businessId'] as String,
      role:        map['role'] as String,
      displayName: map['displayName'] as String? ?? '',
      email:       map['email'] as String? ?? '',
      createdAt:   DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      commissionRate: (map['commissionRate'] as num?)?.toDouble(),
      commissionBalance: (map['commissionBalance'] as num?)?.toDouble(),
    );
  }

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager';
  bool get isStaff => role == 'staff';
}
