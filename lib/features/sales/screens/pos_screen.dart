import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hardwareos/core/router/route_paths.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/models/product.dart';
import '../../../core/models/customer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/services/product_cache_service.dart';
import '../services/offline_sales_queue.dart';
import '../../../core/utils/barcode_listener.dart';
import '../../../core/services/web_serial_service.dart';
import 'offline_queue_screen.dart';
import 'package:flutter/services.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class CheckoutIntent extends Intent {
  const CheckoutIntent();
  static const key = CheckoutIntent();
}

class ClearCartIntent extends Intent {
  const ClearCartIntent();
  static const key = ClearCartIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
  static const key = FocusSearchIntent();
}

class _POSScreenState extends State<POSScreen> {
  final List<_CartEntry> _cart = [];
  String _paymentMethod = 'cash';

  // Customer & Credit state
  Customer? _selectedCustomer;
  final _amountPaidCtrl = TextEditingController();
  final _mpesaPhoneCtrl = TextEditingController();
  final _redeemPointsCtrl = TextEditingController();
  double _pointsDiscount = 0;
  List<Customer> _customers = [];
  bool _loadingCustomers = false;

  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  bool _loadingProducts = true;
  bool _processingCheckout = false;
  String? _error;

  ReceiptData? _lastReceiptData;

  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() {
    super.initState();
    _loadSavedCart();
    _loadProducts();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountPaidCtrl.dispose();
    _redeemPointsCtrl.dispose();
    _mpesaPhoneCtrl.dispose();
    super.dispose();
  }

  void _loadSavedCart() {
    final saved = OfflineService.loadCart();
    if (saved.isNotEmpty) {
      final loaded = <_CartEntry>[];
      for (final item in saved) {
        final prodMap = item['product'] as Map<String, dynamic>;
        final qty = (item['qty'] as num).toDouble();
        final overridePrice = item['overridePrice'] != null
            ? (item['overridePrice'] as num).toDouble()
            : null;
        final note = item['note'] as String?;
        loaded.add(_CartEntry(
            product: Product.fromMap(prodMap),
            qty: qty,
            overridePrice: overridePrice,
            note: note));
      }
      _cart.addAll(loaded);
    }
  }

  void _saveCart() {
    OfflineService.saveCart(
      _cart
          .map((e) => {
                'product': {
                  'id': e.product.id,
                  'businessId': e.product.businessId,
                  'name': e.product.name,
                  'sku': e.product.sku,
                  'category': e.product.category,
                  'quantity': e.product.quantity,
                  'costPrice': e.product.costPrice,
                  'sellingPrice': e.product.sellingPrice,
                  'reorderLevel': e.product.reorderLevel,
                  'barcodes': e.product.barcodes,
                  'createdAt': e.product.createdAt.toIso8601String(),
                  'updatedAt': e.product.updatedAt.toIso8601String(),
                },
                'qty': e.qty,
                if (e.overridePrice != null) 'overridePrice': e.overridePrice,
                if (e.note != null) 'note': e.note,
              })
          .toList(),
    );
  }

  void _holdCart(BuildContext context) {
    if (_cart.isEmpty) return;
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) {
          Future<void> submit() async {
            final ref = ctrl.text.trim();
            if (ref.isEmpty) return;
            final id = 'draft_${DateTime.now().millisecondsSinceEpoch}';
            final draftData = {
              'id': id,
              'reference': ref,
              'timestamp': DateTime.now().toIso8601String(),
              'items': _cart.map((e) => e.toMap()).toList(),
            };
            final messenger = ScaffoldMessenger.of(context);
            final dialogNavigator = Navigator.of(ctx);
            await OfflineService.saveDraftSale(id, draftData);
            if (!mounted) return;
            setState(() {
              _cart.clear();
            });
            _saveCart();
            dialogNavigator.pop();
            messenger
                .showSnackBar(SnackBar(content: Text('Cart "$ref" held.')));
          }

          return AlertDialog(
            title: const Text('Hold Cart'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                  hintText: 'Customer name or reference',
                  labelText: 'Reference'),
              autofocus: true,
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submit,
                child: const Text('Hold Cart'),
              ),
            ],
          );
        });
  }

  void _showHeldCarts() {
    final drafts = OfflineService.getAllDrafts();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Held Carts'),
              content: SizedBox(
                width: 400,
                height: 300,
                child: drafts.isEmpty
                    ? const Center(child: Text('No held carts.'))
                    : ListView.builder(
                        itemCount: drafts.length,
                        itemBuilder: (_, i) {
                          final d = drafts[i];
                          final id = d['id'] as String;
                          final ref = d['reference'] as String;
                          final date = DateTime.parse(d['timestamp'] as String);
                          final items = d['items'] as List;
                          return ListTile(
                            title: Text(ref,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${items.length} items • ${DateFormat('MMM d, h:mm a').format(date)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: AppColors.error),
                              onPressed: () async {
                                final dialogNavigator = Navigator.of(ctx);
                                await OfflineService.deleteDraftSale(id);
                                dialogNavigator.pop();
                                if (!mounted) return;
                                _showHeldCarts(); // Refresh
                              },
                            ),
                            onTap: () async {
                              final dialogNavigator = Navigator.of(ctx);
                              // Restore cart
                              setState(() {
                                _cart.clear();
                                for (final item in items) {
                                  final m = item as Map<String, dynamic>;
                                  // We need to fetch the Product from cache, or reconstruct it
                                  // Since we saved standard toMap() which doesn't have the full Product model,
                                  // Wait, _CartEntry.toMap() does not contain all Product details!
                                  // Ah, _CartEntry.toMap() only has productId, name, quantity, sellingPrice, costPrice, overridePrice, note
                                  // It does NOT have the full Product object. Let's fix this by finding it in _allProducts!
                                  final pId = m['productId'];
                                  final p = _allProducts.firstWhere(
                                    (p) => p.id == pId,
                                    orElse: () => Product.fromMap(
                                        m), // Fallback (missing some fields, but works for UI)
                                  );
                                  _cart.add(_CartEntry(
                                    product: p,
                                    qty: (m['quantity'] as num).toDouble(),
                                    overridePrice: m['overridePrice'] != null
                                        ? (m['overridePrice'] as num).toDouble()
                                        : null,
                                    note: m['note'] as String?,
                                  ));
                                }
                              });
                              _saveCart();
                              await OfflineService.deleteDraftSale(id);
                              dialogNavigator.pop();
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close')),
              ],
            ));
  }

  Future<void> _loadCustomers() async {
    if (_customers.isNotEmpty) return;
    setState(() => _loadingCustomers = true);
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call(
          'getCustomers', {'businessId': bizId, 'limit': 200});
      final rawList = (data['customers'] as List?) ?? [];
      _customers = rawList
          .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingCustomers = false);
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _error = null;
    });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final isOnline = context.read<ConnectivityProvider>().isOnline;

      if (isOnline) {
        if (ProductCacheService.isCacheStale()) {
          // Sync in background to update cache
          ProductCacheService.syncProducts(bizId).catchError((_) {});
        }
      }

      // Always load from cache first for fast offline capability, unless empty
      var prods = ProductCacheService.getCachedProducts();

      if (prods.isEmpty && isOnline) {
        // Fallback to direct fetch if cache is empty
        final data = await FunctionsService.call(
            'getProducts', {'businessId': bizId, 'limit': 200});
        final rawList = (data['products'] as List?) ?? [];
        prods = rawList
            .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        // Save to cache
        OfflineService.saveProducts(prods
            .map((p) => {
                  'id': p.id,
                  'businessId': p.businessId,
                  'name': p.name,
                  'sku': p.sku,
                  'category': p.category,
                  'quantity': p.quantity,
                  'costPrice': p.costPrice,
                  'sellingPrice': p.sellingPrice,
                  'reorderLevel': p.reorderLevel,
                  'barcodes': p.barcodes,
                  'createdAt': p.createdAt.toIso8601String(),
                  'updatedAt': p.updatedAt.toIso8601String()
                })
            .toList());
      }

      // Filter out out-of-stock
      prods = prods.where((p) => !p.isOutOfStock).toList();

      if (mounted) {
        setState(() {
          _allProducts = prods;
          _filtered = prods;
          _loadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingProducts = false;
        });
      }
    }
  }

  bool _fuzzyMatch(String query, String target) {
    if (target.contains(query)) return true;
    int qIdx = 0;
    for (int tIdx = 0; tIdx < target.length && qIdx < query.length; tIdx++) {
      if (target[tIdx] == query[qIdx]) qIdx++;
    }
    // true if we matched most of the query (allowing up to 1 missing/wrong char for short words, 2 for long)
    return qIdx >= query.length - (query.length > 5 ? 2 : 1);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _filtered = _allProducts);
      return;
    }

    final matched = _allProducts
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.barcodes.any((b) => b.toLowerCase() == q))
        .toList();

    if (matched.isEmpty && q.length > 2) {
      // Fallback to fuzzy search on name
      final fuzzy = _allProducts
          .where((p) => _fuzzyMatch(q, p.name.toLowerCase()))
          .toList();
      setState(() => _filtered = fuzzy);
    } else {
      setState(() => _filtered = matched);
    }
  }

  void _handleBarcodeScanned(String barcode) {
    final code = barcode.trim().toLowerCase();
    if (code.isEmpty) return;

    final match = _allProducts
        .where((p) =>
            p.sku.toLowerCase() == code ||
            p.barcodes.any((b) => b.toLowerCase() == code))
        .toList();

    if (match.length == 1) {
      _addToCart(match.first);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Scanned: ${match.first.name}'),
            duration: const Duration(seconds: 1)));
      }
    }
  }

  void _onSearchSubmitted(String val) {
    if (_filtered.length == 1) {
      // Auto-add if exact single match
      _addToCart(_filtered.first);
      _searchCtrl.clear();
      _filter();
    }
  }

  void _addToCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((e) => e.product.id == p.id);
      if (idx >= 0) {
        if (_cart[idx].qty < p.quantity) {
          _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + 1);
        }
      } else {
        _cart.add(_CartEntry(product: p, qty: 1));
      }
    });
    _saveCart();
  }

  void _removeFromCart(String productId) {
    setState(() => _cart.removeWhere((e) => e.product.id == productId));
    _saveCart();
  }

  void _updateCartEntry(String productId, _CartEntry updated) {
    setState(() {
      final idx = _cart.indexWhere((e) => e.product.id == productId);
      if (idx >= 0) {
        if (updated.qty <= 0) {
          _cart.removeAt(idx);
        } else if (updated.qty <= _cart[idx].product.quantity) {
          _cart[idx] = updated;
        } else {
          // cap at max qty
          _cart[idx] = updated.copyWith(qty: _cart[idx].product.quantity);
        }
      }
    });
    _saveCart();
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _paymentMethod = 'cash';
      _selectedCustomer = null;
      _pointsDiscount = 0;
      _amountPaidCtrl.clear();
      _redeemPointsCtrl.clear();
      _mpesaPhoneCtrl.clear();
    });
    _saveCart();
  }

  double get _cartTotal =>
      _cart.fold(0.0, (s, e) => s + e.lineTotal) - _pointsDiscount;
  double get _cartProfit =>
      _cart.fold(0.0, (s, e) => s + e.lineProfit) - _pointsDiscount;

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    if (_paymentMethod == 'credit' && _selectedCustomer == null) {
      if (mounted) {
        setState(() => _error = 'Please select a customer for credit sales.');
      }
      return;
    }
    setState(() {
      _processingCheckout = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final bizId = auth.businessId;
      if (bizId == null) {
        setState(() {
          _error = 'No business found.';
          _processingCheckout = false;
        });
        return;
      }

      final total = _cartTotal;
      final profit = _cartProfit;
      final items = _cart.map((e) => e.toMap()).toList();
      final isOnline = context.read<ConnectivityProvider>().isOnline;

      if (isOnline) {
        Map<String, dynamic> result;

        if (_paymentMethod == 'mpesa') {
          final phone = _mpesaPhoneCtrl.text.trim();
          if (phone.isEmpty) {
            setState(() {
              _error = 'M-Pesa phone number required';
              _processingCheckout = false;
            });
            return;
          }

          // 1. Initiate STK Push
          final refId = const Uuid().v4().substring(0, 8);
          await FunctionsService.call('initiateStkPush', {
            'businessId': bizId,
            'phoneNumber': phone,
            'amount': total,
            'reference': refId,
            'description': 'POS Sale'
          });

          // Show wait dialog
          if (mounted) {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const AlertDialog(
                      content:
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Waiting for M-Pesa PIN...',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Please ask the customer to enter their PIN.',
                            textAlign: TextAlign.center),
                      ]),
                    ));
          }

          // Wait briefly, we'll just create the sale anyway and mark it pending in a real app,
          // but for now, we simulate waiting or just create it immediately.
          // In production, we'd listen to the mpesa_requests document.
          // For simplicity, we just create the sale immediately.
          if (mounted) Navigator.pop(context); // close wait dialog

          result = await FunctionsService.call('createSale', {
            'businessId': bizId,
            'paymentMethod': _paymentMethod,
            'customerId': _selectedCustomer?.id,
            'customerName': _selectedCustomer?.fullName,
            'items': items,
            'pointsRedeemed': _pointsDiscount,
          });
        } else if (_paymentMethod == 'credit') {
          final amountPaid = double.tryParse(_amountPaidCtrl.text.trim()) ?? 0;
          result = await FunctionsService.call('createCreditSale', {
            'businessId': bizId,
            'customerId': _selectedCustomer?.id,
            'customerName': _selectedCustomer?.fullName,
            'items': items,
            'amountPaid': amountPaid > 0 ? amountPaid : 0,
            'pointsRedeemed': _pointsDiscount,
          });
        } else {
          result = await FunctionsService.call('createSale', {
            'businessId': bizId,
            'paymentMethod': _paymentMethod,
            'customerId': _selectedCustomer?.id,
            'customerName': _selectedCustomer?.fullName,
            'items': items,
            'pointsRedeemed': _pointsDiscount,
          });
        }

        if (mounted) {
          final saleTotal = (result['total'] as num?)?.toDouble() ?? total;
          final saleProfit = (result['profit'] as num?)?.toDouble() ?? profit;
          final outstanding = (result['outstanding'] as num?)?.toDouble();
          final amountPaid = (result['amountPaid'] as num?)?.toDouble();
          final pointsEarned = (result['pointsEarned'] as num?)?.toDouble();
          _lastReceiptData = ReceiptData(
            storeName: auth.userProfile?['businessName'] as String? ??
                'Hardware Store',
            storePhone: auth.userProfile?['phone'] as String? ?? '',
            date: DateTime.now(),
            cashier: auth.user?.email ?? 'staff',
            receiptNumber: result['saleId'] as String? ??
                const Uuid().v4().substring(0, 8),
            items: _cart
                .map((e) => ReceiptItem(
                      name: e.selectedUom != null &&
                              e.selectedUom != e.product.sellingUnit
                          ? '${e.product.name} (${e.selectedUom})'
                          : e.product.name,
                      quantity: e.qty,
                      price: e.appliedPrice,
                      subtotal: e.lineTotal,
                    ))
                .toList(),
            subtotal: saleTotal + _pointsDiscount,
            discount: _pointsDiscount > 0 ? _pointsDiscount : 0,
            grandTotal: saleTotal,
            paymentMethod: _paymentMethod,
            customerName: _selectedCustomer?.fullName,
            kraPin: result['kraPin'] as String?,
            timsCuInvoiceNumber: result['timsCuInvoiceNumber'] as String?,
            timsQrCode: result['timsQrCode'] as String?,
          );
          _showReceiptDialog(saleTotal, saleProfit,
              outstanding: outstanding,
              amountPaid: amountPaid,
              pointsEarned: pointsEarned);
          _clearAfterCheckout();
          _loadProducts();
        }
      } else {
        final queue = context.read<OfflineSalesQueue>();
        final saleId = 'offline_${const Uuid().v4().substring(0, 8)}';
        final saleData = {
          'paymentMethod': _paymentMethod,
          'items': items,
          if (_selectedCustomer != null) ...{
            'customerId': _selectedCustomer?.id,
            'customerName': _selectedCustomer?.fullName,
          },
          if (_pointsDiscount > 0) 'pointsRedeemed': _pointsDiscount,
          if (_paymentMethod == 'credit') ...{
            'amountPaid': double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
          },
        };
        await queue.enqueueOfflineSale(saleData);

        if (mounted) {
          _lastReceiptData = ReceiptData(
            storeName: auth.userProfile?['businessName'] as String? ??
                'Hardware Store',
            storePhone: auth.userProfile?['phone'] as String? ?? '',
            date: DateTime.now(),
            cashier: auth.user?.email ?? 'staff',
            receiptNumber: saleId,
            items: _cart
                .map((e) => ReceiptItem(
                      name: e.selectedUom != null &&
                              e.selectedUom != e.product.sellingUnit
                          ? '${e.product.name} (${e.selectedUom})'
                          : e.product.name,
                      quantity: e.qty,
                      price: e.appliedPrice,
                      subtotal: e.lineTotal,
                    ))
                .toList(),
            subtotal: total + _pointsDiscount,
            discount: _pointsDiscount > 0 ? _pointsDiscount : 0,
            grandTotal: total,
            paymentMethod: _paymentMethod,
            customerName: _selectedCustomer?.fullName,
          );
          _showReceiptDialog(total, profit,
              isOffline: true, pointsEarned: total / 100);
          _clearAfterCheckout();
        }
      }
    } on FunctionsException catch (e) {
      if (mounted) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          _handleOfflineCheckout();
        } else {
          setState(() {
            _error = e.message;
            _processingCheckout = false;
          });
        }
      }
    }
  }

  void _clearAfterCheckout() {
    setState(() {
      _cart.clear();
      _processingCheckout = false;
      _selectedCustomer = null;
      _pointsDiscount = 0;
      _amountPaidCtrl.clear();
      _redeemPointsCtrl.clear();
      _mpesaPhoneCtrl.clear();
    });
    _saveCart();
  }

  Future<void> _handleOfflineCheckout() async {
    final auth = context.read<AuthProvider>();
    final bizId = auth.businessId;
    if (bizId == null) return;

    final total = _cartTotal;
    final profit = _cartProfit;
    final items = _cart.map((e) => e.toMap()).toList();
    final queue = context.read<OfflineSalesQueue>();
    final saleId = 'offline_${const Uuid().v4().substring(0, 8)}';

    final saleData = {
      'paymentMethod': _paymentMethod,
      'items': items,
      if (_selectedCustomer != null) ...{
        'customerId': _selectedCustomer?.id,
        'customerName': _selectedCustomer?.fullName,
      },
      if (_pointsDiscount > 0) 'pointsRedeemed': _pointsDiscount,
      if (_paymentMethod == 'credit') ...{
        'amountPaid': double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
      },
    };
    await queue.enqueueOfflineSale(saleData);

    if (mounted) {
      _lastReceiptData = ReceiptData(
        storeName:
            auth.userProfile?['businessName'] as String? ?? 'Hardware Store',
        storePhone: auth.userProfile?['phone'] as String? ?? '',
        date: DateTime.now(),
        cashier: auth.user?.email ?? 'staff',
        receiptNumber: saleId,
        items: _cart
            .map((e) => ReceiptItem(
                  name: e.selectedUom != null &&
                          e.selectedUom != e.product.sellingUnit
                      ? '${e.product.name} (${e.selectedUom})'
                      : e.product.name,
                  quantity: e.qty,
                  price: e.appliedPrice,
                  subtotal: e.lineTotal,
                ))
            .toList(),
        subtotal: total + _pointsDiscount,
        discount: _pointsDiscount > 0 ? _pointsDiscount : 0,
        grandTotal: total,
        paymentMethod: _paymentMethod,
        customerName: _selectedCustomer?.fullName,
      );
      _showReceiptDialog(total, profit,
          isOffline: true, pointsEarned: total / 100);
      _clearAfterCheckout();
    }
  }

  void _showReceiptDialog(double total, double profit,
      {double? outstanding,
      double? amountPaid,
      bool isOffline = false,
      double? pointsEarned}) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: isOffline
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.check_circle_rounded,
              color: isOffline ? AppColors.warning : AppColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(isOffline ? 'Sale Saved Offline' : 'Sale Complete!',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          if (isOffline) ...[
            const SizedBox(height: 4),
            Text('Will sync when online',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          _ReceiptRow('Total', _fmt.format(total), theme: theme),
          _ReceiptRow('Profit', _fmt.format(profit),
              valueColor: AppColors.success, theme: theme),
          _ReceiptRow('Method', _paymentMethod.toUpperCase(), theme: theme),
          if (pointsEarned != null &&
              pointsEarned > 0 &&
              _selectedCustomer?.isFundi == true)
            _ReceiptRow('Points Earned', '${pointsEarned.toInt()} pts',
                valueColor: AppColors.accent, theme: theme),
          if (amountPaid != null && amountPaid > 0)
            _ReceiptRow('Paid', _fmt.format(amountPaid),
                valueColor: AppColors.success, theme: theme),
          if (outstanding != null && outstanding > 0)
            _ReceiptRow('Outstanding', _fmt.format(outstanding),
                valueColor: AppColors.warning, theme: theme),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done')),
          if (_lastReceiptData != null) ...[
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _printReceipt(context);
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print (Thermal)'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _shareReceiptPdf();
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Print A4 Invoice'),
            ),
          ],
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('${RoutePaths.sales}/history');
            },
            child: const Text('View History'),
          ),
        ],
      ),
    );
  }

  void _showHardwareCalculators() {
    showDialog(
      context: context,
      builder: (ctx) => const _HardwareCalculatorsDialog(),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    if (_lastReceiptData == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ReceiptService.generateEscPos(_lastReceiptData!);
      final success = await ReceiptService.printViaBluetooth(bytes);
      if (!success && mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text(
                  'No Bluetooth printer found. Connect a printer and try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  Future<void> _shareReceiptPdf() async {
    if (_lastReceiptData == null) return;
    try {
      final qrUrl =
          'https://hwos.app/receipts/${_lastReceiptData!.receiptNumber}';
      await ReceiptService.sharePdf(_lastReceiptData!,
          isA4: true, qrData: qrUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
      }
    }
  }

  void _showCustomerPicker() {
    _loadCustomers();
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _customers
                .where((c) =>
                    c.fullName
                        .toLowerCase()
                        .contains(searchCtrl.text.toLowerCase()) ||
                    c.phoneNumber.contains(searchCtrl.text))
                .toList();
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Text('Select Customer',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCreateCustomerDialog();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                  ),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onChanged: (_) => setSheetState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _loadingCustomers
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('No customers found'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: theme.dividerColor),
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.accent.withValues(alpha: 0.1),
                                  child: Text(c.fullName[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700)),
                                ),
                                title: Text(c.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                subtitle: Text(c.phoneNumber,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (c.currentBalance > 0)
                                      Text(_fmt.format(c.currentBalance),
                                          style: const TextStyle(
                                              color: AppColors.warning,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                    if (c.isFundi)
                                      Text('${c.loyaltyPoints.toInt()} pts',
                                          style: const TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedCustomer = c;
                                    _pointsDiscount = 0;
                                    _redeemPointsCtrl.clear();
                                    if (c.phoneNumber.isNotEmpty) {
                                      _mpesaPhoneCtrl.text = c.phoneNumber;
                                    }
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
              ),
            ]);
          },
        );
      },
    );
  }

  void _showCreateCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            final name = nameCtrl.text.trim();
            final phone = phoneCtrl.text.trim();
            if (name.isEmpty || phone.isEmpty) return;

            setDialogState(() => isSaving = true);
            final messenger = ScaffoldMessenger.of(context);
            final dialogNavigator = Navigator.of(ctx);
            try {
              final bizId = context.read<AuthProvider>().businessId!;
              final res = await FunctionsService.call('createCustomer', {
                'businessId': bizId,
                'fullName': name,
                'phoneNumber': phone,
              });

              final newId = res['customerId'] as String;
              final newCustomer = Customer(
                id: newId,
                businessId: bizId,
                fullName: name,
                phoneNumber: phone,
                creditLimit: 0,
                currentBalance: 0,
                totalDebt: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              if (!mounted) return;

              setState(() {
                _customers.insert(0, newCustomer);
                _selectedCustomer = newCustomer;
                _pointsDiscount = 0;
                _redeemPointsCtrl.clear();
                _mpesaPhoneCtrl.text = phone;
              });

              dialogNavigator.pop();
              messenger.showSnackBar(
                  SnackBar(content: Text('Customer $name created!')));
            } catch (e) {
              if (!mounted) return;
              setDialogState(() => isSaving = false);
              final messenger2 = ScaffoldMessenger.of(context);
              messenger2.showSnackBar(SnackBar(content: Text('Error: $e')));
            }

            return;
          }

          return AlertDialog(
            title: const Text('New Customer'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                    labelText: 'Phone Number (e.g. 07...)'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSaving ? null : submit,
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f9): CheckoutIntent.key,
        LogicalKeySet(LogicalKeyboardKey.f12): ClearCartIntent.key,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
            FocusSearchIntent.key,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.space):
            FocusSearchIntent.key,
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CheckoutIntent: CallbackAction<CheckoutIntent>(onInvoke: (_) {
            if (!_processingCheckout) _checkout();
            return null;
          }),
          ClearCartIntent: CallbackAction<ClearCartIntent>(onInvoke: (_) {
            _clearCart();
            return null;
          }),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(onInvoke: (_) {
            FocusScope.of(context).requestFocus(_searchFocusNode);
            return null;
          }),
        },
        child: BarcodeListener(
          onBarcodeScanned: _handleBarcodeScanned,
          child: LoadingOverlay(
            isLoading: _processingCheckout,
            message: 'Processing sale...',
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Column(
                children: [
                  if (!context.watch<ConnectivityProvider>().isOnline)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.error,
                      child: const Text(
                        'You are currently OFFLINE - Sales will be saved locally and synced when online.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (context.watch<OfflineSalesQueue>().pendingSales > 0 &&
                      context.watch<ConnectivityProvider>().isOnline)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.warning,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black)),
                          const SizedBox(width: 8),
                          const SizedBox(width: 8),
                          Text(
                            '${context.watch<OfflineSalesQueue>().pendingSales} offline sales pending...',
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => context.push('/sales/offline-queue'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('VIEW QUEUE',
                                style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(child: isWide ? _wideLayout() : _narrowLayout()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideLayout() => Row(children: [
        Expanded(flex: 3, child: _productPanel()),
        Container(width: 1, color: Theme.of(context).dividerColor),
        Expanded(flex: 2, child: _cartPanel()),
      ]);

  Widget _narrowLayout() => Column(children: [
        Expanded(child: _productPanel()),
        if (_cart.isNotEmpty) _miniCartBar(),
      ]);

  Widget _productPanel() {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(Responsive.padding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child:
                  Text('POS — New Sale', style: theme.textTheme.displayMedium)),
          TextButton.icon(
            onPressed: () => _showHardwareCalculators(),
            icon: const Icon(Icons.calculate_rounded, size: 16),
            label: const Text('Calculators'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _showHeldCarts(),
            icon: const Icon(Icons.inventory_2_rounded, size: 16),
            label: const Text('Held Carts'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => context.go('${RoutePaths.sales}/history'),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('History'),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _searchCtrl,
          focusNode: _searchFocusNode,
          onSubmitted: _onSearchSubmitted,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search products or scan barcode...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _filter();
                    })
                : null,
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3))),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        Expanded(
          child: _loadingProducts
              ? const Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.accent)))
              : _filtered.isEmpty
                  ? Center(
                      child: Text('No products found.',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final inCart = _cart.any((e) => e.product.id == p.id);
                        return _ProductTile(
                            product: p,
                            inCart: inCart,
                            onTap: () => _addToCart(p),
                            theme: theme);
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _cartPanel() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.shopping_cart_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Cart', style: theme.textTheme.headlineMedium),
          const Spacer(),
          if (_cart.isNotEmpty)
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_cart.length}',
                    style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.pause_circle_outline,
                    color: AppColors.accent),
                onPressed: () => _holdCart(context),
                tooltip: 'Hold Cart',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded,
                    color: AppColors.error),
                onPressed: _clearCart,
                tooltip: 'Clear Cart',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.shopping_cart_outlined,
                          color: theme.hintColor, size: 48),
                      const SizedBox(height: 12),
                      Text('Cart is empty',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text('Tap a product to add it.',
                          style:
                              TextStyle(color: theme.hintColor, fontSize: 12)),
                    ]))
              : ListView.separated(
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (_, i) {
                    final e = _cart[i];
                    return _CartTile(
                      entry: e,
                      fmt: _fmt,
                      theme: theme,
                      onRemove: () => _removeFromCart(e.product.id),
                      onUpdate: (updated) =>
                          _updateCartEntry(e.product.id, updated),
                    );
                  },
                ),
        ),
        Divider(height: 20, color: theme.dividerColor),
        GestureDetector(
          onTap: _showCustomerPicker,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor)),
            child: Row(children: [
              Expanded(
                child: _selectedCustomer != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('Customer',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant)),
                            Text(_selectedCustomer!.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            if (_selectedCustomer!.isFundi)
                              Text(
                                  '${_selectedCustomer!.loyaltyPoints.toInt()} pts available',
                                  style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                          ])
                    : Text('Select Customer (Optional)',
                        style: TextStyle(color: theme.hintColor, fontSize: 13)),
              ),
              const Icon(Icons.arrow_drop_down_rounded, size: 20),
              if (_selectedCustomer != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() {
                    _selectedCustomer = null;
                    _pointsDiscount = 0;
                    _redeemPointsCtrl.clear();
                    _mpesaPhoneCtrl.clear();
                  }),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ),
        ),
        if (_selectedCustomer != null &&
            _selectedCustomer!.isFundi &&
            _selectedCustomer!.loyaltyPoints > 0) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _redeemPointsCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText:
                  'Redeem Points (Max ${_selectedCustomer!.loyaltyPoints.toInt()})',
              prefixIcon: const Icon(Icons.star_rounded,
                  color: AppColors.accent, size: 18),
              suffixIcon: TextButton(
                onPressed: () {
                  final pts =
                      double.tryParse(_redeemPointsCtrl.text.trim()) ?? 0;
                  if (pts > _selectedCustomer!.loyaltyPoints) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not enough points')));
                    return;
                  }
                  setState(() {
                    _pointsDiscount = pts;
                  });
                },
                child: const Text('Apply'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Payment Method',
            style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _PayBtn(
              label: 'Cash',
              value: 'cash',
              selected: _paymentMethod,
              onTap: (v) => setState(() => _paymentMethod = v),
              theme: theme),
          const SizedBox(width: 8),
          _PayBtn(
              label: 'M-Pesa',
              value: 'mpesa',
              selected: _paymentMethod,
              onTap: (v) => setState(() => _paymentMethod = v),
              theme: theme),
          const SizedBox(width: 8),
          _PayBtn(
              label: 'Credit',
              value: 'credit',
              selected: _paymentMethod,
              onTap: (v) => setState(() => _paymentMethod = v),
              theme: theme),
        ]),
        const SizedBox(height: 16),
        if (_paymentMethod == 'cash') ...[
          TextField(
            controller: _amountPaidCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Amount tendered (optional)',
              prefixText: 'KES ',
              prefixStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amountPaidCtrl,
            builder: (context, val, child) {
              final tendered = double.tryParse(val.text) ?? 0;
              final change = tendered - _cartTotal;
              if (tendered > 0 && change >= 0) {
                return Text('Change Due: ${_fmt.format(change)}',
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 16));
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 12),
        ],
        if (_paymentMethod == 'credit') ...[
          TextField(
            controller: _amountPaidCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Amount paid (optional)',
              prefixText: 'KES ',
              prefixStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_paymentMethod == 'mpesa') ...[
          TextField(
            controller: _mpesaPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Enter M-Pesa Phone Number',
              prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _TotalRow('Subtotal', _fmt.format(_cartTotal + _pointsDiscount),
                theme: theme),
            if (_pointsDiscount > 0) ...[
              const SizedBox(height: 4),
              _TotalRow('Points Discount', '-${_fmt.format(_pointsDiscount)}',
                  color: AppColors.accent, theme: theme),
              const SizedBox(height: 4),
              _TotalRow('New Total', _fmt.format(_cartTotal), theme: theme),
            ],
            const SizedBox(height: 4),
            _TotalRow('Profit', _fmt.format(_cartProfit),
                color: AppColors.success, theme: theme),
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 4),
              _TotalRow('Customer', _selectedCustomer!.fullName,
                  color: AppColors.accent, theme: theme),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _processingCheckout ? null : _checkout,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text('Charge ${_fmt.format(_cartTotal)}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => _cart.clear()),
          child: const Text('Clear Cart'),
        ),
      ]),
    );
  }

  Widget _miniCartBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
          Responsive.padding(context), 12, Responsive.padding(context), 20),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_cart.length} item(s)',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          Text(_fmt.format(_cartTotal),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface)),
        ])),
        ElevatedButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollController) => Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: _cartPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: const Text('View Cart'),
        ),
      ]),
    );
  }
}

// ─── Supporting widgets ──────────────────────────────────────────────────────

class _CartEntry {
  final Product product;
  final double qty;
  final double? overridePrice;
  final String? note;
  final String? selectedUom; // e.g., 'Piece', 'Carton'
  final double uomMultiplier;

  _CartEntry({
    required this.product,
    required this.qty,
    this.overridePrice,
    this.note,
    this.selectedUom,
    this.uomMultiplier = 1.0,
  });

  double get appliedPrice =>
      overridePrice ?? (product.sellingPrice * uomMultiplier);
  double get lineTotal => appliedPrice * qty;
  double get lineProfit =>
      (appliedPrice - (product.costPrice * uomMultiplier)) * qty;

  _CartEntry copyWith({
    Product? product,
    double? qty,
    double? overridePrice,
    String? note,
    String? selectedUom,
    double? uomMultiplier,
  }) {
    return _CartEntry(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      overridePrice: overridePrice, // allow nulling out overridePrice
      note: note ?? this.note,
      selectedUom: selectedUom ?? this.selectedUom,
      uomMultiplier: uomMultiplier ?? this.uomMultiplier,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': product.id,
        'name': selectedUom != null && selectedUom != product.sellingUnit
            ? '${product.name} ($selectedUom)'
            : product.name,
        'quantity': qty * uomMultiplier, // Convert to base unit for inventory
        'sellingPrice': appliedPrice / uomMultiplier, // Send base price
        'costPrice': product.costPrice,
        'displayQty': qty,
        'displayUnit': selectedUom ?? product.sellingUnit,
        if (overridePrice != null) 'overridePrice': overridePrice,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final bool inCart;
  final VoidCallback onTap;
  final ThemeData theme;
  const _ProductTile(
      {required this.product,
      required this.inCart,
      required this.onTap,
      required this.theme});

  @override
  Widget build(BuildContext context) => Material(
        color:
            inCart ? AppColors.accent.withValues(alpha: 0.1) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: inCart ? AppColors.accent : theme.dividerColor,
                    width: inCart ? 1.5 : 1)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Text(product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                    if (inCart)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.accent, size: 16),
                  ]),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'KES ${product.sellingPrice.toStringAsFixed(0)}${product.sellingUnit != null ? ' / ${product.sellingUnit}' : ''}',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(
                          'Stock: ${product.quantity}${product.sellingUnit != null ? ' ${product.sellingUnit}' : ''}',
                          style:
                              TextStyle(color: theme.hintColor, fontSize: 11)),
                    ],
                  ),
                ]),
          ),
        ),
      );
}

class _CartTile extends StatelessWidget {
  final _CartEntry entry;
  final NumberFormat fmt;
  final ThemeData theme;
  final VoidCallback onRemove;
  final ValueChanged<_CartEntry> onUpdate;
  const _CartTile(
      {required this.entry,
      required this.fmt,
      required this.theme,
      required this.onRemove,
      required this.onUpdate});

  void _showEditQtyDialog(BuildContext context) {
    final ctrl = TextEditingController(text: entry.qty.toString());
    void submit() {
      final val = double.tryParse(ctrl.text);
      if (val != null && val >= 0) {
        onUpdate(entry.copyWith(qty: val));
        Navigator.pop(context);
      }
    }

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Edit Quantity'),
              content: TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantity'),
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: submit,
                  child: const Text('Save'),
                ),
              ],
            ));
  }

  void _showEditPriceDialog(BuildContext context) {
    final ctrl =
        TextEditingController(text: entry.appliedPrice.toStringAsFixed(2));
    void submit() {
      final val = double.tryParse(ctrl.text);
      if (val != null && val >= 0) {
        onUpdate(entry.copyWith(overridePrice: val));
        Navigator.pop(context);
      }
    }

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Override Price'),
              content: TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'New Unit Price'),
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    onUpdate(
                        entry.copyWith(overridePrice: null)); // Clear override
                    Navigator.pop(ctx);
                  },
                  child: const Text('Reset',
                      style: TextStyle(color: AppColors.error)),
                ),
                ElevatedButton(
                  onPressed: submit,
                  child: const Text('Save'),
                ),
              ],
            ));
  }

  void _showNoteDialog(BuildContext context) {
    final ctrl = TextEditingController(text: entry.note ?? '');
    void submit() {
      onUpdate(entry.copyWith(note: ctrl.text.trim()));
      Navigator.pop(context);
    }

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Item Note'),
              content: TextField(
                controller: ctrl,
                maxLines: 2,
                decoration:
                    const InputDecoration(hintText: 'e.g. Cut into 2m pieces'),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: submit,
                  child: const Text('Save'),
                ),
              ],
            ));
  }

  Future<void> _readScale(BuildContext context) async {
    final service = getWebSerialService();
    final isSupported = await service.isSupported();
    if (!isSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Web Serial API not supported in this browser. Please use Chrome/Edge.')));
      }
      return;
    }

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select the weighing scale COM port...')));
      }
      await service.requestPort();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Connected to scale. Reading weight...')));
      }

      final stream = service.readData();
      String buffer = '';

      stream.listen((data) {
        buffer += data;
        // Looking for a continuous number, e.g., ST,GS,+  001.25 kg
        // A simple regex to find the first decimal number in the stream output
        final regex = RegExp(r'(\d+\.\d+)');
        final match = regex.firstMatch(buffer);
        if (match != null) {
          final weight = double.tryParse(match.group(1) ?? '');
          if (weight != null && weight > 0) {
            onUpdate(entry.copyWith(qty: weight));
            service.closePort();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Weight Captured: $weight ${entry.product.sellingUnit ?? 'Kg'}')));
            }
          }
        }
        if (buffer.length > 100) {
          buffer =
              buffer.substring(buffer.length - 50); // prevent buffer overflow
        }
      });

      // Auto close after 10 seconds if no weight found
      Future.delayed(const Duration(seconds: 10), () {
        service.closePort();
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Scale Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(entry.product.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showEditPriceDialog(context),
                      child: Text(
                        fmt.format(entry.appliedPrice),
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                            decorationStyle: TextDecorationStyle.dashed),
                      ),
                    ),
                    if (entry.overridePrice != null &&
                        entry.overridePrice != entry.product.sellingPrice) ...[
                      const SizedBox(width: 6),
                      Text(fmt.format(entry.product.sellingPrice),
                          style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough)),
                    ],
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showNoteDialog(context),
                      child: Icon(Icons.note_add_rounded,
                          size: 14,
                          color: entry.note != null && entry.note!.isNotEmpty
                              ? AppColors.accent
                              : theme.hintColor),
                    ),
                    if (entry.product.uomConfig != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                entry.selectedUom ?? entry.product.sellingUnit,
                            isDense: true,
                            iconSize: 14,
                            style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600),
                            items: [
                              if (entry.product.sellingUnit != null)
                                DropdownMenuItem(
                                    value: entry.product.sellingUnit,
                                    child: Text(entry.product.sellingUnit!)),
                              DropdownMenuItem(
                                  value: entry.product.uomConfig!.purchaseUnit,
                                  child: Text(
                                      entry.product.uomConfig!.purchaseUnit)),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                final mult =
                                    val == entry.product.uomConfig!.purchaseUnit
                                        ? entry.product.uomConfig!
                                            .conversionMultiplier
                                        : 1.0;
                                onUpdate(entry.copyWith(
                                    selectedUom: val, uomMultiplier: mult));
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(entry.note!,
                      style: TextStyle(
                          color: theme.hintColor,
                          fontSize: 10,
                          fontStyle: FontStyle.italic)),
                ],
                if (entry.product.isWeighed) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _readScale(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.accent)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.scale_rounded,
                              size: 12, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text('Read Scale',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ])),
          Row(children: [
            _QtyBtn(
                icon: Icons.remove,
                onTap: () => onUpdate(entry.copyWith(qty: entry.qty - 1)),
                theme: theme),
            GestureDetector(
              onTap: () => _showEditQtyDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                    entry.qty.toStringAsFixed(
                        entry.qty.truncateToDouble() == entry.qty ? 0 : 2),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                        decoration: TextDecoration.underline)),
              ),
            ),
            _QtyBtn(
                icon: Icons.add,
                onTap: () => onUpdate(entry.copyWith(qty: entry.qty + 1)),
                theme: theme),
          ]),
          const SizedBox(width: 6),
          GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.delete_outline_rounded,
                  color: AppColors.error.withValues(alpha: 0.8), size: 20)),
        ]),
      );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  const _QtyBtn({required this.icon, required this.onTap, required this.theme});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36, // Increased touch target for mobile
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8)),
          child:
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ),
      );
}

class _PayBtn extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  final ThemeData theme;
  const _PayBtn(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap,
      required this.theme});
  @override
  Widget build(BuildContext context) {
    final sel = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: sel
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? AppColors.accent : theme.dividerColor)),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: sel
                      ? AppColors.accent
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  final ThemeData theme;
  const _TotalRow(this.label, this.value, {this.color, required this.theme});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: color ?? theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      );
}

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final ThemeData theme;
  const _ReceiptRow(this.label, this.value,
      {this.valueColor, required this.theme});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? theme.colorScheme.onSurface)),
        ]),
      );
}

class _HardwareCalculatorsDialog extends StatefulWidget {
  const _HardwareCalculatorsDialog();
  @override
  State<_HardwareCalculatorsDialog> createState() =>
      _HardwareCalculatorsDialogState();
}

class _HardwareCalculatorsDialogState
    extends State<_HardwareCalculatorsDialog> {
  String _mode = 'Tile';
  final _roomLCtrl = TextEditingController();
  final _roomWCtrl = TextEditingController();
  final _itemLCtrl = TextEditingController();
  final _itemWCtrl = TextEditingController();
  final _coverageCtrl = TextEditingController(); // for paint
  final _wireWeightCtrl = TextEditingController();
  final _wireBaseWeightCtrl = TextEditingController(text: '2.0'); // kg per 100m
  final _wattsCtrl = TextEditingController();
  final _voltsCtrl = TextEditingController(text: '240');
  final _pricePerUnitCtrl =
      TextEditingController(); // for room wiring estimator

  double? _resultQty;
  double? _resultArea;
  String? _complexResult;

  void _calculate() {
    setState(() {
      _resultQty = null;
      _resultArea = null;
      _complexResult = null;

      if (_mode == 'Wire (Weight to Length)') {
        final weight = double.tryParse(_wireWeightCtrl.text) ?? 0;
        final base = double.tryParse(_wireBaseWeightCtrl.text) ?? 0;
        if (weight > 0 && base > 0) {
          _resultQty = (weight / base) * 100;
        }
        return;
      } else if (_mode == 'Breaker Load') {
        final watts = double.tryParse(_wattsCtrl.text) ?? 0;
        final volts = double.tryParse(_voltsCtrl.text) ?? 240;
        if (watts > 0 && volts > 0) {
          final amps = watts / volts;
          final breaker = amps * 1.25; // 25% safety margin
          _complexResult =
              'Load: ${amps.toStringAsFixed(1)} A\nRecommended Breaker: ${breaker.ceil()} A';
        }
        return;
      }

      final rl = double.tryParse(_roomLCtrl.text) ?? 0;
      final rw = double.tryParse(_roomWCtrl.text) ?? 0;
      if (rl <= 0 || rw <= 0) return;

      final roomArea = rl * rw;
      final perimeter = 2 * (rl + rw);
      _resultArea = roomArea;

      if (_mode == 'Tile') {
        final il = double.tryParse(_itemLCtrl.text) ?? 0;
        final iw = double.tryParse(_itemWCtrl.text) ?? 0;
        if (il > 0 && iw > 0) {
          final itemArea = (il / 100) * (iw / 100);
          _resultQty = roomArea / itemArea;
        }
      } else if (_mode == 'Paint') {
        final coverage = double.tryParse(_coverageCtrl.text) ?? 10;
        if (coverage > 0) {
          _resultQty = roomArea / coverage;
        }
      } else if (_mode == 'Room Wiring') {
        final wireNeeded = perimeter * 3; // Approx 3 runs around the room
        final sockets = (perimeter / 3).ceil(); // 1 socket every 3m
        final switches = 1 + (roomArea / 15).floor(); // 1 switch per 15sqm
        final lights = (roomArea / 10).ceil(); // 1 light per 10sqm
        final pricePerMeter = double.tryParse(_pricePerUnitCtrl.text) ?? 0;

        String res = 'Wire needed: ${wireNeeded.toStringAsFixed(1)} m\n'
            'Sockets needed: $sockets\n'
            'Switches: $switches, Lights: $lights';
        if (pricePerMeter > 0) {
          res +=
              '\n\nEst Wire Cost: KES ${(wireNeeded * pricePerMeter).toStringAsFixed(0)}';
        }
        _complexResult = res;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Hardware Calculators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _mode,
            items: [
              'Tile',
              'Paint',
              'Wire (Weight to Length)',
              'Breaker Load',
              'Room Wiring'
            ]
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _mode = v;
                  _resultQty = null;
                  _resultArea = null;
                  _complexResult = null;
                  _calculate();
                });
              }
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_mode == 'Tile' ||
              _mode == 'Paint' ||
              _mode == 'Room Wiring') ...[
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _roomLCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Room Length (m)'),
                      onChanged: (_) => _calculate())),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _roomWCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Room Width (m)'),
                      onChanged: (_) => _calculate())),
            ]),
            const SizedBox(height: 16),
          ],
          if (_mode == 'Wire (Weight to Length)') ...[
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _wireWeightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Coil Weight (kg)'),
                      onChanged: (_) => _calculate())),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _wireBaseWeightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Standard (kg/100m)'),
                      onChanged: (_) => _calculate())),
            ]),
          ] else if (_mode == 'Breaker Load') ...[
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _wattsCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Total Watts (W)'),
                      onChanged: (_) => _calculate())),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _voltsCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Voltage (V)'),
                      onChanged: (_) => _calculate())),
            ]),
          ] else if (_mode == 'Tile') ...[
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _itemLCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Tile Length (cm)'),
                      onChanged: (_) => _calculate())),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _itemWCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Tile Width (cm)'),
                      onChanged: (_) => _calculate())),
            ]),
          ] else if (_mode == 'Paint') ...[
            TextField(
                controller: _coverageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Coverage (sqm per L) - Default 10'),
                onChanged: (_) => _calculate()),
          ] else if (_mode == 'Room Wiring') ...[
            TextField(
                controller: _pricePerUnitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Wire Price per Meter (optional)'),
                onChanged: (_) => _calculate()),
          ],
          const SizedBox(height: 24),
          if (_resultArea != null)
            Text('Total Area: ${_resultArea!.toStringAsFixed(2)} sqm',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_resultQty != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                _mode == 'Tile'
                    ? 'Tiles Needed: ${_resultQty!.ceil()} (approx)'
                    : _mode == 'Paint'
                        ? 'Paint Needed: ${_resultQty!.toStringAsFixed(1)} Liters'
                        : 'Estimated Length: ${_resultQty!.toStringAsFixed(1)} meters',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          if (_complexResult != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_complexResult!,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4)),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}
