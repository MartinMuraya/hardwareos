class Business {
  final String id;
  final String name;
  final String plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionStartsAt;
  final DateTime? subscriptionEndsAt;
  final DateTime? lastPaymentDate;
  final String ownerId;
  final DateTime createdAt;
  final bool active;

  const Business({
    required this.id,
    required this.name,
    required this.plan,
    required this.subscriptionStatus,
    this.trialEndsAt,
    this.subscriptionStartsAt,
    this.subscriptionEndsAt,
    this.lastPaymentDate,
    required this.ownerId,
    required this.createdAt,
    this.active = true,
  });

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      plan: map['plan'] as String? ?? 'trial',
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'trial',
      trialEndsAt: map['trialEndsAt'] != null
          ? DateTime.tryParse(map['trialEndsAt'].toString())
          : null,
      subscriptionStartsAt: map['subscriptionStartsAt'] != null
          ? DateTime.tryParse(map['subscriptionStartsAt'].toString())
          : null,
      subscriptionEndsAt: map['subscriptionEndsAt'] != null
          ? DateTime.tryParse(map['subscriptionEndsAt'].toString())
          : null,
      lastPaymentDate: map['lastPaymentDate'] != null
          ? DateTime.tryParse(map['lastPaymentDate'].toString())
          : null,
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      active: map['active'] as bool? ?? true,
    );
  }

  bool get isOnTrial   => subscriptionStatus == 'trial';
  bool get isExpired   => subscriptionStatus == 'expired';
  bool get isActive    => subscriptionStatus == 'active';
  bool get isPro       => plan == 'pro';
  bool get isStarter   => plan == 'starter';

  int? get trialDaysLeft {
    if (trialEndsAt == null) return null;
    final now = DateTime.now();
    return trialEndsAt!.isAfter(now) ? trialEndsAt!.difference(now).inDays.clamp(0, 999) : 0;
  }

  int? get subscriptionDaysLeft {
    if (subscriptionEndsAt == null) return null;
    final now = DateTime.now();
    return subscriptionEndsAt!.isAfter(now) ? subscriptionEndsAt!.difference(now).inDays.clamp(0, 999) : 0;
  }
}
