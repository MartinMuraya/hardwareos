import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _skuCtrl     = TextEditingController();
  final _qtyCtrl     = TextEditingController(text: '0');
  final _costCtrl    = TextEditingController();
  final _priceCtrl   = TextEditingController();
  final _reorderCtrl = TextEditingController(text: '5');
  String _category   = 'General';
  bool _isSubmitting = false;
  String? _error;

  bool _isBulkEnabled = false;
  bool _isBulkParent = true;
  String? _parentProductId;
  double? _conversionRatio;
  String _baseUnit = '';
  String _sellingUnit = '';
  List<Map<String, dynamic>> _allProducts = [];
  bool _loadingProducts = false;

  static const _categories = [
    'General', 'Plumbing', 'Electrical', 'Tools', 'Paint',
    'Fasteners', 'Lumber', 'Safety', 'Gardening', 'Roofing',
    'Tiles & Flooring', 'Other',
  ];

  Future<void> _loadProducts() async {
    if (_allProducts.isNotEmpty) return;
    setState(() => _loadingProducts = true);
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getProducts', {'businessId': bizId, 'limit': 200});
      final raw = (data['products'] as List?) ?? [];
      _allProducts = raw.cast<Map<String, dynamic>>();
    } catch (_) {}
    setState(() => _loadingProducts = false);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _skuCtrl, _qtyCtrl, _costCtrl, _priceCtrl, _reorderCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _margin {
    final cost  = double.tryParse(_costCtrl.text)  ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (price <= 0) return 0;
    return ((price - cost) / price) * 100;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSubmitting = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final baseParams = {
        'businessId':   bizId,
        'name':         _nameCtrl.text.trim(),
        'sku':          _skuCtrl.text.trim(),
        'category':     _category,
        'quantity':     int.parse(_qtyCtrl.text),
        'costPrice':    double.parse(_costCtrl.text),
        'sellingPrice': double.parse(_priceCtrl.text),
        'reorderLevel': int.parse(_reorderCtrl.text),
      };

      if (_isBulkEnabled) {
        await FunctionsService.call('bulkCreateProduct', {
          ...baseParams,
          'isBulkParent': _isBulkParent,
          'isBulkChild': !_isBulkParent,
          'parentProductId': _parentProductId,
          'conversionRatio': _conversionRatio,
          'baseUnit': _baseUnit.isEmpty ? null : _baseUnit,
          'sellingUnit': _sellingUnit.isEmpty ? null : _sellingUnit,
        });
      } else {
        await FunctionsService.call('createProduct', baseParams);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')));
        context.pop();
      }
    } on FunctionsException catch (e) {
      setState(() { _error = e.message; _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LoadingOverlay(
      isLoading: _isSubmitting,
      message: 'Adding product...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Add Product'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.padding(context)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _ErrorCard(message: _error!, theme: theme),

                    _Section(title: 'Product Info', theme: theme, children: [
                      TextFormField(
                        controller: _nameCtrl,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: const InputDecoration(labelText: 'Product Name'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _skuCtrl,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: const InputDecoration(labelText: 'SKU (optional)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            dropdownColor: theme.cardColor,
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: _categories.map((c) =>
                              DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 20),

                    _Section(title: 'Pricing', theme: theme, children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: const InputDecoration(labelText: 'Cost Price (KES)'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              return n == null || n < 0 ? 'Enter valid price' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: const InputDecoration(labelText: 'Selling Price (KES)'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              return n == null || n <= 0 ? 'Must be > 0' : null;
                            },
                          ),
                        ),
                      ]),
                      if (_costCtrl.text.isNotEmpty && _priceCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _MarginBar(margin: _margin, theme: theme),
                      ],
                    ]),
                    const SizedBox(height: 20),

                    _Section(title: 'Stock', theme: theme, children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: const InputDecoration(labelText: 'Initial Quantity'),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 0 ? 'Enter valid quantity' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _reorderCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: const InputDecoration(labelText: 'Reorder Level'),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 0 ? 'Enter valid number' : null;
                            },
                          ),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 20),

                    _Section(title: 'Bulk Configuration', theme: theme, children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Bulk Product'),
                        subtitle: Text(_isBulkEnabled
                          ? (_isBulkParent ? 'Configured as Bulk Parent' : 'Configured as Bulk Child')
                          : 'Allow selling in sub-units'),
                        value: _isBulkEnabled,
                        onChanged: (v) => setState(() => _isBulkEnabled = v),
                      ),
                      if (_isBulkEnabled) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Bulk Parent'),
                              selected: _isBulkParent,
                              onSelected: (v) => setState(() => _isBulkParent = true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Bulk Child'),
                              selected: !_isBulkParent,
                              onSelected: (v) {
                                setState(() => _isBulkParent = false);
                                _loadProducts();
                              },
                            ),
                          ),
                        ]),
                        if (!_isBulkParent) ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _parentProductId,
                            dropdownColor: theme.cardColor,
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                            decoration: const InputDecoration(labelText: 'Parent Product'),
                            items: _loadingProducts
                              ? [const DropdownMenuItem(value: null, child: Text('Loading...'))]
                              : _allProducts.map((p) => DropdownMenuItem(
                                  value: p['id'] as String,
                                  child: Text(p['name'] as String? ?? ''),
                                )).toList(),
                            onChanged: (v) => setState(() => _parentProductId = v),
                            validator: (v) => _isBulkEnabled && !_isBulkParent && v == null ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: const InputDecoration(
                              labelText: 'Conversion Ratio (1 parent = ? child)',
                              hintText: 'e.g. 12 for pieces per box',
                            ),
                            onChanged: (v) => _conversionRatio = double.tryParse(v),
                            validator: (v) => _isBulkEnabled && !_isBulkParent && (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                              ? 'Enter valid ratio > 0' : null,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(labelText: 'Base Unit (e.g., Box)'),
                              onChanged: (v) => _baseUnit = v,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(labelText: 'Selling Unit (e.g., Piece)'),
                              onChanged: (v) => _sellingUnit = v,
                            ),
                          ),
                        ]),
                      ],
                    ]),
                    const SizedBox(height: 32),

                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save Product'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final ThemeData theme;
  const _Section({required this.title, required this.children, required this.theme});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(
        color: theme.colorScheme.onSurfaceVariant, fontSize: 12,
        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ],
  );
}

class _MarginBar extends StatelessWidget {
  final double margin;
  final ThemeData theme;
  const _MarginBar({required this.margin, required this.theme});
  @override
  Widget build(BuildContext context) {
    final color = margin < 0
        ? AppColors.error
        : margin < 15 ? AppColors.warning : AppColors.success;
    return Row(children: [
      Text('Margin: ', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
      Text('${margin.toStringAsFixed(1)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(width: 10),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (margin / 100).clamp(0.0, 1.0),
            backgroundColor: theme.dividerColor,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ),
    ]);
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final ThemeData theme;
  const _ErrorCard({required this.message, required this.theme});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
        style: const TextStyle(color: AppColors.error, fontSize: 13))),
    ]),
  );
}
