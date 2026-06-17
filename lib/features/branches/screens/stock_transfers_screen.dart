import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/branch.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class StockTransfersScreen extends StatefulWidget {
  const StockTransfersScreen({super.key});
  @override
  State<StockTransfersScreen> createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen> {
  List<StockTransfer> _transfers = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final params = <String, dynamic>{'businessId': bizId, 'limit': 100};
      if (_filterStatus != 'all') params['status'] = _filterStatus;

      final data = await FunctionsService.call('getStockTransfers', params);
      final raw = (data['transfers'] as List?) ?? [];
      final transfers = raw.map((e) => StockTransfer.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _transfers = transfers; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading transfers...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stock Transfers', style: theme.textTheme.displayMedium),
              const SizedBox(height: 4),
              Text('${_transfers.length} transfers', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),

              Row(children: [
                _FilterChip(label: 'All', selected: _filterStatus == 'all', onTap: () { setState(() => _filterStatus = 'all'); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Pending', selected: _filterStatus == 'pending', onTap: () { setState(() => _filterStatus = 'pending'); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Completed', selected: _filterStatus == 'completed', onTap: () { setState(() => _filterStatus = 'completed'); _load(); }),
              ]),
              const SizedBox(height: 16),

              if (_error != null)
                _ErrorBar(message: _error!, onRetry: _load, theme: theme),

              Expanded(
                child: _transfers.isEmpty && !_loading
                    ? const EmptyState(
                        icon: Icons.swap_horiz_rounded,
                        title: 'No transfers',
                        subtitle: 'Request stock transfers between branches.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.separated(
                          itemCount: _transfers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _TransferCard(
                            transfer: _transfers[i],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : theme.dividerColor),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : theme.colorScheme.onSurface,
          fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final StockTransfer transfer;
  final ThemeData theme;
  const _TransferCard({required this.transfer, required this.theme});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return theme.colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              color: _statusColor(transfer.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.swap_horiz_rounded,
              color: _statusColor(transfer.status), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${transfer.quantity}x ${transfer.productName.isNotEmpty ? transfer.productName : transfer.productId}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Row(children: [
              _Badge(label: transfer.status.toUpperCase(), color: _statusColor(transfer.status)),
              const SizedBox(width: 8),
              Text(transfer.requestedByName,
                style: theme.textTheme.bodySmall),
            ]),
          ])),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
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
