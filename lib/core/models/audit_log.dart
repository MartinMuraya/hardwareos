class AuditLog {
  final String id;
  final String businessId;
  final String userId;
  final String userName;
  final String module;
  final String action;
  final String entityId;
  final String entityName;
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.userName,
    required this.module,
    required this.action,
    required this.entityId,
    required this.entityName,
    required this.oldValues,
    required this.newValues,
    this.metadata,
    required this.createdAt,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String? ?? '',
      module: map['module'] as String? ?? '',
      action: map['action'] as String? ?? '',
      entityId: map['entityId'] as String? ?? '',
      entityName: map['entityName'] as String? ?? '',
      oldValues: Map<String, dynamic>.from(map['oldValues'] as Map? ?? {}),
      newValues: Map<String, dynamic>.from(map['newValues'] as Map? ?? {}),
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata'] as Map) : null,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
