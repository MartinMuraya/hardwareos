import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../widgets/kpi_card.dart';
import '../widgets/plan_status_banner.dart';
import '../widgets/low_stock_list.dart';
import '../widgets/recent_sales_list.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _debtStats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final businessId = context.read<AuthProvider>().businessId;
      if (businessId == null) { setState(() { _loading = false; _error = 'No business found.'; }); return; }

      final results = await Future.wait([
        FunctionsService.call('getDashboardStats', {'businessId': businessId}),
        FunctionsService.call('getDebtDashboard', {'businessId': businessId}),
      ]);
      final data = results[0];
      final debt = results[1];
      if (mounted) {
        setState(() { _stats = data; _debtStats = debt; _loading = false; });
        final sub = data['subscription'] as Map?;
        if (sub != null) {
          context.read<BusinessProvider>().setBusinessData({
            'id':                 businessId,
            'plan':               sub['plan'],
            'subscriptionStatus': sub['status'],
            'trialEndsAt':        sub['trialEndsAt'],
          });
        }
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kpis       = _stats?['kpis']        as Map?;
    final lowStock   = (_stats?['lowStock']    as List?)?.cast<Map<String, dynamic>>() ?? [];
    final recentSales= (_stats?['recentSales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sub        = _stats?['subscription'] as Map?;
    final fmt        = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');
    final padding    = Responsive.padding(context);

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading dashboard...',
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: theme.cardColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Dashboard',
                      style: theme.textTheme.displayMedium),
                    const SizedBox(height: 4),
                    Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: theme.textTheme.bodyMedium),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
              ]),
              const SizedBox(height: 20),

              if (sub != null) PlanStatusBanner(subscription: sub),
              if (sub != null) const SizedBox(height: 20),

              if (_error != null && !_loading)
                _ErrorCard(message: _error!, onRetry: _load, theme: theme),

              if (kpis != null) ...[
                _SectionHeader(title: "Today's Performance", theme: theme),
                const SizedBox(height: 12),
                _KpiGrid(kpis: kpis, fmt: fmt),
                const SizedBox(height: 28),
              ],

              const _SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              _QuickActions(),
              const SizedBox(height: 28),

              if (lowStock.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _SectionHeader(title: 'Low Stock Alert', theme: theme),
                  TextButton(
                    onPressed: () => context.go('/inventory'),
                    child: const Text('View All'),
                  ),
                ]),
                const SizedBox(height: 12),
                LowStockList(items: lowStock),
                const SizedBox(height: 28),
              ],

              if (_debtStats != null) ...[
                _SectionHeader(title: 'Credit Overview', theme: theme),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.go('/credit-ledger'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.warning, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Outstanding Debt',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Text('${_debtStats!['overdueCount'] ?? 0} overdue customers',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt.format(_debtStats!['totalOutstanding'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.warning)),
                        const SizedBox(height: 4),
                        Text('Tap to view',
                          style: TextStyle(fontSize: 11, color: theme.hintColor)),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              if (recentSales.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _SectionHeader(title: 'Recent Sales', theme: theme),
                  TextButton(
                    onPressed: () => context.go('/sales/history'),
                    child: const Text('View All'),
                  ),
                ]),
                const SizedBox(height: 12),
                RecentSalesList(sales: recentSales, fmt: fmt),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final Map kpis;
  final NumberFormat fmt;
  const _KpiGrid({required this.kpis, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = width > 900 ? 4 : (width > 600 ? 2 : 1);

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: cols == 1 ? 2.2 : 1.6,
      children: [
        KpiCard(
          label: 'Revenue',
          value: fmt.format(kpis['todayRevenue'] ?? 0),
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.chartGreen,
          trend: null,
        ),
        KpiCard(
          label: 'Gross Profit',
          value: fmt.format(kpis['todayProfit'] ?? 0),
          icon: Icons.account_balance_wallet_rounded,
          iconColor: AppColors.accent,
          trend: null,
        ),
        KpiCard(
          label: 'Expenses',
          value: fmt.format(kpis['todayExpenses'] ?? 0),
          icon: Icons.receipt_rounded,
          iconColor: AppColors.chartRed,
          trend: null,
        ),
        KpiCard(
          label: 'Net Profit',
          value: fmt.format(kpis['netProfit'] ?? 0),
          icon: Icons.savings_rounded,
          iconColor: AppColors.chartBlue,
          isHighlighted: (kpis['netProfit'] ?? 0) > 0,
          trend: null,
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.point_of_sale_rounded,
          label: 'New Sale',
          color: AppColors.accent,
          onTap: () => context.go('/sales'),
        ),
        _ActionButton(
          icon: Icons.add_box_rounded,
          label: 'Add Product',
          color: AppColors.chartBlue,
          onTap: () => context.go('/inventory/add'),
        ),
        _ActionButton(
          icon: Icons.receipt_long_rounded,
          label: 'Add Expense',
          color: AppColors.chartRed,
          onTap: () => context.go('/expenses/add'),
        ),
      ].map((btn) => isMobile
        ? SizedBox(width: (MediaQuery.of(context).size.width - 24 - 24 - 24) / 3, child: btn)
        : SizedBox(width: 160, child: btn)
      ).toList(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData? theme;
  const _SectionHeader({required this.title, this.theme});

  @override
  Widget build(BuildContext context) => Text(title,
    style: (theme ?? Theme.of(context)).textTheme.titleLarge,
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ThemeData theme;
  const _ErrorCard({required this.message, required this.onRetry, required this.theme});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_rounded, color: AppColors.error),
      const SizedBox(width: 12),
      Expanded(child: Text(message, style: TextStyle(color: theme.colorScheme.onSurface))),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
