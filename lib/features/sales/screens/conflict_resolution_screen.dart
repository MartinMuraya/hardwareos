import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../services/offline_sales_queue.dart';

class ConflictResolutionScreen extends StatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  bool _isProcessing = false;

  Future<void> _handleCancel(ConflictedSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Conflicted Sale'),
        content: const Text(
            'Are you sure you want to cancel and remove this offline sale? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Sale'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await context.read<OfflineSalesQueue>().removeConflictedSale(sale.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conflicted sale removed.')),
        );
      }
    }
  }

  Future<void> _handleAdjustAndRetry(ConflictedSale sale) async {
    final details = sale.conflictDetails;
    final String? productId = details?['productId'];
    final double available =
        (details?['availableQty'] as num?)?.toDouble() ?? 0.0;

    final updatedData = Map<String, dynamic>.from(sale.saleData);
    final items = (updatedData['items'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    if (productId != null) {
      for (final item in items) {
        if (item['productId'] == productId) {
          item['quantity'] = available > 0 ? available : 1;
        }
      }
    }

    updatedData['items'] = items;

    final queue = context.read<OfflineSalesQueue>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isProcessing = true);
    try {
      await FunctionsService.call('createSale', updatedData);
      await queue.removeConflictedSale(sale.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Sale updated and posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to post sale: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleManagerOverride(ConflictedSale sale) async {
    final isManager =
        ['owner', 'manager'].contains(context.read<AuthProvider>().userRole);
    if (!isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Manager or Owner permission required to override stock.')),
      );
      return;
    }

    final updatedData = Map<String, dynamic>.from(sale.saleData);
    updatedData['allowOverride'] = true;

    final queue = context.read<OfflineSalesQueue>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isProcessing = true);
    try {
      await FunctionsService.call('createSale', updatedData);
      await queue.removeConflictedSale(sale.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content:
                  Text('Stock override approved! Sale posted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Override failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = context.watch<OfflineSalesQueue>();
    final conflictedSales = queue.conflictedSalesList;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Sync Conflicts Review',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => queue.refresh(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : conflictedSales.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No Conflicts Found',
                  subtitle:
                      'All offline sales synced cleanly without stock conflicts.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: conflictedSales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final sale = conflictedSales[i];
                    final items = (sale.saleData['items'] as List?) ?? [];
                    final details = sale.conflictDetails;
                    final available =
                        (details?['availableQty'] as num?)?.toDouble();

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: AppColors.error, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Conflicted Sale #${sale.id.substring(0, 8)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurface),
                                    ),
                                    Text(
                                      'Logged ${sale.conflictedAt.toLocal().toString().split('.')[0]}',
                                      style: TextStyle(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              sale.conflictReason,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Items in Sale (${items.length}):',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 4),
                          ...items.map((it) {
                            final itemMap =
                                Map<String, dynamic>.from(it as Map);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '• ${itemMap['name'] ?? itemMap['productId']}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: theme
                                              .colorScheme.onSurfaceVariant)),
                                  Text('Qty: ${itemMap['quantity']}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface)),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 24),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error),
                                onPressed: () => _handleCancel(sale),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Cancel Sale'),
                              ),
                              if (available != null && available > 0)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.info),
                                  onPressed: () => _handleAdjustAndRetry(sale),
                                  icon:
                                      const Icon(Icons.tune_rounded, size: 18),
                                  label: Text('Adjust Qty to $available'),
                                ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.warning),
                                onPressed: () => _handleManagerOverride(sale),
                                icon: const Icon(Icons.bolt_rounded, size: 18),
                                label: const Text('Manager Override'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
