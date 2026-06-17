import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../sales/services/offline_sales_queue.dart';

class PendingSyncCard extends StatelessWidget {
  const PendingSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<OfflineSalesQueue>();
    if (queue.totalPending == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.sync_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Text('Pending Sync',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
          const Spacer(),
          if (queue.isSyncing)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
            )
          else
            TextButton(
              onPressed: () => queue.syncAll(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Sync Now', style: TextStyle(fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 16, children: [
          if (queue.pendingSales > 0)
            _SyncCount(label: 'Sales', count: queue.pendingSales, icon: Icons.point_of_sale_rounded),
          if (queue.pendingPayments > 0)
            _SyncCount(label: 'Payments', count: queue.pendingPayments, icon: Icons.payments_rounded),
          if (queue.pendingInventory > 0)
            _SyncCount(label: 'Inventory', count: queue.pendingInventory, icon: Icons.inventory_2_rounded),
        ]),
        if (queue.lastError != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(queue.lastError!, style: const TextStyle(color: AppColors.error, fontSize: 11)),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _SyncCount extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;

  const _SyncCount({required this.label, required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 4),
      Text('$label: $count',
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}
