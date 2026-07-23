import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../services/offline_sales_queue.dart';

import '../../../core/services/offline_service.dart';

class OfflineQueueScreen extends StatefulWidget {
  const OfflineQueueScreen({super.key});

  @override
  State<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends State<OfflineQueueScreen> {
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      final queue = context.read<OfflineSalesQueue>();
      await queue.syncAll(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _discardSale(PendingSale sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Sale?'),
        content: const Text('Are you sure you want to permanently delete this offline sale? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final queue = context.read<OfflineSalesQueue>();
      await queue.removeSale(sale.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Sales Queue'),
        actions: [
          if (_isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Force Sync',
              onPressed: _syncNow,
            ),
        ],
      ),
      body: Consumer<OfflineSalesQueue>(
        builder: (context, queue, child) {
          final sales = queue.pendingSalesList;

          if (sales.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done_outlined, size: 64, color: AppColors.success),
                  SizedBox(height: 16),
                  Text('All caught up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('No offline sales pending synchronization.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sales.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final sale = sales[index];
              final items = sale.saleData['items'] as List<dynamic>? ?? [];
              final total = sale.saleData['total'] ?? 0.0;
              final date = sale.createdAt;

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.warning,
                  child: Icon(Icons.wifi_off, color: Colors.white, size: 20),
                ),
                title: Text('${items.length} Items - ${_fmt.format(total)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('MMM dd, yyyy - HH:mm').format(date)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _discardSale(sale),
                  tooltip: 'Discard',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
