class Plan {
  final String id;
  final String name;
  final int price;
  final String currency;
  final String billingCycle;
  final int maxUsers;
  final List<String> features;

  const Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.billingCycle,
    required this.maxUsers,
    required this.features,
  });

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'] as String,
      name: map['name'] as String,
      price: map['price'] as int,
      currency: map['currency'] as String? ?? 'KES',
      billingCycle: map['billingCycle'] as String? ?? 'monthly',
      maxUsers: map['maxUsers'] as int? ?? -1,
      features: List<String>.from(map['features'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'currency': currency,
    'billingCycle': billingCycle,
    'maxUsers': maxUsers,
    'features': features,
  };
}
