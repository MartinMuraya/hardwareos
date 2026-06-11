class Business {
  final String id;
  final String name;
  final String plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndsAt;
  final String ownerId;
  final DateTime createdAt;

  const Business({
    required this.id,
    required this.name,
    required this.plan,
    required this.subscriptionStatus,
    this.trialEndsAt,
    this.subscriptionEndsAt,
    required this.ownerId,
    required this.createdAt,
  });

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id:                 map['id'] as String,
      name:               map['name'] as String,
      plan:               map['plan'] as String? ?? 'free',
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'trial',
      trialEndsAt:        map['trialEndsAt'] != null
          ? DateTime.tryParse(map['trialEndsAt'].toString())
          : null,
      subscriptionEndsAt: map['subscriptionEndsAt'] != null
          ? DateTime.tryParse(map['subscriptionEndsAt'].toString())
          : null,
      ownerId:   map['ownerId'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isOnTrial   => subscriptionStatus == 'trial';
  bool get isExpired   => subscriptionStatus == 'expired';
  bool get isPro       => plan == 'pro';

  int? get trialDaysLeft {
    if (trialEndsAt == null) return null;
    return trialEndsAt!.difference(DateTime.now()).inDays.clamp(0, 999);
  }
}
