import 'dart:convert';
import 'package:hive/hive.dart';

class PendingSale {
  final String id;
  final Map<String, dynamic> saleData;
  final DateTime createdAt;
  int retryCount;

  PendingSale({
    required this.id,
    required this.saleData,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'saleData': saleData,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingSale.fromJson(Map<String, dynamic> json) => PendingSale(
    id: json['id'] as String,
    saleData: Map<String, dynamic>.from(json['saleData'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );
}

class PendingPayment {
  final String id;
  final Map<String, dynamic> paymentData;
  final DateTime createdAt;
  int retryCount;

  PendingPayment({
    required this.id,
    required this.paymentData,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'paymentData': paymentData,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingPayment.fromJson(Map<String, dynamic> json) => PendingPayment(
    id: json['id'] as String,
    paymentData: Map<String, dynamic>.from(json['paymentData'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );
}

class PendingInventoryUpdate {
  final String id;
  final Map<String, dynamic> updateData;
  final DateTime createdAt;
  int retryCount;

  PendingInventoryUpdate({
    required this.id,
    required this.updateData,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'updateData': updateData,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingInventoryUpdate.fromJson(Map<String, dynamic> json) =>
    PendingInventoryUpdate(
      id: json['id'] as String,
      updateData: Map<String, dynamic>.from(json['updateData'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
}

class OfflineService {
  static const _salesBoxName = 'offline_sales';
  static const _paymentsBoxName = 'offline_payments';
  static const _inventoryBoxName = 'offline_inventory';
  static const _cartBoxName = 'offline_cart';
  static const _draftBoxName = 'offline_draft';
  static const _customerBoxName = 'offline_customer';

  static late Box<String> _salesBox;
  static late Box<String> _paymentsBox;
  static late Box<String> _inventoryBox;
  static late Box<String> _cartBox;
  static late Box<String> _draftBox;
  static late Box<String> _customerBox;

  static Future<void> init() async {
    _salesBox = await Hive.openBox<String>(_salesBoxName);
    _paymentsBox = await Hive.openBox<String>(_paymentsBoxName);
    _inventoryBox = await Hive.openBox<String>(_inventoryBoxName);
    _cartBox = await Hive.openBox<String>(_cartBoxName);
    _draftBox = await Hive.openBox<String>(_draftBoxName);
    _customerBox = await Hive.openBox<String>(_customerBoxName);
  }

  static Future<void> clearAll() async {
    await _salesBox.clear();
    await _paymentsBox.clear();
    await _inventoryBox.clear();
    await _cartBox.clear();
    await _draftBox.clear();
    await _customerBox.clear();
  }

  // ── Cart Persistence ──

  static Future<void> saveCart(List<Map<String, dynamic>> cartItems) async {
    await _cartBox.put('cart', jsonEncode(cartItems));
  }

  static List<Map<String, dynamic>> loadCart() {
    final raw = _cartBox.get('cart');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> clearCart() async {
    await _cartBox.delete('cart');
  }

  // ── Draft Sale ──

  static Future<void> saveDraftSale(Map<String, dynamic> draft) async {
    await _draftBox.put('draft', jsonEncode(draft));
  }

  static Map<String, dynamic>? loadDraftSale() {
    final raw = _draftBox.get('draft');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> clearDraftSale() async {
    await _draftBox.delete('draft');
  }

  // ── Customer Selection ──

  static Future<void> saveSelectedCustomer(Map<String, dynamic> customer) async {
    await _customerBox.put('selected', jsonEncode(customer));
  }

  static Map<String, dynamic>? loadSelectedCustomer() {
    final raw = _customerBox.get('selected');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> clearSelectedCustomer() async {
    await _customerBox.delete('selected');
  }

  // ── Pending Sales Queue ──

  static Future<void> enqueueSale(PendingSale sale) async {
    await _salesBox.put(sale.id, jsonEncode(sale.toJson()));
  }

  static List<PendingSale> getPendingSales() {
    return _salesBox.values.map((raw) =>
      PendingSale.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map))
    ).toList();
  }

  static Future<void> removeSale(String id) async {
    await _salesBox.delete(id);
  }

  static int get pendingSaleCount => _salesBox.length;

  // ── Pending Payments Queue ──

  static Future<void> enqueuePayment(PendingPayment payment) async {
    await _paymentsBox.put(payment.id, jsonEncode(payment.toJson()));
  }

  static List<PendingPayment> getPendingPayments() {
    return _paymentsBox.values.map((raw) =>
      PendingPayment.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map))
    ).toList();
  }

  static Future<void> removePayment(String id) async {
    await _paymentsBox.delete(id);
  }

  static int get pendingPaymentCount => _paymentsBox.length;

  // ── Pending Inventory Updates Queue ──

  static Future<void> enqueueInventoryUpdate(PendingInventoryUpdate update) async {
    await _inventoryBox.put(update.id, jsonEncode(update.toJson()));
  }

  static List<PendingInventoryUpdate> getPendingInventoryUpdates() {
    return _inventoryBox.values.map((raw) =>
      PendingInventoryUpdate.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map))
    ).toList();
  }

  static Future<void> removeInventoryUpdate(String id) async {
    await _inventoryBox.delete(id);
  }

  static int get pendingInventoryCount => _inventoryBox.length;
}
