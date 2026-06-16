import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../widgets/po_status_badge.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String purchaseOrderId;
  const PurchaseOrderDetailScreen({required this.purchaseOrderId, super.key});
  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  PurchaseOrder? _po;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getPurchaseOrder', {
        'businessId': bizId, 'purchaseOrderId': widget.purchaseOrderId,
      });
      final po = PurchaseOrder.fromMap(Map<String, dynamic>.from(data['purchaseOrder'] as Map));
      if (mounted) setState(() { _po = po; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() { _actionLoading = true; _error = null; });
    try {
      final authProvider = context.read<AuthProvider>();
      final bizId = authProvider.businessId!;
      await FunctionsService.call('updatePurchaseOrderStatus', {
        'businessId': bizId, 'purchaseOrderId': widget.purchaseOrderId, 'status': status,
      });
      if (mounted) _load();
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _actionLoading = false; });
    }
  }

  Future<void> _receive() async {
    final authProvider = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: const Text('Receive Order'),
        content: const Text('This will add all items to inventory and update stock levels. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Receive')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() { _actionLoading = true; _error = null; });
    try {
      final bizId = authProvider.businessId!;
      await FunctionsService.call('receivePurchaseOrder', {
        'businessId': bizId, 'purchaseOrderId': widget.purchaseOrderId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase order received. Stock updated.')),
        );
        _load();
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _actionLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _loading || _actionLoading,
      message: _actionLoading ? 'Processing...' : 'Loading...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_po?.poNumber ?? 'Purchase Order'),
          actions: [
            if (_po != null && _po!.status == 'draft')
              PopupMenuButton<String>(
                onSelected: _updateStatus,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'sent', child: Text('Mark as Sent')),
                  const PopupMenuItem(value: 'cancelled', child: Text('Cancel Order')),
                ],
              ),
          ],
        ),
        body: _po == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.padding(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),

                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_po!.poNumber,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(_po!.supplierName,
                            style: theme.textTheme.bodyMedium),
                        ])),
                        POStatusBadge(status: _po!.status),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(children: [
                        _InfoChip(label: 'Created', value: _dateFmt.format(_po!.createdAt), theme: theme),
                        if (_po!.receivedAt != null) ...[
                          Container(width: 1, height: 30, color: theme.dividerColor),
                          _InfoChip(label: 'Received', value: _dateFmt.format(_po!.receivedAt!), theme: theme),
                        ],
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Items
                  Text('Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(children: [
                      ..._po!.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(item.name,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                          SizedBox(width: 60, child: Text('x${item.quantity}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
                          SizedBox(width: 80, child: Text(_fmt.format(item.unitCost),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
                          SizedBox(width: 80, child: Text(_fmt.format(item.total),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        ]),
                      )),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Total', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                          Text(_fmt.format(_po!.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.accent)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Notes
                  if (_po!.notes.isNotEmpty) ...[
                    Text('Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(_po!.notes,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Receive button
                  if (_po!.isReceivable)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _receive,
                        icon: const Icon(Icons.inventory_2_rounded, size: 18),
                        label: const Text('Receive Order — Add to Stock'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                ]),
              ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  final ThemeData theme;
  const _InfoChip({required this.label, required this.value, required this.theme});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: theme.colorScheme.onSurface)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
  ]));
}
