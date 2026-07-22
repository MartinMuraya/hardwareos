import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
import 'package:flutter/services.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class CheckoutIntent extends Intent { const CheckoutIntent(); static const key = CheckoutIntent(); }
class ClearCartIntent extends Intent { const ClearCartIntent(); static const key = ClearCartIntent(); }
class FocusSearchIntent extends Intent { const FocusSearchIntent(); static const key = FocusSearchIntent(); }

class _POSScreenState extends State<POSScreen> {
  final List<_CartEntry> _cart = [];
  String _paymentMethod = 'cash';

  // Credit sale state
  String? _selectedCustomerId;
  String _selectedCustomerName = '';
  final _amountPaidCtrl = TextEditingController();
  List<Customer> _customers = [];
  bool _loadingCustomers = false;

  final _searchCtrl  = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Product> _allProducts = [];
  List<Product> _filtered    = [];
  bool _loadingProducts      = true;
  bool _processingCheckout   = false;
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
  void dispose() { _searchCtrl.dispose(); _amountPaidCtrl.dispose(); super.dispose(); }

  void _loadSavedCart() {
    final saved = OfflineService.loadCart();
    if (saved.isNotEmpty) {
      final loaded = <_CartEntry>[];
      for (final item in saved) {
        final prodMap = item['product'] as Map<String, dynamic>;
        final qty = (item['qty'] as num).toDouble();
        final overridePrice = item['overridePrice'] != null ? (item['overridePrice'] as num).toDouble() : null;
        final note = item['note'] as String?;
        loaded.add(_CartEntry(product: Product.fromMap(prodMap), qty: qty, overridePrice: overridePrice, note: note));
      }
      _cart.addAll(loaded);
    }
  }

  void _saveCart() {
    OfflineService.saveCart(
      _cart.map((e) => {
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
      }).toList(),
    );
  }

  void _holdCart(BuildContext context) {
    if (_cart.isEmpty) return;
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) {
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
        await OfflineService.saveDraftSale(id, draftData);
        setState(() { _cart.clear(); });
        _saveCart();
        if (mounted) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cart "$ref" held.')));
        }
      }
      return AlertDialog(
        title: const Text('Hold Cart'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Customer name or reference', labelText: 'Reference'),
          autofocus: true,
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: submit,
            child: const Text('Hold Cart'),
          ),
        ],
      );
    });
  }

  void _showHeldCarts(BuildContext context) {
    final drafts = OfflineService.getAllDrafts();
    showDialog(context: context, builder: (ctx) => AlertDialog(
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
                  title: Text(ref, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${items.length} items • ${DateFormat('MMM d, h:mm a').format(date)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: () async {
                      await OfflineService.deleteDraftSale(id);
                      Navigator.pop(ctx);
                      _showHeldCarts(context); // Refresh
                    },
                  ),
                  onTap: () async {
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
                          orElse: () => Product.fromMap(m), // Fallback (missing some fields, but works for UI)
                        );
                        _cart.add(_CartEntry(
                          product: p,
                          qty: (m['quantity'] as num).toDouble(),
                          overridePrice: m['overridePrice'] != null ? (m['overridePrice'] as num).toDouble() : null,
                          note: m['note'] as String?,
                        ));
                      }
                    });
                    _saveCart();
                    await OfflineService.deleteDraftSale(id);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ));
  }

  Future<void> _loadCustomers() async {
    if (_customers.isNotEmpty) return;
    setState(() => _loadingCustomers = true);
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getCustomers', {'businessId': bizId, 'limit': 200});
      final rawList = (data['customers'] as List?) ?? [];
      _customers = rawList.map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingCustomers = false);
  }

  Future<void> _loadProducts() async {
    setState(() { _loadingProducts = true; _error = null; });
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
        final data  = await FunctionsService.call('getProducts', {'businessId': bizId, 'limit': 200});
        final rawList = (data['products'] as List?) ?? [];
        prods = rawList
            .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        // Save to cache
        OfflineService.saveProducts(prods.map((p) => {
          'id': p.id, 'businessId': p.businessId, 'name': p.name, 'sku': p.sku, 'category': p.category, 
          'quantity': p.quantity, 'costPrice': p.costPrice, 'sellingPrice': p.sellingPrice, 
          'reorderLevel': p.reorderLevel, 'barcodes': p.barcodes, 'createdAt': p.createdAt.toIso8601String(), 'updatedAt': p.updatedAt.toIso8601String()
        }).toList());
      }
      
      // Filter out out-of-stock
      prods = prods.where((p) => !p.isOutOfStock).toList();

      if (mounted) setState(() { _allProducts = prods; _filtered = prods; _loadingProducts = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loadingProducts = false; });
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

    final matched = _allProducts.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.sku.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q) ||
        p.barcodes.any((b) => b.toLowerCase() == q)).toList();

    if (matched.isEmpty && q.length > 2) {
      // Fallback to fuzzy search on name
      final fuzzy = _allProducts.where((p) => _fuzzyMatch(q, p.name.toLowerCase())).toList();
      setState(() => _filtered = fuzzy);
    } else {
      setState(() => _filtered = matched);
    }
  }

  void _handleBarcodeScanned(String barcode) {
    final code = barcode.trim().toLowerCase();
    if (code.isEmpty) return;

    final match = _allProducts.where((p) => 
      p.sku.toLowerCase() == code || 
      p.barcodes.any((b) => b.toLowerCase() == code)
    ).toList();

    if (match.length == 1) {
      _addToCart(match.first);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: ${match.first.name}'), duration: const Duration(seconds: 1)));
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
      _selectedCustomerId = null;
      _selectedCustomerName = '';
      _amountPaidCtrl.clear();
    });
    _saveCart();
  }

  double get _cartTotal  => _cart.fold(0, (s, e) => s + e.lineTotal);
  double get _cartProfit => _cart.fold(0, (s, e) => s + e.lineProfit);

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    if (_paymentMethod == 'credit' && _selectedCustomerId == null) {
      if (mounted) setState(() => _error = 'Please select a customer for credit sales.');
      return;
    }
    setState(() { _processingCheckout = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final bizId = auth.businessId;
      if (bizId == null) { setState(() { _error = 'No business found.'; _processingCheckout = false; }); return; }

      final total = _cartTotal;
      final profit = _cartProfit;
      final items = _cart.map((e) => e.toMap()).toList();
      final isOnline = context.read<ConnectivityProvider>().isOnline;

      if (isOnline) {
        Map<String, dynamic> result;
        if (_paymentMethod == 'credit') {
          final amountPaid = double.tryParse(_amountPaidCtrl.text.trim()) ?? 0;
          result = await FunctionsService.call('createCreditSale', {
            'businessId': bizId,
            'customerId': _selectedCustomerId,
            'customerName': _selectedCustomerName,
            'items': items,
            'amountPaid': amountPaid > 0 ? amountPaid : 0,
          });
        } else {
          result = await FunctionsService.call('createSale', {
            'businessId': bizId,
            'paymentMethod': _paymentMethod,
            'items': items,
          });
        }

        if (mounted) {
          final saleTotal  = (result['total'] as num?)?.toDouble() ?? total;
          final saleProfit = (result['profit'] as num?)?.toDouble() ?? profit;
          final outstanding = (result['outstanding'] as num?)?.toDouble();
          final amountPaid = (result['amountPaid'] as num?)?.toDouble();
          _lastReceiptData = ReceiptData(
            storeName: auth.userProfile?['businessName'] as String? ?? 'Hardware Store',
            storePhone: auth.userProfile?['phone'] as String? ?? '',
            date: DateTime.now(),
            cashier: auth.user?.email ?? 'staff',
            receiptNumber: result['saleId'] as String? ?? const Uuid().v4().substring(0, 8),
            items: _cart.map((e) => ReceiptItem(
              name: e.product.name, quantity: e.qty,
              price: e.appliedPrice, subtotal: e.lineTotal,
            )).toList(),
            subtotal: saleTotal,
            grandTotal: saleTotal,
            paymentMethod: _paymentMethod,
            customerName: _paymentMethod == 'credit' ? _selectedCustomerName : null,
          );
          _showReceiptDialog(saleTotal, saleProfit, outstanding: outstanding, amountPaid: amountPaid);
          _clearAfterCheckout();
          _loadProducts();
        }
      } else {
        final queue = context.read<OfflineSalesQueue>();
        final saleId = 'offline_${const Uuid().v4().substring(0, 8)}';
        final saleData = {
          'paymentMethod': _paymentMethod,
          'items': items,
          if (_paymentMethod == 'credit') ...{
            'customerId': _selectedCustomerId,
            'customerName': _selectedCustomerName,
            'amountPaid': double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
          },
        };
        await queue.enqueueOfflineSale(saleData);

        if (mounted) {
          _lastReceiptData = ReceiptData(
            storeName: auth.userProfile?['businessName'] as String? ?? 'Hardware Store',
            storePhone: auth.userProfile?['phone'] as String? ?? '',
            date: DateTime.now(),
            cashier: auth.user?.email ?? 'staff',
            receiptNumber: saleId,
            items: _cart.map((e) => ReceiptItem(
              name: e.product.name, quantity: e.qty,
              price: e.product.sellingPrice, subtotal: e.lineTotal,
            )).toList(),
            subtotal: total,
            grandTotal: total,
            paymentMethod: _paymentMethod,
            customerName: _paymentMethod == 'credit' ? _selectedCustomerName : null,
          );
          _showReceiptDialog(total, profit, isOffline: true);
          _clearAfterCheckout();
        }
      }
    } on FunctionsException catch (e) {
      if (mounted) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          _handleOfflineCheckout();
        } else {
          setState(() { _error = e.message; _processingCheckout = false; });
        }
      }
    }
  }

  void _clearAfterCheckout() {
    setState(() {
      _cart.clear();
      _processingCheckout = false;
      _selectedCustomerId = null;
      _selectedCustomerName = '';
      _amountPaidCtrl.clear();
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
      if (_paymentMethod == 'credit') ...{
        'customerId': _selectedCustomerId,
        'customerName': _selectedCustomerName,
        'amountPaid': double.tryParse(_amountPaidCtrl.text.trim()) ?? 0,
      },
    };
    await queue.enqueueOfflineSale(saleData);

    if (mounted) {
      _lastReceiptData = ReceiptData(
        storeName: auth.userProfile?['businessName'] as String? ?? 'Hardware Store',
        storePhone: auth.userProfile?['phone'] as String? ?? '',
        date: DateTime.now(),
        cashier: auth.user?.email ?? 'staff',
        receiptNumber: saleId,
        items: _cart.map((e) => ReceiptItem(
          name: e.product.name, quantity: e.qty,
          price: e.product.sellingPrice, subtotal: e.lineTotal,
        )).toList(),
        subtotal: total,
        grandTotal: total,
        paymentMethod: _paymentMethod,
        customerName: _paymentMethod == 'credit' ? _selectedCustomerName : null,
      );
      _showReceiptDialog(total, profit, isOffline: true);
      _clearAfterCheckout();
    }
  }

  void _showReceiptDialog(double total, double profit,
      {double? outstanding, double? amountPaid, bool isOffline = false}) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: isOffline ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle),
            child: Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.check_circle_rounded,
              color: isOffline ? AppColors.warning : AppColors.success, size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(isOffline ? 'Sale Saved Offline' : 'Sale Complete!',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          if (isOffline) ...[
            const SizedBox(height: 4),
            Text('Will sync when online',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          _ReceiptRow('Total',  _fmt.format(total), theme: theme),
          _ReceiptRow('Profit', _fmt.format(profit), valueColor: AppColors.success, theme: theme),
          _ReceiptRow('Method', _paymentMethod.toUpperCase(), theme: theme),
          if (amountPaid != null && amountPaid > 0)
            _ReceiptRow('Paid', _fmt.format(amountPaid), valueColor: AppColors.success, theme: theme),
          if (outstanding != null && outstanding > 0)
            _ReceiptRow('Outstanding', _fmt.format(outstanding), valueColor: AppColors.warning, theme: theme),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
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
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share Invoice (PDF)'),
            ),
          ],
          ElevatedButton(
            onPressed: () { Navigator.pop(dialogContext); context.go('/sales/history'); },
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
    try {
      final bytes = await ReceiptService.generateEscPos(_lastReceiptData!);
      final success = await ReceiptService.printViaBluetooth(bytes);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Bluetooth printer found. Connect a printer and try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  Future<void> _shareReceiptPdf() async {
    if (_lastReceiptData == null) return;
    try {
      final qrUrl = 'https://hwos.app/receipts/${_lastReceiptData!.receiptNumber}';
      await ReceiptService.sharePdf(_lastReceiptData!, isA4: true, qrData: qrUrl);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
    }
  }

  void _showCustomerPicker() {
    _loadCustomers();
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _customers.where((c) =>
              c.fullName.toLowerCase().contains(searchCtrl.text.toLowerCase()) ||
              c.phoneNumber.contains(searchCtrl.text)).toList();
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Text('Select Customer', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCreateCustomerDialog();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                  ),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                height: 300,
                child: _loadingCustomers
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('No customers found'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                                  child: Text(c.fullName[0].toUpperCase(),
                                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                                ),
                                title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(c.phoneNumber, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                trailing: c.currentBalance > 0
                                    ? Text(_fmt.format(c.currentBalance),
                                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 13))
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCustomerId = c.id;
                                    _selectedCustomerName = c.fullName;
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

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        Future<void> submit() async {
          final name = nameCtrl.text.trim();
          final phone = phoneCtrl.text.trim();
          if (name.isEmpty || phone.isEmpty) return;

          setDialogState(() => isSaving = true);
          try {
            final bizId = context.read<AuthProvider>().businessId!;
            final res = await FunctionsService.call('createCustomer', {
              'businessId': bizId,
              'fullName': name,
              'phoneNumber': phone,
            });
            
            final newId = res['customerId'] as String;
            final newCustomer = Customer(
              id: newId, businessId: bizId, fullName: name, phoneNumber: phone,
              creditLimit: 0, currentBalance: 0, totalDebt: 0,
              createdAt: DateTime.now(), updatedAt: DateTime.now(),
            );

            if (mounted) {
              setState(() {
                _customers.insert(0, newCustomer);
                _selectedCustomerId = newId;
                _selectedCustomerName = name;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Customer $name created!')));
            }
          } catch (e) {
            if (mounted) {
              setDialogState(() => isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
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
              decoration: const InputDecoration(labelText: 'Phone Number (e.g. 07...)'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
          ]),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : submit,
              child: isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        );
      },
    ));
  }

  void _showHardwareCalculators() {
    showDialog(context: context, builder: (ctx) => const _HardwareCalculatorsDialog());
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f9): CheckoutIntent.key,
        LogicalKeySet(LogicalKeyboardKey.f12): ClearCartIntent.key,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): FocusSearchIntent.key,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.space): FocusSearchIntent.key,
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CheckoutIntent: CallbackAction<CheckoutIntent>(onInvoke: (_) { if (!_processingCheckout) _checkout(); return null; }),
          ClearCartIntent: CallbackAction<ClearCartIntent>(onInvoke: (_) { _clearCart(); return null; }),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(onInvoke: (_) { FocusScope.of(context).requestFocus(_searchFocusNode); return null; }),
        },
        child: BarcodeListener(
          onBarcodeScanned: _handleBarcodeScanned,
          child: LoadingOverlay(
            isLoading: _processingCheckout,
            message: 'Processing sale...',
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: isWide ? _wideLayout() : _narrowLayout(),
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
          Expanded(child: Text('POS — New Sale',
            style: theme.textTheme.displayMedium)),
          TextButton.icon(
            onPressed: () => _showHardwareCalculators(),
            icon: const Icon(Icons.calculate_rounded, size: 16),
            label: const Text('Calculators'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _showHeldCarts(context),
            icon: const Icon(Icons.inventory_2_rounded, size: 16),
            label: const Text('Held Carts'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => context.go('/sales/history'),
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
                    onPressed: () { _searchCtrl.clear(); _filter(); })
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
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        Expanded(
          child: _loadingProducts
              ? const Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.accent)))
              : _filtered.isEmpty
                  ? Center(child: Text('No products found.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
                          product: p, inCart: inCart, onTap: () => _addToCart(p), theme: theme);
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
          const Icon(Icons.shopping_cart_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Cart', style: theme.textTheme.headlineMedium),
          const Spacer(),
          if (_cart.isNotEmpty)
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                child: Text('${_cart.length}',
                  style: TextStyle(color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.pause_circle_outline, color: AppColors.accent),
                onPressed: () => _holdCart(context),
                tooltip: 'Hold Cart',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
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
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.shopping_cart_outlined, color: theme.hintColor, size: 48),
                    const SizedBox(height: 12),
                    Text('Cart is empty', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text('Tap a product to add it.',
                      style: TextStyle(color: theme.hintColor, fontSize: 12)),
                  ]))
              : ListView.separated(
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (_, i) {
                    final e = _cart[i];
                    return _CartTile(
                      entry: e, fmt: _fmt, theme: theme,
                      onRemove: () => _removeFromCart(e.product.id),
                      onUpdate: (updated) => _updateCartEntry(e.product.id, updated),
                    );
                  },
                ),
        ),

        if (_cart.isNotEmpty) ...[
          Divider(height: 20, color: theme.dividerColor),
          Text('Payment Method',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            _PayBtn(label: 'Cash',  value: 'cash',
              selected: _paymentMethod, onTap: (v) => setState(() => _paymentMethod = v), theme: theme),
            const SizedBox(width: 8),
            _PayBtn(label: 'M-Pesa', value: 'mpesa',
              selected: _paymentMethod, onTap: (v) => setState(() => _paymentMethod = v), theme: theme),
            const SizedBox(width: 8),
            _PayBtn(label: 'Credit', value: 'credit',
              selected: _paymentMethod, onTap: (v) => setState(() => _paymentMethod = v), theme: theme),
          ]),
          const SizedBox(height: 16),

          if (_paymentMethod == 'cash') ...[
            TextField(
              controller: _amountPaidCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Amount tendered (optional)',
                prefixText: 'KES ',
                prefixStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
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
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16));
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 12),
          ],

          if (_paymentMethod == 'credit') ...[
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
                    child: _selectedCustomerId != null
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Customer', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                            Text(_selectedCustomerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ])
                        : Text('Select Customer *', style: TextStyle(color: theme.hintColor, fontSize: 13)),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountPaidCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Amount paid (optional)',
                prefixText: 'KES ',
                prefixStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _TotalRow('Subtotal', _fmt.format(_cartTotal), theme: theme),
              const SizedBox(height: 4),
              _TotalRow('Profit',   _fmt.format(_cartProfit), color: AppColors.success, theme: theme),
              if (_paymentMethod == 'credit' && _selectedCustomerId != null) ...[
                const SizedBox(height: 4),
                _TotalRow('Customer', _selectedCustomerName, color: AppColors.accent, theme: theme),
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => _cart.clear()),
            child: const Text('Clear Cart'),
          ),
        ],
      ]),
    );
  }

  Widget _miniCartBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(Responsive.padding(context), 12, Responsive.padding(context), 20),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_cart.length} item(s)',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          Text(_fmt.format(_cartTotal),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
              color: theme.colorScheme.onSurface)),
        ])),
        ElevatedButton(
          onPressed: _checkout,
          child: const Text('Checkout'),
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
  
  _CartEntry({required this.product, required this.qty, this.overridePrice, this.note});
  
  double get appliedPrice => overridePrice ?? product.sellingPrice;
  double get lineTotal  => appliedPrice * qty;
  double get lineProfit => (appliedPrice - product.costPrice) * qty;
  
  _CartEntry copyWith({Product? product, double? qty, double? overridePrice, String? note}) {
    return _CartEntry(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      overridePrice: overridePrice ?? this.overridePrice,
      note: note ?? this.note,
    );
  }
  
  Map<String, dynamic> toMap() => {
    'productId':    product.id,
    'name':         product.name,
    'quantity':     qty,
    'sellingPrice': appliedPrice,
    'costPrice':    product.costPrice,
    if (overridePrice != null) 'overridePrice': overridePrice,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final bool inCart;
  final VoidCallback onTap;
  final ThemeData theme;
  const _ProductTile({required this.product, required this.inCart, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) => Material(
    color: inCart ? AppColors.accent.withValues(alpha: 0.1) : theme.cardColor,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (inCart) const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 16),
            ]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KES ${product.sellingPrice.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppColors.accent,
                    fontWeight: FontWeight.w700, fontSize: 14)),
                Text('Stock: ${product.quantity}',
                  style: TextStyle(color: theme.hintColor, fontSize: 11)),
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
  const _CartTile({required this.entry, required this.fmt, required this.theme,
    required this.onRemove, required this.onUpdate});

  void _showEditQtyDialog(BuildContext context) {
    final ctrl = TextEditingController(text: entry.qty.toString());
    void submit() {
      final val = double.tryParse(ctrl.text);
      if (val != null && val >= 0) {
        onUpdate(entry.copyWith(qty: val));
        Navigator.pop(context);
      }
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Quantity'),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity'),
        autofocus: true,
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: submit,
          child: const Text('Save'),
        ),
      ],
    ));
  }

  void _showEditPriceDialog(BuildContext context) {
    final ctrl = TextEditingController(text: entry.appliedPrice.toStringAsFixed(2));
    void submit() {
      final val = double.tryParse(ctrl.text);
      if (val != null && val >= 0) {
        onUpdate(entry.copyWith(overridePrice: val));
        Navigator.pop(context);
      }
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Override Price'),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'New Unit Price'),
        autofocus: true,
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
             onUpdate(entry.copyWith(overridePrice: null)); // Clear override
             Navigator.pop(ctx);
          },
          child: const Text('Reset', style: TextStyle(color: AppColors.error)),
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
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Item Note'),
      content: TextField(
        controller: ctrl,
        maxLines: 2,
        decoration: const InputDecoration(hintText: 'e.g. Cut into 2m pieces'),
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: submit,
          child: const Text('Save'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.product.name,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
            color: theme.colorScheme.onSurface),
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(
          children: [
            GestureDetector(
              onTap: () => _showEditPriceDialog(context),
              child: Text(
                fmt.format(entry.appliedPrice),
                style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: AppColors.accent, decorationStyle: TextDecorationStyle.dashed),
              ),
            ),
            if (entry.overridePrice != null && entry.overridePrice != entry.product.sellingPrice) ...[
              const SizedBox(width: 6),
              Text(fmt.format(entry.product.sellingPrice),
                style: TextStyle(color: theme.hintColor, fontSize: 10, decoration: TextDecoration.lineThrough)),
            ],
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showNoteDialog(context),
              child: Icon(Icons.note_add_rounded, size: 14, color: entry.note != null && entry.note!.isNotEmpty ? AppColors.accent : theme.hintColor),
            ),
          ],
        ),
        if (entry.note != null && entry.note!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(entry.note!, style: TextStyle(color: theme.hintColor, fontSize: 10, fontStyle: FontStyle.italic)),
        ],
      ])),
      Row(children: [
        _QtyBtn(icon: Icons.remove, onTap: () => onUpdate(entry.copyWith(qty: entry.qty - 1)), theme: theme),
        GestureDetector(
          onTap: () => _showEditQtyDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(entry.qty.toStringAsFixed(entry.qty.truncateToDouble() == entry.qty ? 0 : 2),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                color: theme.colorScheme.onSurface,
                decoration: TextDecoration.underline)),
          ),
        ),
        _QtyBtn(icon: Icons.add, onTap: () => onUpdate(entry.copyWith(qty: entry.qty + 1)), theme: theme),
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
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
    ),
  );
}

class _PayBtn extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  final ThemeData theme;
  const _PayBtn({required this.label, required this.value,
    required this.selected, required this.onTap, required this.theme});
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
            border: Border.all(color: sel ? AppColors.accent : theme.dividerColor)),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
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
      Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
      Text(value,  style: TextStyle(
        color: color ?? theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700, fontSize: 14)),
    ],
  );
}

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final ThemeData theme;
  const _ReceiptRow(this.label, this.value, {this.valueColor, required this.theme});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      Text(value,  style: TextStyle(fontWeight: FontWeight.w700,
        color: valueColor ?? theme.colorScheme.onSurface)),
    ]),
  );
}

class _HardwareCalculatorsDialog extends StatefulWidget {
  const _HardwareCalculatorsDialog();
  @override
  State<_HardwareCalculatorsDialog> createState() => _HardwareCalculatorsDialogState();
}

class _HardwareCalculatorsDialogState extends State<_HardwareCalculatorsDialog> {
  String _mode = 'Tile';
  final _roomLCtrl = TextEditingController();
  final _roomWCtrl = TextEditingController();
  final _itemLCtrl = TextEditingController();
  final _itemWCtrl = TextEditingController();
  final _coverageCtrl = TextEditingController(); // for paint
  
  double? _resultQty;
  double? _resultArea;

  void _calculate() {
    setState(() {
      _resultQty = null;
      _resultArea = null;
      final rl = double.tryParse(_roomLCtrl.text) ?? 0;
      final rw = double.tryParse(_roomWCtrl.text) ?? 0;
      if (rl <= 0 || rw <= 0) return;
      
      final roomArea = rl * rw;
      _resultArea = roomArea;

      if (_mode == 'Tile') {
        final il = double.tryParse(_itemLCtrl.text) ?? 0;
        final iw = double.tryParse(_itemWCtrl.text) ?? 0;
        if (il > 0 && iw > 0) {
          // item dimensions in cm, convert to meters
          final itemArea = (il / 100) * (iw / 100);
          _resultQty = roomArea / itemArea;
        }
      } else if (_mode == 'Paint') {
        final coverage = double.tryParse(_coverageCtrl.text) ?? 10; // default 10 sqm per liter
        if (coverage > 0) {
          _resultQty = roomArea / coverage;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Hardware Calculators', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _mode,
            items: ['Tile', 'Paint'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) {
              if (v != null) setState(() { _mode = v; _resultQty = null; _resultArea = null; });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: _roomLCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Room Length (m)'), onChanged: (_) => _calculate())),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _roomWCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Room Width (m)'), onChanged: (_) => _calculate())),
          ]),
          const SizedBox(height: 16),
          if (_mode == 'Tile') ...[
            Row(children: [
              Expanded(child: TextField(controller: _itemLCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tile Length (cm)'), onChanged: (_) => _calculate())),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _itemWCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tile Width (cm)'), onChanged: (_) => _calculate())),
            ]),
          ] else if (_mode == 'Paint') ...[
            TextField(controller: _coverageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coverage (sqm per L) - Default 10'), onChanged: (_) => _calculate()),
          ],
          const SizedBox(height: 24),
          if (_resultArea != null)
            Text('Total Area: ${_resultArea!.toStringAsFixed(2)} sqm', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_resultQty != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(
                _mode == 'Tile' ? 'Tiles Needed: ${_resultQty!.ceil()} (approx)' : 'Paint Needed: ${_resultQty!.toStringAsFixed(1)} Liters',
                style: const TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
