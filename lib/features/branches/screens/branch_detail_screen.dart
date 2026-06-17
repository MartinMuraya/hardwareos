import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/branch.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';

class BranchDetailScreen extends StatefulWidget {
  final String branchId;
  const BranchDetailScreen({required this.branchId, super.key});
  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  Branch? _branch;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pendingTransfers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final brData = await FunctionsService.call('getBranches', {'businessId': bizId});
      final branches = (brData['branches'] as List?) ?? [];
      final found = branches.firstWhere(
        (b) => (b as Map)['id'] == widget.branchId,
        orElse: () => null,
      );
      if (found != null) {
        _branch = Branch.fromMap(Map<String, dynamic>.from(found as Map));
      }

      // Load pending transfers to this branch
      try {
        final tData = await FunctionsService.call('getStockTransfers', {
          'businessId': bizId,
          'status': 'pending',
          'limit': 10,
        });
        final raw = (tData['transfers'] as List?) ?? [];
        _pendingTransfers = raw
          .cast<Map<String, dynamic>>()
          .where((t) => t['toBranchId'] == widget.branchId)
          .toList();
      } catch (_) {}

      if (mounted) setState(() { _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    return Scaffold(
      appBar: AppBar(title: Text(_branch?.name ?? 'Branch')),
      body: LoadingOverlay(
        isLoading: _loading,
        child: _error != null
            ? Center(child: Text(_error!))
            : _branch == null
                ? const Center(child: Text('Branch not found'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: EdgeInsets.all(padding),
                      children: [
                        _InfoCard(branch: _branch!, theme: theme),
                        const SizedBox(height: 20),
                        if (_pendingTransfers.isNotEmpty) ...[
                          Text('Pending Transfers', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          ...(_pendingTransfers.take(5).map((t) => ListTile(
                            title: Text('${t['productName'] ?? t['productId']} × ${t['quantity']}'),
                            subtitle: Text('From: ${t['fromBranchId'] ?? ''}'),
                            trailing: TextButton(
                              onPressed: () => _approveTransfer(t['id'] as String),
                              child: const Text('Approve'),
                            ),
                          ))),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Future<void> _approveTransfer(String transferId) async {
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('approveStockTransfer', {
        'businessId': bizId,
        'transferId': transferId,
      });
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer approved')),
      );
    } on FunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }
}

class _InfoCard extends StatelessWidget {
  final Branch branch;
  final ThemeData theme;
  const _InfoCard({required this.branch, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _InfoChip(label: branch.active ? 'Active' : 'Inactive',
            color: branch.active ? AppColors.success : AppColors.error),
        ]),
        const SizedBox(height: 12),
        if (branch.address.isNotEmpty) ...[
          _Row(icon: Icons.location_on_rounded, text: branch.address, theme: theme),
          const SizedBox(height: 8),
        ],
        if (branch.phone.isNotEmpty) ...[
          _Row(icon: Icons.phone_rounded, text: branch.phone, theme: theme),
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;
  const _Row({required this.icon, required this.text, required this.theme});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
    const SizedBox(width: 8),
    Text(text, style: theme.textTheme.bodyMedium),
  ]);
}

class _InfoChip extends StatelessWidget {
  final String label; final Color color;
  const _InfoChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}
