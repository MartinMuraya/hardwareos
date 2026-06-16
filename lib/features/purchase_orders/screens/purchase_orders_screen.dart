import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/po_status_badge.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});
  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  List<PurchaseOrder> _orders = [];
  List<PurchaseOrder> _filtered = [];
  bool _loading = true;
  String? _error;
  String _tabFilter = 'all';
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  static const _tabs = ['all', 'draft', 'sent', 'received', 'cancelled'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getPurchaseOrders', {'businessId': bizId, 'limit': 100});
      final rawList = (data['purchaseOrders'] as List?) ?? [];
      final items = rawList.map((e) => PurchaseOrder.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _orders = items; _filtered = items; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _applyFilter(String tab) {
    setState(() {
      _tabFilter = tab;
      if (tab == 'all') {
        _filtered = _orders;
      } else {
        _filtered = _orders.where((o) => o.status == tab).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/purchase-orders/add');
          if (result == true) _load();
        },
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New PO', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Purchase Orders', style: theme.textTheme.displayMedium),
                const SizedBox(height: 4),
                Text('Order stock from suppliers',
                  style: theme.textTheme.bodyMedium),
              ])),
              TextButton(
                onPressed: () => context.go('/suppliers'),
                child: const Text('Suppliers'),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final tab = _tabs[i];
                  final sel = _tabFilter == tab;
                  return FilterChip(
                    label: Text(tab == 'all' ? 'All' : tab[0].toUpperCase() + tab.substring(1),
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => _applyFilter(tab),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.cardColor,
                    selectedColor: AppColors.accent.withValues(alpha: 0.12),
                    side: BorderSide(color: sel ? AppColors.accent : theme.dividerColor),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _tabFilter == 'all' ? 'No purchase orders yet' : 'No $_tabFilter orders',
                          subtitle: _tabFilter == 'all'
                              ? 'Create your first purchase order.'
                              : 'No orders match this status.',
                          actionLabel: 'New Purchase Order',
                          onAction: () async {
                            final result = await context.push('/purchase-orders/add');
                            if (result == true) _load();
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final po = _filtered[i];
                              return Card(
                                color: theme.cardColor,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => context.push('/purchase-orders/${po.id}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.receipt_rounded, color: AppColors.accent, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(po.poNumber,
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: theme.colorScheme.onSurface)),
                                        const SizedBox(height: 3),
                                        Text(po.supplierName,
                                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ])),
                                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                        Text(_fmt.format(po.total),
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.onSurface)),
                                        const SizedBox(height: 4),
                                        POStatusBadge(status: po.status),
                                      ]),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
