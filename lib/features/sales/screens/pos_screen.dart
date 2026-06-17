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
import '../services/offline_sales_queue.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

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
        final qty = item['qty'] as int;
        loaded.add(_CartEntry(product: Product.fromMap(prodMap), qty: qty));
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
          'createdAt': e.product.createdAt.toIso8601String(),
          'updatedAt': e.product.updatedAt.toIso8601String(),
        },
        'qty': e.qty,
      }).toList(),
    );
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
      final data  = await FunctionsService.call('getProducts', {'businessId': bizId, 'limit': 200});
      final rawList = (data['products'] as List?) ?? [];
      final prods = rawList
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((p) => !p.isOutOfStock)
          .toList();
      if (mounted) setState(() { _allProducts = prods; _filtered = prods; _loadingProducts = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loadingProducts = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allProducts
          : _allProducts.where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q)).toList();
    });
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

  void _updateQty(String productId, int newQty) {
    setState(() {
      final idx = _cart.indexWhere((e) => e.product.id == productId);
      if (idx >= 0) {
        if (newQty <= 0) {
          _cart.removeAt(idx);
        } else if (newQty <= _cart[idx].product.quantity) {
          _cart[idx] = _cart[idx].copyWith(qty: newQty);
        }
      }
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
              price: e.product.sellingPrice, subtotal: e.lineTotal,
            )).toList(),
            subtotal: saleTotal,
            grandTotal: saleTotal,
            paymentMethod: _paymentMethod,
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
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
              label: const Text('Print'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _shareReceiptPdf();
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share PDF'),
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

  Future<void> _printReceipt(BuildContext context) async {
    if (_lastReceiptData == null) return;
    try {
      final bytes = await ReceiptService.generateEscPos(_lastReceiptData!);
      final success = await ReceiptService.printViaBluetooth(bytes);
      if (!success && mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Bluetooth printer found. Connect a printer and try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  Future<void> _shareReceiptPdf() async {
    if (_lastReceiptData == null) return;
    try {
      await ReceiptService.sharePdf(_lastReceiptData!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return LoadingOverlay(
      isLoading: _processingCheckout,
      message: 'Processing sale...',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: isWide ? _wideLayout() : _narrowLayout(),
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
            onPressed: () => context.go('/sales/history'),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('History'),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _searchCtrl,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search products...',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
              child: Text('${_cart.length}',
                style: TextStyle(color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800, fontSize: 12)),
            ),
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
                      onRemove:    () => _removeFromCart(e.product.id),
                      onQtyChange: (q) => _updateQty(e.product.id, q),
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
  final int qty;
  const _CartEntry({required this.product, required this.qty});
  double get lineTotal  => product.sellingPrice * qty;
  double get lineProfit => (product.sellingPrice - product.costPrice) * qty;
  _CartEntry copyWith({int? qty}) => _CartEntry(product: product, qty: qty ?? this.qty);
  Map<String, dynamic> toMap() => {
    'productId':    product.id,
    'name':         product.name,
    'quantity':     qty,
    'sellingPrice': product.sellingPrice,
    'costPrice':    product.costPrice,
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
  final ValueChanged<int> onQtyChange;
  const _CartTile({required this.entry, required this.fmt, required this.theme,
    required this.onRemove, required this.onQtyChange});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.product.name,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
            color: theme.colorScheme.onSurface),
          overflow: TextOverflow.ellipsis),
        Text(fmt.format(entry.lineTotal),
          style: const TextStyle(color: AppColors.accent,
            fontSize: 12, fontWeight: FontWeight.w600)),
      ])),
      Row(children: [
        _QtyBtn(icon: Icons.remove, onTap: () => onQtyChange(entry.qty - 1), theme: theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${entry.qty}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
              color: theme.colorScheme.onSurface)),
        ),
        _QtyBtn(icon: Icons.add, onTap: () => onQtyChange(entry.qty + 1), theme: theme),
      ]),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onRemove,
        child: Icon(Icons.delete_outline_rounded,
          color: theme.hintColor, size: 18)),
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
