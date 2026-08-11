import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class PendingStorefrontOrder {
  final String id;
  final Map<String, dynamic> orderData;
  final DateTime createdAt;
  int retryCount;

  PendingStorefrontOrder({
    required this.id,
    required this.orderData,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderData': orderData,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingStorefrontOrder.fromJson(Map<String, dynamic> json) =>
      PendingStorefrontOrder(
        id: json['id'] as String,
        orderData: Map<String, dynamic>.from(json['orderData'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

class ConflictedSale {
  final String id;
  final Map<String, dynamic> saleData;
  final String conflictReason;
  final Map<String, dynamic>? conflictDetails;
  final DateTime conflictedAt;

  ConflictedSale({
    required this.id,
    required this.saleData,
    required this.conflictReason,
    this.conflictDetails,
    required this.conflictedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'saleData': saleData,
        'conflictReason': conflictReason,
        'conflictDetails': conflictDetails,
        'conflictedAt': conflictedAt.toIso8601String(),
      };

  factory ConflictedSale.fromJson(Map<String, dynamic> json) => ConflictedSale(
        id: json['id'] as String,
        saleData: Map<String, dynamic>.from(json['saleData'] as Map),
        conflictReason: json['conflictReason'] as String,
        conflictDetails: json['conflictDetails'] != null
            ? Map<String, dynamic>.from(json['conflictDetails'] as Map)
            : null,
        conflictedAt: DateTime.parse(json['conflictedAt'] as String),
      );
}

class OfflineService {
  static const _salesBoxName = 'offline_sales';
  static const _paymentsBoxName = 'offline_payments';
  static const _inventoryBoxName = 'offline_inventory';
  static const _cartBoxName = 'offline_cart';
  static const _draftBoxName = 'offline_draft';
  static const _customerBoxName = 'offline_customer';
  static const _productsBoxName = 'offline_products';
  static const _storefrontCartBoxName = 'offline_storefront_cart';
  static const _storefrontOrdersBoxName = 'offline_storefront_orders';
  static const _conflictedSalesBoxName = 'offline_conflicted_sales';

  static Box<String>? _salesBox;
  static Box<String>? _paymentsBox;
  static Box<String>? _inventoryBox;
  static Box<String>? _cartBox;
  static Box<String>? _draftBox;
  static Box<String>? _customerBox;
  static Box<String>? _productsBox;
  static Box<String>? _storefrontCartBox;
  static Box<String>? _storefrontOrdersBox;
  static Box<String>? _conflictedSalesBox;

  static Future<void> init() async {
    const secureStorage = FlutterSecureStorage();

    // 1. Obtain or generate encryption key
    final containsEncryptionKey =
        await secureStorage.containsKey(key: 'hive_key');
    if (!containsEncryptionKey) {
      final key = Hive.generateSecureKey();
      await secureStorage.write(
        key: 'hive_key',
        value: base64UrlEncode(key),
      );
    }

    final encryptionKeyString = await secureStorage.read(key: 'hive_key');
    final encryptionKeyUint8List = base64Url.decode(encryptionKeyString!);
    final cipher = HiveAesCipher(encryptionKeyUint8List);

    // 2. Open boxes with encryption. If it fails (e.g., key lost, corrupted, or migrating from unencrypted),
    // we delete the boxes and recreate them to prevent app crashes. If that still fails (e.g. IndexedDB broken), we return null.
    Future<Box<String>?> safeOpenBox(String boxName) async {
      try {
        return await Hive.openBox<String>(boxName, encryptionCipher: cipher);
      } catch (e) {
        debugPrint(
            'Failed to open Hive box $boxName with encryption. Wiping and retrying. Error: $e');
        try {
          await Hive.deleteBoxFromDisk(boxName);
          return await Hive.openBox<String>(boxName, encryptionCipher: cipher);
        } catch (e2) {
          debugPrint(
              'Failed to open Hive box $boxName even after wiping (IndexedDB may be broken). Disabling offline storage for this box. Error: $e2');
          return null;
        }
      }
    }

    _salesBox = await safeOpenBox(_salesBoxName);
    _paymentsBox = await safeOpenBox(_paymentsBoxName);
    _inventoryBox = await safeOpenBox(_inventoryBoxName);
    _cartBox = await safeOpenBox(_cartBoxName);
    _draftBox = await safeOpenBox(_draftBoxName);
    _customerBox = await safeOpenBox(_customerBoxName);
    _productsBox = await safeOpenBox(_productsBoxName);
    _storefrontCartBox = await safeOpenBox(_storefrontCartBoxName);
    _storefrontOrdersBox = await safeOpenBox(_storefrontOrdersBoxName);
    _conflictedSalesBox = await safeOpenBox(_conflictedSalesBoxName);
  }

  static Future<void> clearAll() async {
    await _salesBox?.clear();
    await _paymentsBox?.clear();
    await _inventoryBox?.clear();
    await _cartBox?.clear();
    await _draftBox?.clear();
    await _customerBox?.clear();
    await _productsBox?.clear();
    await _storefrontCartBox?.clear();
    await _storefrontOrdersBox?.clear();
    await _conflictedSalesBox?.clear();
  }

  // ── Cart Persistence ──

  static Future<void> saveCart(List<Map<String, dynamic>> cartItems) async {
    await _cartBox?.put('cart', jsonEncode(cartItems));
  }

  static List<Map<String, dynamic>> loadCart() {
    final raw = _cartBox?.get('cart');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> clearCart() async {
    await _cartBox?.delete('cart');
  }

  // ── Storefront Cart Persistence ──

  static Future<void> saveStorefrontCart(
      String tenantSlug, List<Map<String, dynamic>> cartItems) async {
    await _storefrontCartBox?.put(tenantSlug, jsonEncode(cartItems));
  }

  static List<Map<String, dynamic>> loadStorefrontCart(String tenantSlug) {
    final raw = _storefrontCartBox?.get(tenantSlug);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> clearStorefrontCart(String tenantSlug) async {
    await _storefrontCartBox?.delete(tenantSlug);
  }

  // ── Pending Storefront Orders Queue ──

  static Future<void> enqueueStorefrontOrder(
      PendingStorefrontOrder order) async {
    await _storefrontOrdersBox?.put(order.id, jsonEncode(order.toJson()));
  }

  static List<PendingStorefrontOrder> getPendingStorefrontOrders() {
    return _storefrontOrdersBox?.values
            .map((raw) => PendingStorefrontOrder.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map)))
            .toList() ??
        [];
  }

  static Future<void> removeStorefrontOrder(String id) async {
    await _storefrontOrdersBox?.delete(id);
  }

  static int get pendingStorefrontOrderCount =>
      _storefrontOrdersBox?.length ?? 0;

  // ── Draft Sale ──

  static Future<void> saveDraftSale(
      String id, Map<String, dynamic> draft) async {
    await _draftBox?.put(id, jsonEncode(draft));
  }

  static List<Map<String, dynamic>> getAllDrafts() {
    return _draftBox?.values
            .map((raw) => Map<String, dynamic>.from(jsonDecode(raw) as Map))
            .toList() ??
        [];
  }

  static Future<void> deleteDraftSale(String id) async {
    await _draftBox?.delete(id);
  }

  // ── Customer Selection ──

  static Future<void> saveSelectedCustomer(
      Map<String, dynamic> customer) async {
    await _customerBox?.put('selected', jsonEncode(customer));
  }

  static Map<String, dynamic>? loadSelectedCustomer() {
    final raw = _customerBox?.get('selected');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> clearSelectedCustomer() async {
    await _customerBox?.delete('selected');
  }

  // ── Pending Sales Queue ──

  static Future<void> enqueueSale(PendingSale sale) async {
    await _salesBox?.put(sale.id, jsonEncode(sale.toJson()));
  }

  static List<PendingSale> getPendingSales() {
    return _salesBox?.values
            .map((raw) => PendingSale.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map)))
            .toList() ??
        [];
  }

  static Future<void> removeSale(String id) async {
    await _salesBox?.delete(id);
  }

  static int get pendingSaleCount => _salesBox?.length ?? 0;

  // ── Pending Payments Queue ──

  static Future<void> enqueuePayment(PendingPayment payment) async {
    await _paymentsBox?.put(payment.id, jsonEncode(payment.toJson()));
  }

  static List<PendingPayment> getPendingPayments() {
    return _paymentsBox?.values
            .map((raw) => PendingPayment.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map)))
            .toList() ??
        [];
  }

  static Future<void> removePayment(String id) async {
    await _paymentsBox?.delete(id);
  }

  static int get pendingPaymentCount => _paymentsBox?.length ?? 0;

  // ── Pending Inventory Updates Queue ──

  static Future<void> enqueueInventoryUpdate(
      PendingInventoryUpdate update) async {
    await _inventoryBox?.put(update.id, jsonEncode(update.toJson()));
  }

  static List<PendingInventoryUpdate> getPendingInventoryUpdates() {
    return _inventoryBox?.values
            .map((raw) => PendingInventoryUpdate.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map)))
            .toList() ??
        [];
  }

  static Future<void> removeInventoryUpdate(String id) async {
    await _inventoryBox?.delete(id);
  }

  static int get pendingInventoryCount => _inventoryBox?.length ?? 0;

  // ── Products Cache ──

  static Future<void> saveProducts(List<Map<String, dynamic>> products) async {
    await _productsBox?.put('products', jsonEncode(products));
    await _productsBox?.put('last_sync', DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>> loadProducts() {
    final raw = _productsBox?.get('products');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> clearProducts() async {
    await _productsBox?.delete('products');
    await _productsBox?.delete('last_sync');
  }

  static DateTime? get lastProductSyncAt {
    final raw = _productsBox?.get('last_sync');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── Conflicted Sales Queue ──

  static Future<void> addConflictedSale(ConflictedSale sale) async {
    await _conflictedSalesBox?.put(sale.id, jsonEncode(sale.toJson()));
  }

  static List<ConflictedSale> getConflictedSales() {
    return _conflictedSalesBox?.values
            .map((raw) => ConflictedSale.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map)))
            .toList() ??
        [];
  }

  static Future<void> removeConflictedSale(String id) async {
    await _conflictedSalesBox?.delete(id);
  }

  static int get conflictedSaleCount => _conflictedSalesBox?.length ?? 0;
}
