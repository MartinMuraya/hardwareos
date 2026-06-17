import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  List<Map<String, dynamic>> _returns = [];
  bool _loading = true;
  String? _error;
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getReturns', {'businessId': bizId, 'limit': 100});
      final raw = (data['returns'] as List?) ?? [];
      if (mounted) setState(() { _returns = raw.cast<Map<String, dynamic>>(); _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);
    final role = context.read<AuthProvider>().userRole ?? 'staff';
    final canProcess = role == 'owner' || role == 'manager';

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading returns...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Returns & Refunds', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 4),
                  Text('${_returns.length} returns', style: theme.textTheme.bodyMedium),
                ])),
                if (canProcess)
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (_) => const ProcessReturnDialog(),
                      );
                      if (result == true) _load();
                    },
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Process Return'),
                  ),
              ]),
              const SizedBox(height: 20),

              if (_error != null)
                _ErrorBar(message: _error!, onRetry: _load, theme: theme),

              Expanded(
                child: _returns.isEmpty && !_loading
                    ? const EmptyState(
                        icon: Icons.replay_rounded,
                        title: 'No returns yet',
                        subtitle: 'Process customer returns from completed sales.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.separated(
                          itemCount: _returns.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _ReturnCard(
                            ret: _returns[i],
                            fmt: _fmt,
                            theme: theme,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  final Map<String, dynamic> ret;
  final NumberFormat fmt;
  final ThemeData theme;
  const _ReturnCard({required this.ret, required this.fmt, required this.theme});

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'Damaged': return AppColors.error;
      case 'Wrong Item': return AppColors.warning;
      case 'Defective Product': return AppColors.chartRed;
      case 'Customer Changed Mind': return AppColors.chartBlue;
      case 'Duplicate Sale': return AppColors.chartPurple;
      default: return theme.colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = ret['reason'] as String? ?? 'Other';
    final color = _reasonColor(reason);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.replay_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ret['customerName'] as String? ?? 'Walk-in',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(reason, style: TextStyle(color: color, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(ret['refundAmount'] ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.error)),
              const SizedBox(height: 2),
              Text(ret['processedByName'] as String? ?? '',
                style: theme.textTheme.bodySmall),
            ]),
          ]),
          const SizedBox(height: 8),
          Text('${(ret['items'] as List?)?.length ?? 0} items returned',
            style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------
// ProcessReturnDialog — select sale, items, reason, submit
// ---------------------------------------------------------------
class ProcessReturnDialog extends StatefulWidget {
  const ProcessReturnDialog({super.key});
  @override
  State<ProcessReturnDialog> createState() => _ProcessReturnDialogState();
}

class _ProcessReturnDialogState extends State<ProcessReturnDialog> {
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];
  Sale? _selectedSale;
  bool _loadingSales = true;
  bool _submitting = false;
  String _reason = 'Damaged';

  // Items selected for return with their quantities
  final Map<String, int> _returnQtys = {};

  static const _reasons = ['Damaged', 'Wrong Item', 'Defective Product', 'Customer Changed Mind', 'Duplicate Sale', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadSales();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filteredSales = _sales.where((s) =>
          s.id.toLowerCase().contains(q) ||
          s.paymentMethod.toLowerCase().contains(q)
        ).toList();
      });
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getSales', {'businessId': bizId, 'limit': 100});
      final raw = (data['sales'] as List?) ?? [];
      final sales = raw.map((e) => Sale.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _sales = sales; _filteredSales = sales; _loadingSales = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingSales = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedSale == null || _returnQtys.isEmpty) return;

    final items = _selectedSale!.items
      .where((item) => (_returnQtys[item.productId] ?? 0) > 0)
      .map((item) => {
        'productId': item.productId,
        'name': item.name,
        'quantity': _returnQtys[item.productId] ?? 0,
        'sellingPrice': item.sellingPrice,
        'costPrice': item.costPrice,
      })
      .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item with quantity > 0')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('processReturn', {
        'businessId': bizId,
        'saleId': _selectedSale!.id,
        'items': items,
        'reason': _reason,
        'notes': _notesCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on FunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 60,
        vertical: 24,
      ),
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 550, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Process Return',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Sale', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      if (_selectedSale == null) ...[
                        TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search sales...',
                            prefixIcon: Icon(Icons.search, size: 18),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingSales)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ))
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _filteredSales.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final s = _filteredSales[i];
                                return ListTile(
                                  dense: true,
                                  title: Text('${s.items.length} items · ${DateFormat('MMM d, HH:mm').format(s.createdAt)}',
                                    style: const TextStyle(fontSize: 13)),
                                  subtitle: Text('KES ${s.total.toStringAsFixed(0)} · ${s.paymentMethod}',
                                    style: const TextStyle(fontSize: 11)),
                                  trailing: Text('${s.items.length} items', style: const TextStyle(fontSize: 11)),
                                  onTap: () {
                                    setState(() {
                                      _selectedSale = s;
                                      _returnQtys.clear();
                                      for (final item in s.items) {
                                        _returnQtys[item.productId] = 0;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                      ] else ...[
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${_selectedSale!.items.length} items · ${_selectedSale!.paymentMethod}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Total: KES ${_selectedSale!.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12)),
                          ])),
                          TextButton(
                            onPressed: () => setState(() => _selectedSale = null),
                            child: const Text('Change'),
                          ),
                        ]),
                      ],

                      if (_selectedSale != null) ...[
                        const SizedBox(height: 16),
                        Text('Select Items to Return', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        ..._selectedSale!.items.map((item) {
                          final qty = _returnQtys[item.productId] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                Text('Sold: ${item.quantity} · KES ${item.sellingPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11)),
                              ])),
                              SizedBox(
                                width: 100,
                                child: Row(children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                    onPressed: qty > 0 ? () {
                                      setState(() => _returnQtys[item.productId] = qty - 1);
                                    } : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Text('$qty', textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    onPressed: qty < item.quantity ? () {
                                      setState(() => _returnQtys[item.productId] = qty + 1);
                                    } : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ]),
                              ),
                            ]),
                          );
                        }),
                        const SizedBox(height: 16),

                        Text('Reason', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _reason,
                          decoration: const InputDecoration(),
                          items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (v) => setState(() => _reason = v!),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Notes (optional)',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (_selectedSale != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Process Return'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  final ThemeData theme;
  const _ErrorBar({required this.message, required this.onRetry, required this.theme});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
