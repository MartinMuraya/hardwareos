import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/audit_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});
  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<AuditLog> _logs = [];
  bool _loading = true;
  String? _error;
  String? _filterModule;
  String? _filterAction;
  List<String> _modules = [];
  final _searchCtrl = TextEditingController();

  static const _actions = [
    'Create Product', 'Update Product', 'Delete Product', 'Stock Adjustment',
    'Create Sale', 'Cancel Sale',
    'Create Debt', 'Receive Payment', 'Debt Write-Off',
    'Create Quote', 'Edit Quote', 'Delete Quote', 'Convert Quote To Sale',
    'Create Supplier', 'Create PO', 'Receive PO',
    'Process Return',
  ];

  @override
  void initState() {
    super.initState();
    _loadModules();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getAuditModules', {'businessId': bizId});
      final raw = (data['modules'] as List?) ?? [];
      if (mounted) setState(() => _modules = raw.cast<String>());
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final params = <String, dynamic>{'businessId': bizId, 'limit': 100};
      if (_filterModule != null) params['module'] = _filterModule;
      if (_filterAction != null) params['action'] = _filterAction;

      final data = await FunctionsService.call('getAuditLogs', params);
      final raw = (data['logs'] as List?) ?? [];
      final logs = raw.map((e) => AuditLog.fromMap(Map<String, dynamic>.from(e as Map))).toList();

      // Client-side search filter
      final q = _searchCtrl.text.toLowerCase();
      final filtered = q.isEmpty ? logs : logs.where((l) =>
        l.entityName.toLowerCase().contains(q) ||
        l.userName.toLowerCase().contains(q) ||
        l.module.toLowerCase().contains(q)
      ).toList();

      if (mounted) setState(() { _logs = filtered; _loading = false; });
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
      message: 'Loading audit trail...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audit Trail', style: theme.textTheme.displayMedium),
              const SizedBox(height: 4),
              Text('${_logs.length} events', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search by entity, user, or module...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    onChanged: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterDropdown(
                  value: _filterModule,
                  items: _modules,
                  hint: 'Module',
                  onChanged: (v) { setState(() => _filterModule = v); _load(); },
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _FilterDropdown(
                  value: _filterAction,
                  items: _actions,
                  hint: 'Action',
                  onChanged: (v) { setState(() => _filterAction = v); _load(); },
                  theme: theme,
                ),
              ]),
              const SizedBox(height: 16),

              if (_error != null)
                _ErrorBar(message: _error!, onRetry: _load, theme: theme),

              Expanded(
                child: _logs.isEmpty && !_loading
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No audit logs yet',
                        subtitle: 'Actions performed in the system will appear here.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) => _AuditCard(log: _logs[i], theme: theme),
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

class _FilterDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> onChanged;
  final ThemeData theme;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          dropdownColor: theme.cardColor,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12),
          items: [
            DropdownMenuItem(value: null, child: Text('All $hint', style: const TextStyle(fontSize: 12))),
            ...items.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditLog log;
  final ThemeData theme;
  const _AuditCard({required this.log, required this.theme});

  IconData _moduleIcon(String module) {
    switch (module) {
      case 'Inventory': return Icons.inventory_2_rounded;
      case 'Sales': return Icons.point_of_sale_rounded;
      case 'Credit': return Icons.account_balance_wallet_rounded;
      case 'Quotation': return Icons.description_rounded;
      case 'Suppliers': return Icons.store_rounded;
      default: return Icons.history_rounded;
    }
  }

  Color _actionColor(String action) {
    if (action.contains('Create') || action.contains('Receive') || action.contains('Payment')) return AppColors.success;
    if (action.contains('Delete') || action.contains('Cancel') || action.contains('Write-Off')) return AppColors.error;
    if (action.contains('Update') || action.contains('Edit') || action.contains('Adjust')) return AppColors.warning;
    return AppColors.chartBlue;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm');
    final color = _actionColor(log.action);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_moduleIcon(log.module), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Badge(label: log.module, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(log.action,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 3),
            Text(log.entityName,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Text(log.userName, style: TextStyle(fontSize: 11, color: theme.hintColor)),
              const SizedBox(width: 8),
              Text(fmt.format(log.createdAt), style: TextStyle(fontSize: 11, color: theme.hintColor)),
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
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
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
