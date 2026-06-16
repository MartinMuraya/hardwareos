import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/product.dart';
import '../../../core/models/supplier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';

class _POLine {
  String productId = '';
  String productName = '';
  int quantity = 1;
  double unitCost = 0;
  double get total => unitCost * quantity;
}

class AddPurchaseOrderScreen extends StatefulWidget {
  const AddPurchaseOrderScreen({super.key});
  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedSupplierId;
  final List<_POLine> _lines = [];
  bool _submitting = false;
  String? _error;

  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() { super.initState(); _loadData(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final results = await Future.wait([
        FunctionsService.call('getSuppliers', {'businessId': bizId, 'limit': 200}),
        FunctionsService.call('getProducts', {'businessId': bizId, 'limit': 200}),
      ]);
      _suppliers = ((results[0]['suppliers'] as List?) ?? [])
          .map((e) => Supplier.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _products = ((results[1]['products'] as List?) ?? [])
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.total);
  double get _total => _subtotal;

  void _addLine() => setState(() => _lines.add(_POLine()));
  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  void _pickSupplier() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final q = searchCtrl.text.toLowerCase();
          final filtered = _suppliers.where((s) =>
            s.name.toLowerCase().contains(q) || s.phoneNumber.contains(q)).toList();
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Text('Select Supplier', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (_) => setSheetState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: filtered.isEmpty
                  ? const Center(child: Text('No suppliers found'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (_, idx) {
                        final s = filtered[idx];
                        return ListTile(
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(s.phoneNumber, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            setState(() {
                              _selectedSupplierId = s.id;
                              _nameCtrl.text = s.name;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ]);
        });
      },
    );
  }

  void _pickProduct(int i) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final q = searchCtrl.text.toLowerCase();
          final filtered = _products.where((p) =>
            p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)).toList();
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Text('Select Product', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (_) => setSheetState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: filtered.isEmpty
                  ? const Center(child: Text('No products found'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (_, idx) {
                        final p = filtered[idx];
                        return ListTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('Cost: ${_fmt.format(p.costPrice)}  •  Stock: ${p.quantity}',
                            style: const TextStyle(fontSize: 12)),
                          trailing: Text(_fmt.format(p.costPrice),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
                          onTap: () {
                            setState(() {
                              _lines[i].productId = p.id;
                              _lines[i].productName = p.name;
                              _lines[i].unitCost = p.costPrice;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ]);
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one product line.');
      return;
    }
    if (_lines.every((l) => l.productName.isEmpty)) {
      setState(() => _error = 'Select products for all lines.');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('createPurchaseOrder', {
        'businessId': bizId,
        'supplierId': _selectedSupplierId ?? '',
        'supplierName': _nameCtrl.text.trim(),
        'items': _lines.map((l) => {
          'productId': l.productId,
          'name': l.productName,
          'quantity': l.quantity,
          'unitCost': l.unitCost,
        }).toList(),
        'notes': _notesCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase order created successfully.')),
        );
        context.pop(true);
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _submitting,
      message: 'Creating purchase order...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('New Purchase Order'),
          actions: [
            TextButton(onPressed: _submitting ? null : _submit, child: const Text('Save')),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ]),
                    ),

                  _Section(label: 'Supplier', child: Column(children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Supplier Name *',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.person_search_rounded, size: 20),
                          onPressed: _pickSupplier,
                          tooltip: 'Select existing supplier',
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ])),
                  const SizedBox(height: 20),

                  _Section(label: 'Items', child: Column(children: [
                    ...List.generate(_lines.length, (i) {
                      final line = _lines[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: () => _pickProduct(i),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Product',
                                    hintText: line.productName.isEmpty ? 'Tap to select' : null,
                                    suffixIcon: const Icon(Icons.search, size: 18),
                                  ),
                                  controller: TextEditingController(text: line.productName),
                                  validator: (v) => line.productName.isEmpty ? 'Select product' : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: line.quantity.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Qty'),
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null && n > 0) setState(() => _lines[i].quantity = n);
                              },
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                return n == null || n <= 0 ? 'Invalid' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: line.unitCost > 0 ? line.unitCost.toStringAsFixed(0) : '',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Unit Cost'),
                              onChanged: (v) {
                                final n = double.tryParse(v);
                                if (n != null && n > 0) setState(() => _lines[i].unitCost = n);
                              },
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                return n == null || n <= 0 ? 'Invalid' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                            onPressed: () => _removeLine(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
                          ),
                        ]),
                      );
                    }),
                    OutlinedButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Item'),
                    ),
                  ])),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: _Row(label: 'Total', value: _fmt.format(_total), theme: theme),
                  ),
                  const SizedBox(height: 20),

                  _Section(label: 'Notes', child: Column(children: [
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 3,
                    ),
                  ])),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Create Purchase Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: child,
      ),
    ]);
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final ThemeData theme;
  const _Row({required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.accent)),
    ],
  );
}
