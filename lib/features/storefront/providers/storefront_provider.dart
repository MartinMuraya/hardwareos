import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/services/offline_service.dart';
import '../models/storefront_models.dart';

class StorefrontProvider extends ChangeNotifier {
  final String tenantSlug;

  StorefrontInfo? _storeInfo;
  List<StorefrontProduct> _products = [];
  List<String> _categories = [];
  List<StorefrontCartItem> _cart = [];
  
  bool _isLoading = true;
  String? _error;

  StorefrontProvider({required this.tenantSlug}) {
    _init();
  }

  StorefrontInfo? get storeInfo => _storeInfo;
  List<StorefrontProduct> get products => _products;
  List<String> get categories => _categories;
  List<StorefrontCartItem> get cart => _cart;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DeliveryZone? _selectedZone;
  DeliveryZone? get selectedZone => _selectedZone;

  void setDeliveryZone(DeliveryZone? zone) {
    _selectedZone = zone;
    notifyListeners();
  }

  double get cartSubtotal => _cart.fold(0, (sum, item) => sum + (item.product.sellingPrice * item.quantity));
  double get cartTotal => cartSubtotal + (_selectedZone?.fee ?? 0.0);
  int get cartItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch store info
      final storeRes = await FunctionsService.call('getPublicStorefront', {'tenantSlug': tenantSlug});
      _storeInfo = StorefrontInfo.fromJson(Map<String, dynamic>.from(storeRes));

      if (_storeInfo!.active) {
        // 2. Fetch products
        final prodRes = await FunctionsService.call('getPublicProducts', {'businessId': _storeInfo!.businessId});
        final pList = (prodRes['products'] as List).map((e) => StorefrontProduct.fromJson(Map<String, dynamic>.from(e))).toList();
        _products = pList;

        // 3. Fetch categories
        final catRes = await FunctionsService.call('getStorefrontCategories', {'businessId': _storeInfo!.businessId});
        _categories = (catRes['categories'] as List).map((e) => e.toString()).toList();
        _categories.insert(0, 'All');

        // 4. Load offline cart
        final savedCart = OfflineService.loadStorefrontCart(tenantSlug);
        _cart = savedCart.map((e) => StorefrontCartItem.fromJson(e)).toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addToCart(StorefrontProduct product, [int quantity = 1]) {
    if (!product.inStock) return;

    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(StorefrontCartItem(product: product, quantity: quantity));
    }
    _saveCart();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cart[index].quantity = quantity;
      _saveCart();
    }
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    _saveCart();
  }

  void clearCart() {
    _cart.clear();
    _saveCart();
  }

  Future<void> _saveCart() async {
    notifyListeners();
    await OfflineService.saveStorefrontCart(
      tenantSlug, 
      _cart.map((e) => e.toJson()).toList()
    );
  }

  Future<void> checkout({
    required String customerName,
    required String customerPhone,
    required String address,
    String? note,
  }) async {
    if (_cart.isEmpty || _storeInfo == null) return;

    final itemsPayload = _cart.map((item) => {
      'productId': item.product.id,
      'quantity': item.quantity,
    }).toList();

    final orderData = {
      'businessId': _storeInfo!.businessId,
      'items': itemsPayload,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'address': address,
      'note': note,
      'deliveryZoneId': _selectedZone?.id,
      'deliveryFee': _selectedZone?.fee ?? 0.0,
      'total': cartTotal,
      'triggerMpesa': true, // The backend will trigger STK push
    };

    try {
      // Attempt online checkout. Backend should return orderId and stk_push status
      await FunctionsService.call('createOnlineOrder', orderData);
      clearCart();
    } on FunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw Exception('Network error. Cannot initiate M-Pesa payment right now.');
      } else {
        rethrow;
      }
    }
  }

  // Called periodically or on connectivity restored
  static Future<void> syncPendingOrders() async {
    final pending = OfflineService.getPendingStorefrontOrders();
    for (final order in pending) {
      try {
        await FunctionsService.call('createOnlineOrder', order.orderData);
        await OfflineService.removeStorefrontOrder(order.id);
      } on FunctionsException catch (e) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          order.retryCount++;
          await OfflineService.enqueueStorefrontOrder(order);
          await OfflineService.removeStorefrontOrder(order.id);
        } else {
          // If it fails for business logic (e.g. out of stock), we might want to flag it as error
          await OfflineService.removeStorefrontOrder(order.id);
        }
      }
    }
  }
}
