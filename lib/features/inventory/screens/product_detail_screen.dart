import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_overlay.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  String? _error;

  final _addQtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController(text: 'Stock replenishment');
  bool _submitting  = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _addQtyCtrl.dispose(); _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data  = await FunctionsService.call(
          'getProducts', {'businessId': bizId, 'limit': 200});
      final rawList = (data['products'] as List?) ?? [];
      final prod = rawList
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.id == widget.productId)
          .firstOrNull;
      if (mounted) setState(() { _product = prod; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _addStock() async {
    final qty = int.tryParse(_addQtyCtrl.text);
    if (qty == null || qty <= 0) return;
    setState(() => _submitting = true);
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('addStock', {
        'businessId': bizId,
        'productId':  widget.productId,
        'quantity':   qty,
        'reason':     _reasonCtrl.text.trim(),
      });
      _addQtyCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Added $qty units to stock.')));
        Navigator.of(context).pop();
        _load();
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showAddStockSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24,
            24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.add_box_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text('Add Stock', style: AppTheme.darkTheme.textTheme.headlineMedium),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: _addQtyCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Quantity to Add',
              prefixIcon: Icon(Icons.add)),
            autofocus: true,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _addStock,
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.background)))
                : const Text('Confirm Stock Addition'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(p?.name ?? 'Product'),
          backgroundColor: AppColors.surface,
          actions: [
            if (p != null)
              IconButton(
                icon: const Icon(Icons.add_box_outlined),
                tooltip: 'Add Stock',
                onPressed: _showAddStockSheet,
              ),
          ],
        ),
        body: p == null && !_loading
            ? Center(child: Text(_error ?? 'Product not found.',
                style: const TextStyle(color: AppColors.textSecondary)))
            : p == null ? const SizedBox()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _StockCard(product: p),
                      const SizedBox(height: 16),
                      _DetailCard(product: p),
                    ]),
                  ),
                ),
              ),
        floatingActionButton: p != null
            ? FloatingActionButton.extended(
                onPressed: _showAddStockSheet,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                icon: const Icon(Icons.add),
                label: const Text('Add Stock'),
              )
            : null,
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final Product product;
  const _StockCard({required this.product});
  @override
  Widget build(BuildContext context) {
    final color = product.isOutOfStock
        ? AppColors.stockCritical
        : product.isLowStock ? AppColors.stockLow : AppColors.stockGood;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Current Stock',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text('${product.quantity} units',
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
          Text('Reorder at ${product.reorderLevel}',
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
        ])),
        Icon(
          product.isOutOfStock
              ? Icons.remove_circle
              : product.isLowStock
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
          color: color, size: 42,
        ),
      ]),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Product product;
  const _DetailCard({required this.product});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border)),
    child: Column(children: [
      _Row('Category',      product.category),
      const _HDivider(),
      _Row('SKU',           product.sku.isEmpty ? '—' : product.sku),
      const _HDivider(),
      _Row('Cost Price',    'KES ${product.costPrice.toStringAsFixed(2)}'),
      const _HDivider(),
      _Row('Selling Price', 'KES ${product.sellingPrice.toStringAsFixed(2)}'),
      const _HDivider(),
      _Row('Margin',        '${product.margin.toStringAsFixed(1)}%'),
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      Text(value,  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.border);
}
