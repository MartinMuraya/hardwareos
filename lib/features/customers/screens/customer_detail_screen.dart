import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/debt_transaction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../widgets/debt_tx_tile.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({required this.customerId, super.key});
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  List<DebtTransaction> _transactions = [];
  bool _loading = true;
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;

      final [custData, txData] = await Future.wait([
        FunctionsService.call('getCustomer', {
          'businessId': bizId, 'customerId': widget.customerId,
        }),
        FunctionsService.call('getDebtTransactions', {
          'businessId': bizId, 'customerId': widget.customerId, 'limit': 100,
        }),
      ]);

      final customer = Customer.fromMap(Map<String, dynamic>.from(custData['customer'] as Map));
      final rawTxs = (txData['transactions'] as List?) ?? [];
      final txs = rawTxs
          .map((e) => DebtTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted) {
        setState(() { _customer = customer; _transactions = txs; _loading = false; });
      }
    } on FunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _recordPayment() async {
    final authProvider = context.read<AuthProvider>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: const Text('Record Payment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amountCtrl,
            decoration: const InputDecoration(labelText: 'Amount (KES)', prefixText: 'KES '),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. M-Pesa payment'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record Payment')),
        ],
      ),
    );

    if (result != true) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount.')),
        );
      }
      return;
    }

    try {
      final bizId = authProvider.businessId!;
      await FunctionsService.call('recordDebtPayment', {
        'businessId': bizId,
        'customerId': widget.customerId,
        'amount': amount,
        'note': noteCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully.')),
        );
        _load();
      }
    } on FunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
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
          title: Text(_customer?.fullName ?? 'Customer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.payment_rounded),
              tooltip: 'Record Payment',
              onPressed: _recordPayment,
            ),
            IconButton(
              icon: const Icon(Icons.description_rounded),
              tooltip: 'View Statement',
              onPressed: () => context.push('/customers/${widget.customerId}/statement'),
            ),
          ],
        ),
        body: _customer == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.padding(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Customer info card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: (_customer!.currentBalance > 0
                                ? AppColors.warning : theme.colorScheme.surfaceContainerHighest).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.person_rounded,
                            color: _customer!.currentBalance > 0 ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
                            size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_customer!.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(_customer!.phoneNumber, style: theme.textTheme.bodyMedium),
                          if (_customer!.nationalId.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('ID: ${_customer!.nationalId}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ])),
                      ]),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      // KPI Row
                      Row(children: [
                        _KpiTile(label: 'Balance', value: _fmt.format(_customer!.currentBalance),
                          color: _customer!.currentBalance > 0 ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
                          theme: theme),
                        Container(width: 1, height: 40, color: theme.dividerColor),
                        _KpiTile(label: 'Credit Limit', value: _fmt.format(_customer!.creditLimit),
                          color: _customer!.creditLimit > 0 ? AppColors.info : theme.colorScheme.onSurfaceVariant,
                          theme: theme),
                        Container(width: 1, height: 40, color: theme.dividerColor),
                        _KpiTile(label: 'Available', value: _customer!.creditLimit > 0
                            ? _fmt.format(_customer!.availableCredit)
                            : 'Unlimited',
                          color: _customer!.availableCredit > 0 || _customer!.creditLimit == 0
                              ? AppColors.success : AppColors.error,
                          theme: theme),
                      ]),
                      if (_customer!.isOverLimit) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Text('Over credit limit by ${_fmt.format(_customer!.currentBalance - _customer!.creditLimit)}',
                              style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // Transactions header
                  Row(children: [
                    Text('Transaction History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.push('/customers/${widget.customerId}/statement'),
                      icon: const Icon(Icons.description_rounded, size: 16),
                      label: const Text('Statement'),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('No transactions yet', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
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

class _KpiTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final ThemeData theme;
  const _KpiTile({required this.label, required this.value, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
  ]));
}
