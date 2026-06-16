import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/debt_transaction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../widgets/debt_tx_tile.dart';

class CustomerStatementScreen extends StatefulWidget {
  final String customerId;
  const CustomerStatementScreen({required this.customerId, super.key});
  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  Customer? _customer;
  List<DebtTransaction> _transactions = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getCustomerStatement', {
        'businessId': bizId, 'customerId': widget.customerId,
      });

      final customer = Customer.fromMap(Map<String, dynamic>.from(data['customer'] as Map));
      final rawTxs = (data['transactions'] as List?) ?? [];
      final txs = rawTxs
          .map((e) => DebtTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted) {
        setState(() {
          _customer = customer;
          _transactions = txs;
          _summary = Map<String, dynamic>.from(data['summary'] as Map);
          _loading = false;
        });
      }
    } on FunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() { _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_customer?.fullName ?? 'Statement'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Print Statement',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Print functionality coming soon.')),
                );
              },
            ),
          ],
        ),
        body: _customer == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.padding(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Header / Business info
                  Center(child: Column(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.store_rounded, color: AppColors.accent, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Text('HARDWARE STORE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text('Customer Statement',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Generated ${DateFormat.yMMMd().format(DateTime.now())}',
                      style: TextStyle(color: theme.hintColor, fontSize: 11)),
                  ])),
                  const SizedBox(height: 20),

                  // Customer info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_customer!.fullName,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: theme.colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Text('Phone: ${_customer!.phoneNumber}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                        if (_customer!.nationalId.isNotEmpty)
                          Text('ID: ${_customer!.nationalId}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Summary row
                  if (_summary != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(children: [
                        _StatItem(label: 'Total Debt', value: _fmt.format(_summary!['totalDebt'] ?? 0),
                          color: AppColors.warning, theme: theme),
                        Container(width: 1, height: 36, color: theme.dividerColor),
                        _StatItem(label: 'Total Paid', value: _fmt.format(_summary!['totalPaid'] ?? 0),
                          color: AppColors.success, theme: theme),
                        Container(width: 1, height: 36, color: theme.dividerColor),
                        _StatItem(label: 'Balance', value: _fmt.format(_summary!['currentBalance'] ?? 0),
                          color: (_summary!['currentBalance'] as num? ?? 0) > 0 ? AppColors.warning : AppColors.success,
                          theme: theme),
                      ]),
                    ),
                  const SizedBox(height: 20),

                  Text('Transactions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('No transactions found', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    )
                  else
                    ..._transactions.map((tx) => DebtTxTile(transaction: tx, fmt: _fmt, theme: theme)),
                ]),
              ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color color;
  final ThemeData theme;
  const _StatItem({required this.label, required this.value, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
  ]));
}
