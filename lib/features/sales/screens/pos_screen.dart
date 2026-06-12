import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_overlay.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final List<_CartEntry> _cart = [];
  String _paymentMethod = 'cash';

  final _searchCtrl  = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filtered    = [];
  bool _loadingProducts      = true;
  bool _processingCheckout   = false;
  String? _error;

  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() { super.initState(); _loadProducts(); _searchCtrl.addListener(_filter); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

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
  }

  void _removeFromCart(String productId) =>
      setState(() => _cart.removeWhere((e) => e.product.id == productId));

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
  }

  double get _cartTotal  => _cart.fold(0, (s, e) => s + e.lineTotal);
  double get _cartProfit => _cart.fold(0, (s, e) => s + e.lineProfit);

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    setState(() { _processingCheckout = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final result = await FunctionsService.call('createSale', {
        'businessId':    bizId,
        'paymentMethod': _paymentMethod,
        'items':         _cart.map((e) => e.toMap()).toList(),
      });
      if (mounted) {
        final total  = result['total']  as num;
        final profit = result['profit'] as num;
        _showReceiptDialog(total.toDouble(), profit.toDouble());
        setState(() { _cart.clear(); _processingCheckout = false; });
        _loadProducts();
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _processingCheckout = false; });
    }
  }

  void _showReceiptDialog(double total, double profit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Sale Complete!',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          _ReceiptRow('Total',  _fmt.format(total)),
          _ReceiptRow('Profit', _fmt.format(profit), valueColor: AppColors.success),
          _ReceiptRow('Method', _paymentMethod.toUpperCase()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
          ElevatedButton(
            onPressed: () { Navigator.pop(dialogContext); context.go('/sales/history'); },
            child: const Text('View History'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return LoadingOverlay(
      isLoading: _processingCheckout,
      message: 'Processing sale...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: isWide ? _wideLayout() : _narrowLayout(),
      ),
    );
  }

  Widget _wideLayout() => Row(children: [
    Expanded(flex: 3, child: _productPanel()),
    Container(width: 1, color: AppColors.border),
    SizedBox(width: 360, child: _cartPanel()),
  ]);

  Widget _narrowLayout() => Column(children: [
    Expanded(child: _productPanel()),
    if (_cart.isNotEmpty) _miniCartBar(),
  ]);

  Widget _productPanel() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('POS — New Sale',
          style: AppTheme.darkTheme.textTheme.displayMedium)),
        TextButton.icon(
          onPressed: () => context.go('/sales/history'),
          icon: const Icon(Icons.history_rounded, size: 16),
          label: const Text('History'),
        ),
      ]),
      const SizedBox(height: 16),
      TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: AppColors.textPrimary),
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
                ? const Center(child: Text('No products found.',
                    style: TextStyle(color: AppColors.textSecondary)))
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
                        product: p, inCart: inCart, onTap: () => _addToCart(p));
                    },
                  ),
      ),
    ]),
  );

  Widget _cartPanel() => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.shopping_cart_rounded, color: AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text('Cart', style: AppTheme.darkTheme.textTheme.headlineMedium),
        const Spacer(),
        if (_cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
            child: Text('${_cart.length}',
              style: const TextStyle(color: AppColors.background,
                fontWeight: FontWeight.w800, fontSize: 12)),
          ),
      ]),
      const SizedBox(height: 16),

      Expanded(
        child: _cart.isEmpty
            ? const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.shopping_cart_outlined, color: AppColors.textHint, size: 48),
                  SizedBox(height: 12),
                  Text('Cart is empty', style: TextStyle(color: AppColors.textSecondary)),
                  SizedBox(height: 6),
                  Text('Tap a product to add it.',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                ]))
            : ListView.separated(
                itemCount: _cart.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = _cart[i];
                  return _CartTile(
                    entry: e, fmt: _fmt,
                    onRemove:    () => _removeFromCart(e.product.id),
                    onQtyChange: (q) => _updateQty(e.product.id, q),
                  );
                },
              ),
      ),

      if (_cart.isNotEmpty) ...[
        const Divider(height: 20),
        const Text('Payment Method',
          style: TextStyle(color: AppColors.textSecondary,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _PayBtn(label: 'Cash',  value: 'cash',
            selected: _paymentMethod, onTap: (v) => setState(() => _paymentMethod = v)),
          const SizedBox(width: 8),
          _PayBtn(label: 'M-Pesa', value: 'mpesa',
            selected: _paymentMethod, onTap: (v) => setState(() => _paymentMethod = v)),
          const SizedBox(width: 8),
          _PayBtn(label: 'Credit', value: 'credit',
            selected: _paymentMethod, onTap: (v) => setState(() => _paymentMethod = v)),
        ]),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _TotalRow('Subtotal', _fmt.format(_cartTotal)),
            const SizedBox(height: 4),
            _TotalRow('Profit',   _fmt.format(_cartProfit), color: AppColors.success),
          ]),
        ),
        const SizedBox(height: 14),

        ElevatedButton(
          onPressed: _processingCheckout ? null : _checkout,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
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

  Widget _miniCartBar() => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_cart.length} item(s)',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text(_fmt.format(_cartTotal),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ])),
      ElevatedButton(
        onPressed: _checkout,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background),
        child: const Text('Checkout'),
      ),
    ]),
  );
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
  const _ProductTile({required this.product, required this.inCart, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: inCart ? AppColors.accent.withValues(alpha: 0.1) : AppColors.card,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart ? AppColors.accent : AppColors.border,
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
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
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
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChange;
  const _CartTile({required this.entry, required this.fmt,
    required this.onRemove, required this.onQtyChange});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.product.name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          overflow: TextOverflow.ellipsis),
        Text(fmt.format(entry.lineTotal),
          style: const TextStyle(color: AppColors.accent,
            fontSize: 12, fontWeight: FontWeight.w600)),
      ])),
      Row(children: [
        _QtyBtn(icon: Icons.remove, onTap: () => onQtyChange(entry.qty - 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${entry.qty}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        _QtyBtn(icon: Icons.add, onTap: () => onQtyChange(entry.qty + 1)),
      ]),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.delete_outline_rounded,
          color: AppColors.textHint, size: 18)),
    ]),
  );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 14, color: AppColors.textSecondary),
    ),
  );
}

class _PayBtn extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  const _PayBtn({required this.label, required this.value,
    required this.selected, required this.onTap});
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
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? AppColors.accent : AppColors.border)),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? AppColors.accent : AppColors.textSecondary,
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
  const _TotalRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Text(value,  style: TextStyle(
        color: color ?? AppColors.textPrimary,
        fontWeight: FontWeight.w700, fontSize: 14)),
    ],
  );
}

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _ReceiptRow(this.label, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      Text(value,  style: TextStyle(fontWeight: FontWeight.w700,
        color: valueColor ?? AppColors.textPrimary)),
    ]),
  );
}
