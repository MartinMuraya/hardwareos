import 'quotation_item.dart';

class Quotation {
  final String id;
  final String businessId;
  final String quotationNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final List<QuotationItem> items;
  final double subtotal;
  final double discount;
  final String discountType;
  final double discountAmount;
  final double total;
  final String status;
  final DateTime? validUntil;
  final String notes;
  final String terms;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Quotation({
    required this.id,
    required this.businessId,
    required this.quotationNumber,
    this.customerId = '',
    required this.customerName,
    this.customerPhone = '',
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.discountType = 'fixed',
    this.discountAmount = 0,
    required this.total,
    this.status = 'draft',
    this.validUntil,
    this.notes = '',
    this.terms = '',
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Quotation.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? [];
    return Quotation(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      quotationNumber: (map['quotationNumber'] as String?) ?? '',
      customerId: (map['customerId'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? '',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      items: rawItems.map((e) => QuotationItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
      discount: ((map['discount'] as num?) ?? 0).toDouble(),
      discountType: (map['discountType'] as String?) ?? 'fixed',
      discountAmount: ((map['discountAmount'] as num?) ?? 0).toDouble(),
      total: ((map['total'] as num?) ?? 0).toDouble(),
      status: (map['status'] as String?) ?? 'draft',
      validUntil: map['validUntil'] != null ? DateTime.tryParse(map['validUntil'].toString()) : null,
      notes: (map['notes'] as String?) ?? '',
      terms: (map['terms'] as String?) ?? '',
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Draft';
      case 'sent': return 'Sent';
      case 'accepted': return 'Accepted';
      case 'rejected': return 'Rejected';
      case 'converted': return 'Converted';
      default: return status;
    }
  }

  bool get isConvertible => status == 'accepted';
  bool get isEditable => status == 'draft';
}
