import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_overlay.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _skuCtrl      = TextEditingController();
  final _qtyCtrl      = TextEditingController(text: '0');
  final _costCtrl     = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _reorderCtrl  = TextEditingController(text: '5');
  String _category    = 'General';
  bool _isSubmitting  = false;
  String? _error;

  static const _categories = [
    'General', 'Plumbing', 'Electrical', 'Tools', 'Paint',
    'Fasteners', 'Lumber', 'Safety', 'Gardening', 'Roofing',
    'Tiles & Flooring', 'Other',
  ];

  @override
  void dispose() {
    for (final c in [_nameCtrl, _skuCtrl, _qtyCtrl, _costCtrl, _priceCtrl, _reorderCtrl]) c.dispose();
    super.dispose();
  }

  double get _margin {
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (price <= 0) return 0;
    return ((price - cost) / price) * 100;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSubmitting = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('createProduct', {
        'businessId':   bizId,
        'name':         _nameCtrl.text.trim(),
        'sku':          _skuCtrl.text.trim(),
        'category':     _category,
        'quantity':     int.parse(_qtyCtrl.text),
        'costPrice':    double.parse(_costCtrl.text),
        'sellingPrice': double.parse(_priceCtrl.text),
        'reorderLevel': int.parse(_reorderCtrl.text),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Product added successfully!')),
        );
        context.pop();
      }
    } on FunctionsException catch (e) {
      setState(() { _error = e.message; _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSubmitting,
      message: 'Adding product...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Add Product'),
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _ErrorCard(message: _error!),

                    _Section(title: 'Product Info', children: [
                      _Field(ctrl: _nameCtrl, label: 'Product Name', id: 'prod-name',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: _Field(ctrl: _skuCtrl, label: 'SKU (optional)', id: 'prod-sku'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _category,
                            dropdownColor: AppColors.card,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 20),

                    _Section(title: 'Pricing', children: [
                      Row(children: [
                        Expanded(
                          child: _Field(ctrl: _costCtrl, label: 'Cost Price (KES)', id: 'prod-cost',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              return n == null || n < 0 ? 'Enter valid price' : null;
                            }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(ctrl: _priceCtrl, label: 'Selling Price (KES)', id: 'prod-price',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              return n == null || n <= 0 ? 'Must be > 0' : null;
                            }),
                        ),
                      ]),
                      if (_costCtrl.text.isNotEmpty && _priceCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _MarginBar(margin: _margin),
                      ],
                    ]),
                    const SizedBox(height: 20),

                    _Section(title: 'Stock', children: [
                      Row(children: [
                        Expanded(
                          child: _Field(ctrl: _qtyCtrl, label: 'Initial Quantity', id: 'prod-qty',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 0 ? 'Enter valid quantity' : null;
                            }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(ctrl: _reorderCtrl, label: 'Reorder Level', id: 'prod-reorder',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 0 ? 'Enter valid number' : null;
                            }),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 32),

                    ElevatedButton.icon(
                      id: 'save-product',
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save Product'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
        color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600,
        letterSpacing: 0.8)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ],
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, id;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _Field({required this.ctrl, required this.label, required this.id,
    this.keyboardType, this.validator, this.onChanged});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: const TextStyle(color: AppColors.textPrimary),
    decoration: InputDecoration(labelText: label),
    validator: validator,
    onChanged: onChanged,
  );
}

class _MarginBar extends StatelessWidget {
  final double margin;
  const _MarginBar({required this.margin});
  @override
  Widget build(BuildContext context) {
    final color = margin < 0 ? AppColors.error : margin < 15 ? AppColors.warning : AppColors.success;
    return Row(children: [
      const Text('Margin: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      Text('${margin.toStringAsFixed(1)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(width: 10),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (margin / 100).clamp(0.0, 1.0),
            backgroundColor: AppColors.border,
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
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13))),
    ]),
  );
}
