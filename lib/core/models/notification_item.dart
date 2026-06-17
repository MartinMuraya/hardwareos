class NotificationItem {
  final String id;
  final String businessId;
  final String type;
  final String recipient;
  final String message;
  final String status;
  final DateTime createdAt;
  final DateTime? sentAt;
  final String? error;

  const NotificationItem({
    required this.id,
    required this.businessId,
    required this.type,
    required this.recipient,
    required this.message,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.error,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      type: map['type'] as String? ?? '',
      recipient: map['recipient'] as String? ?? '',
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      sentAt: map['sentAt'] != null ? DateTime.tryParse(map['sentAt'].toString()) : null,
      error: map['error'] as String?,
    );
  }
}

class NotificationSettings {
  final bool debtReminders;
  final bool lowStockAlerts;
  final bool paymentNotifications;
  final bool quotationNotifications;
  final String provider;

  const NotificationSettings({
    this.debtReminders = true,
    this.lowStockAlerts = true,
    this.paymentNotifications = true,
    this.quotationNotifications = true,
    this.provider = 'meta_whatsapp',
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      debtReminders: map['debtReminders'] as bool? ?? true,
      lowStockAlerts: map['lowStockAlerts'] as bool? ?? true,
      paymentNotifications: map['paymentNotifications'] as bool? ?? true,
      quotationNotifications: map['quotationNotifications'] as bool? ?? true,
      provider: map['provider'] as String? ?? 'meta_whatsapp',
    );
  }

  Map<String, dynamic> toMap() => {
    'debtReminders': debtReminders,
    'lowStockAlerts': lowStockAlerts,
    'paymentNotifications': paymentNotifications,
    'quotationNotifications': quotationNotifications,
    'provider': provider,
  };
}
