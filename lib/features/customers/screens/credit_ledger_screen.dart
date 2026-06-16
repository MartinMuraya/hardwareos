import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/customer_card.dart';

class CreditLedgerScreen extends StatefulWidget {
  const CreditLedgerScreen({super.key});
  @override
  State<CreditLedgerScreen> createState() => _CreditLedgerScreenState();
}

class _CreditLedgerScreenState extends State<CreditLedgerScreen> {
  List<Customer> _debtors = [];
  bool _loading = true;
  String? _error;
  double _totalOutstanding = 0;
  int _overdueCount = 0;
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getDebtDashboard', {'businessId': bizId});

      final rawList = (data['topDebtors'] as List?) ?? [];
      final debtors = rawList
          .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted) {
        setState(() {
          _debtors = debtors;
          _totalOutstanding = ((data['totalOutstanding'] as num?) ?? 0).toDouble();
          _overdueCount = (data['overdueCount'] as int?) ?? 0;
          _loading = false;
        });
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Credit Ledger', style: theme.textTheme.displayMedium),
                const SizedBox(height: 4),
                Text('Track customer debt and payments',
                  style: theme.textTheme.bodyMedium),
              ])),
            ]),
            const SizedBox(height: 16),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.error))))
            else ...[
              // Summary cards
              Row(children: [
                _SummaryCard(
                  label: 'Total Outstanding',
                  value: _fmt.format(_totalOutstanding),
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.warning,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _SummaryCard(
                  label: 'Active Debtors',
                  value: '${_debtors.length}',
                  icon: Icons.people_rounded,
                  color: AppColors.info,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _SummaryCard(
                  label: 'Overdue',
                  value: '$_overdueCount',
                  icon: Icons.warning_rounded,
                  color: _overdueCount > 0 ? AppColors.error : AppColors.success,
                  theme: theme,
                ),
              ]),
              const SizedBox(height: 20),

              Text('Top Debtors', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              Expanded(
                child: _debtors.isEmpty
                    ? const EmptyState(
                        icon: Icons.check_circle_rounded,
                        title: 'No outstanding debt',
                        subtitle: 'All customer balances are cleared.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _debtors.length,
                          itemBuilder: (_, i) => CustomerCard(
                            customer: _debtors[i],
                            onTap: () => context.push('/customers/${_debtors[i].id}'),
                          ),
                        ),
                      ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      ]),
    ),
  );
}
