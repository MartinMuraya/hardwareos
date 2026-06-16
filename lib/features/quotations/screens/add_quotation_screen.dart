import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';

class _QuotationLine {
  String productId = '';
  String productName = '';
  int quantity = 1;
  double unitPrice = 0;

  double get total => unitPrice * quantity;
}

class AddQuotationScreen extends StatefulWidget {
  const AddQuotationScreen({super.key});
  @override
  State<AddQuotationScreen> createState() => _AddQuotationScreenState();
}

class _AddQuotationScreenState extends State<AddQuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _validUntilCtrl = TextEditingController();

  String? _selectedCustomerId;
  final List<_QuotationLine> _lines = [];
  String _discountType = 'fixed';
  bool _submitting = false;
  String? _error;

  List<Customer> _customers = [];
  List<Product> _products = [];
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() { super.initState(); _loadData(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _notesCtrl.dispose();
    _discountCtrl.dispose(); _validUntilCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final results = await Future.wait([
        FunctionsService.call('getCustomers', {'businessId': bizId, 'limit': 200}),
        FunctionsService.call('getProducts', {'businessId': bizId, 'limit': 200}),
      ]);
      _customers = ((results[0]['customers'] as List?) ?? [])
          .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _products = ((results[1]['products'] as List?) ?? [])
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((p) => !p.isOutOfStock)
          .toList();
    } catch (_) {}
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.total);
  double get _discountAmount {
    if (_discountType == 'percentage') {
      final pct = double.tryParse(_discountCtrl.text) ?? 0;
      return _subtotal * (pct / 100);
    }
    return double.tryParse(_discountCtrl.text) ?? 0;
  }
  double get _total => (_subtotal - _discountAmount).clamp(0, _subtotal);

  void _addLine() {
    setState(() => _lines.add(_QuotationLine()));
  }

  void _removeLine(int i) {
    setState(() => _lines.removeAt(i));
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
                          subtitle: Text('${_fmt.format(p.sellingPrice)}  •  Stock: ${p.quantity}',
                            style: const TextStyle(fontSize: 12)),
                          trailing: Text(_fmt.format(p.sellingPrice),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
                          onTap: () {
                            setState(() {
                              _lines[i].productId = p.id;
                              _lines[i].productName = p.name;
                              _lines[i].unitPrice = p.sellingPrice;
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

  void _pickCustomer() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final q = searchCtrl.text.toLowerCase();
          final filtered = _customers.where((c) =>
            c.fullName.toLowerCase().contains(q) || c.phoneNumber.contains(q)).toList();
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
                decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (_) => setSheetState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: filtered.isEmpty
                  ? const Center(child: Text('No customers found'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (_, idx) {
                        final c = filtered[idx];
                        return ListTile(
                          title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(c.phoneNumber, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            setState(() {
                              _selectedCustomerId = c.id;
                              _nameCtrl.text = c.fullName;
                              _phoneCtrl.text = c.phoneNumber;
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
      final validUntil = _validUntilCtrl.text.isNotEmpty
          ? '${_validUntilCtrl.text}T23:59:59'
          : null;

      await FunctionsService.call('createQuotation', {
        'businessId': bizId,
        'customerId': _selectedCustomerId ?? '',
        'customerName': _nameCtrl.text.trim(),
        'customerPhone': _phoneCtrl.text.trim(),
        'items': _lines.map((l) => {
          'productId': l.productId,
          'name': l.productName,
          'quantity': l.quantity,
          'unitPrice': l.unitPrice,
        }).toList(),
        'discount': double.tryParse(_discountCtrl.text) ?? 0,
        'discountType': _discountType,
        'validUntil': validUntil,
        'notes': _notesCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation created successfully.')),
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
      message: 'Creating quotation...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('New Quotation'),
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

                  // Customer section
                  _Section(label: 'Customer', child: Column(children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.person_search_rounded, size: 20),
                          onPressed: _pickCustomer,
                          tooltip: 'Select existing customer',
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone (optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                  ])),
                  const SizedBox(height: 20),

                  // Items section
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
                                if (n != null && n > 0) {
                                  setState(() => _lines[i].quantity = n);
                                }
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
                              initialValue: line.unitPrice > 0 ? line.unitPrice.toStringAsFixed(0) : '',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Price'),
                              onChanged: (v) {
                                final n = double.tryParse(v);
                                if (n != null && n > 0) {
                                  setState(() => _lines[i].unitPrice = n);
                                }
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

                  // Totals
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(children: [
                      _Row(label: 'Subtotal', value: _fmt.format(_subtotal), theme: theme),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Text('Discount',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13))),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _discountCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              suffixText: _discountType == 'percentage' ? '%' : 'KES',
                              suffixStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'fixed', label: Text('KES', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'percentage', label: Text('%', style: TextStyle(fontSize: 11))),
                          ],
                          selected: {_discountType},
                          onSelectionChanged: (v) => setState(() => _discountType = v.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ]),
                      if (_discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        _Row(label: 'Discount Amount', value: '-${_fmt.format(_discountAmount)}',
                          color: AppColors.error, theme: theme),
                      ],
                      const Divider(height: 20),
                      _Row(label: 'Total', value: _fmt.format(_total),
                        color: AppColors.accent, bold: true, theme: theme),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Additional options
                  _Section(label: 'Additional Options', child: Column(children: [
                    TextFormField(
                      controller: _validUntilCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Valid Until (optional)',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                    child: const Text('Create Quotation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
  final Color? color;
  final bool bold;
  final ThemeData theme;
  const _Row({required this.label, required this.value, this.color, this.bold = false, required this.theme});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
      Text(value, style: TextStyle(
        color: color ?? theme.colorScheme.onSurface,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontSize: bold ? 15 : 13,
      )),
    ],
  );
}
