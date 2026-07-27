import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/supplier_debt.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';

class SupplierDebtScreen extends StatefulWidget {
  const SupplierDebtScreen({super.key});

  @override
  State<SupplierDebtScreen> createState() => _SupplierDebtScreenState();
}

class _SupplierDebtScreenState extends State<SupplierDebtScreen> {
  bool _loading = true;
  String? _error;
  List<SupplierDebt> _debts = [];
  double _totalPayables = 0.0;
  double _overdueTotal = 0.0;
  int _overdueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bizId = context.read<AuthProvider>().businessId;
      if (bizId == null) return;

      final resDebts = await FunctionsService.call('getSupplierDebts', {'businessId': bizId});
      final resDash = await FunctionsService.call('getSupplierDebtDashboard', {'businessId': bizId});

      final list = (resDebts['debts'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _debts = list.map((e) => SupplierDebt.fromMap(Map<String, dynamic>.from(e as Map))).toList();
          _totalPayables = (resDash['totalPayables'] ?? 0.0).toDouble();
          _overdueTotal = (resDash['overdueTotal'] ?? 0.0).toDouble();
          _overdueCount = (resDash['overdueCount'] ?? 0).toInt();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _showPaymentDialog(SupplierDebt debt) async {
    final theme = Theme.of(context);
    final bizId = context.read<AuthProvider>().businessId!;
    final messenger = ScaffoldMessenger.of(context);
    final amountCtrl = TextEditingController(text: debt.outstanding.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String paymentMethod = 'mpesa';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text('Pay Supplier: ${debt.supplierName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Outstanding: KES ${debt.outstanding.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (KES)',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment Method'),
                      dropdownColor: theme.cardColor,
                      items: const [
                        DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => paymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reference Code (e.g. M-Pesa Code / Cheque No.)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm Payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final pmtAmount = double.tryParse(amountCtrl.text);
      if (pmtAmount == null || pmtAmount <= 0) return;
      try {
        await FunctionsService.call('recordSupplierPayment', {
          'businessId': bizId,
          'supplierDebtId': debt.id,
          'amount': pmtAmount,
          'paymentMethod': paymentMethod,
          'referenceCode': refCtrl.text.trim(),
          'note': noteCtrl.text.trim(),
        });
        if (mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Payment recorded successfully!')));
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text('Payment failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Supplier Debt & Payables', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dashboard Cards
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Total Payables',
                              value: 'KES ${_totalPayables.toStringAsFixed(0)}',
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'Overdue Payables',
                              value: 'KES ${_overdueTotal.toStringAsFixed(0)}',
                              subtitle: '$_overdueCount Overdue Invoices',
                              icon: Icons.warning_amber_rounded,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text('Outstanding Supplier Debts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _debts.isEmpty
                          ? const EmptyState(
                              icon: Icons.check_circle_outline_rounded,
                              title: 'No Outstanding Payables',
                              subtitle: 'You are all clear with your suppliers!',
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _debts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, i) {
                                final debt = _debts[i];
                                final isOverdue = debt.isOverdue;

                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isOverdue
                                          ? AppColors.error.withValues(alpha: 0.4)
                                          : theme.dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isOverdue ? AppColors.error : AppColors.accent).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isOverdue ? Icons.warning_amber_rounded : Icons.receipt_long_rounded,
                                          color: isOverdue ? AppColors.error : AppColors.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(debt.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Due: ${debt.paymentDueDate != null ? debt.paymentDueDate!.toLocal().toString().split(' ')[0] : 'Not specified'}',
                                              style: TextStyle(
                                                color: isOverdue ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                                                fontSize: 13,
                                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('KES ${debt.outstanding.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error)),
                                          const SizedBox(height: 8),
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                                            onPressed: () => _showPaymentDialog(debt),
                                            icon: const Icon(Icons.payment_rounded, size: 16),
                                            label: const Text('Pay Supplier'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
