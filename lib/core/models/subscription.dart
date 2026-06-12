class Subscription {
  final String id;
  final String businessId;
  final String businessName;
  final String ownerUid;
  final String plan;
  final int amount;
  final String currency;
  final String phoneNumber;
  final String transactionStatus;
  final String mpesaReceipt;
  final String checkoutRequestId;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? expiresAt;

  const Subscription({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerUid,
    required this.plan,
    required this.amount,
    required this.currency,
    required this.phoneNumber,
    required this.transactionStatus,
    required this.mpesaReceipt,
    required this.checkoutRequestId,
    required this.createdAt,
    this.paidAt,
    this.expiresAt,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      plan: map['plan'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'KES',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      transactionStatus: map['transactionStatus'] as String? ?? 'pending',
      mpesaReceipt: map['mpesaReceipt'] as String? ?? '',
      checkoutRequestId: map['checkoutRequestId'] as String? ?? '',
      createdAt: _parseDateTimeRequired(map['createdAt']),
      paidAt: _parseDateTime(map['paidAt']),
      expiresAt: _parseDateTime(map['expiresAt']),
    );
  }

  static DateTime _parseDateTimeRequired(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool get isPending => transactionStatus == 'pending';
  bool get isCompleted => transactionStatus == 'completed';
  bool get isFailed => transactionStatus == 'failed';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
}