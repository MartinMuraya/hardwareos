import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class AdjustmentScreen extends StatefulWidget {
  const AdjustmentScreen({super.key});
  @override
  State<AdjustmentScreen> createState() => _AdjustmentScreenState();
}

class _AdjustmentScreenState extends State<AdjustmentScreen> {
  List<Map<String, dynamic>> _adjustments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getStockAdjustments', {'businessId': bizId, 'limit': 100});
      final raw = (data['adjustments'] as List?) ?? [];
      if (mounted) setState(() { _adjustments = raw.cast<Map<String, dynamic>>(); _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);
    final role = context.read<AuthProvider>().userRole ?? 'staff';
    final canAdjust = role == 'owner' || role == 'manager';

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading adjustments...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Stock Adjustments', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 4),
                  Text('${_adjustments.length} adjustments',
                    style: theme.textTheme.bodyMedium),
                ])),
                if (canAdjust)
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (_) => const AdjustStockDialog(),
                      );
                      if (result == true) _load();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adjust Stock'),
                  ),
              ]),
              const SizedBox(height: 20),

              if (_error != null)
                _ErrorBar(message: _error!, onRetry: _load, theme: theme),

              Expanded(
                child: _adjustments.isEmpty && !_loading
                    ? const EmptyState(
                        icon: Icons.balance_rounded,
                        title: 'No adjustments yet',
                        subtitle: 'Adjust stock when items are damaged, lost, or expired.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.separated(
                          itemCount: _adjustments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _AdjustmentCard(
                            adj: _adjustments[i],
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

class _AdjustmentCard extends StatelessWidget {
  final Map<String, dynamic> adj;
  final ThemeData theme;
  const _AdjustmentCard({required this.adj, required this.theme});

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'Damaged': return AppColors.error;
      case 'Lost': return AppColors.warning;
      case 'Expired': return AppColors.chartRed;
      case 'Stolen': return AppColors.error;
      case 'Physical Count': return AppColors.chartBlue;
      case 'Returned': return AppColors.success;
      default: return theme.colorScheme.onSurfaceVariant;
    }
  }

  IconData _reasonIcon(String reason) {
    switch (reason) {
      case 'Damaged': return Icons.warning_amber_rounded;
      case 'Lost': return Icons.search_off_rounded;
      case 'Expired': return Icons.event_busy_rounded;
      case 'Stolen': return Icons.security_rounded;
      case 'Physical Count': return Icons.numbers_rounded;
      case 'Returned': return Icons.replay_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = (adj['difference'] as num?)?.toInt() ?? 0;
    final reason = adj['reason'] as String? ?? 'Other';
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
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_reasonIcon(reason), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(adj['productName'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              _Chip(label: reason, color: color),
              const SizedBox(width: 6),
              Text(adj['adjustedByName'] as String? ?? '',
                style: theme.textTheme.bodySmall),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(diff >= 0 ? '+$diff' : '$diff',
              style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16,
                color: diff >= 0 ? AppColors.success : AppColors.error,
              )),
            const SizedBox(height: 4),
            Text('${adj['previousQty']} → ${adj['newQty']}',
              style: theme.textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
  );
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

// ---------------------------------------------------------------
// AdjustStockDialog — full-screen dialog to pick product + adjust
// ---------------------------------------------------------------
class AdjustStockDialog extends StatefulWidget {
  const AdjustStockDialog({super.key});
  @override
  State<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<AdjustStockDialog> {
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _newQtyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  List<Product> _filtered = [];
  Product? _selected;
  bool _loading = true;
  bool _submitting = false;
  String _reason = 'Damaged';

  static const _reasons = ['Damaged', 'Lost', 'Expired', 'Stolen', 'Physical Count', 'Returned', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = _products.where((p) =>
          p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)
        ).toList();
      });
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    _newQtyCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getProducts', {'businessId': bizId, 'limit': 200});
      final raw = (data['products'] as List?) ?? [];
      final prods = raw.map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map))).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (mounted) setState(() { _products = prods; _filtered = prods; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    final newQty = int.tryParse(_newQtyCtrl.text);
    if (newQty == null || newQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid non-negative quantity')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('adjustInventoryStock', {
        'businessId': bizId,
        'productId': _selected!.id,
        'newQty': newQty,
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
        constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Adjust Stock',
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
                      Text('Product', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search product...',
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ))
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = _filtered[i];
                              final selected = _selected?.id == p.id;
                              return ListTile(
                                dense: true,
                                selected: selected,
                                selectedTileColor: AppColors.accent.withValues(alpha: 0.1),
                                title: Text(p.name, style: const TextStyle(fontSize: 13)),
                                subtitle: Text('Qty: ${p.quantity} · KES ${p.sellingPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11)),
                                trailing: Text('${p.quantity}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: p.isLowStock ? AppColors.warning : null,
                                  )),
                                onTap: () {
                                  setState(() => _selected = p);
                                  _newQtyCtrl.text = p.quantity.toString();
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),

                      if (_selected != null) ...[
                        Text('Current: ${_selected!.quantity} · New Quantity',
                          style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter new quantity',
                            prefixText: '${_selected!.quantity} → ',
                          ),
                        ),
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

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected != null && !_submitting ? _submit : null,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Process Adjustment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
