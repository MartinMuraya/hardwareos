import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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

      final data = await FunctionsService.call('getDashboardStats', {'businessId': businessId});
      if (mounted) {
        setState(() { _stats = data; _loading = false; });
        // Update BusinessProvider with plan data
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
    final kpis       = _stats?['kpis']        as Map?;
    final lowStock   = (_stats?['lowStock']    as List?)?.cast<Map<String, dynamic>>() ?? [];
    final recentSales= (_stats?['recentSales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sub        = _stats?['subscription'] as Map?;
    final fmt        = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading dashboard...',
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Dashboard',
                      style: AppTheme.darkTheme.textTheme.displayMedium),
                    const SizedBox(height: 4),
                    Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
              ]),
              const SizedBox(height: 20),

              // Plan banner
              if (sub != null) PlanStatusBanner(subscription: sub),
              if (sub != null) const SizedBox(height: 20),

              // Error
              if (_error != null && !_loading)
                _ErrorCard(message: _error!, onRetry: _load),

              // KPI grid
              if (kpis != null) ...[
                _SectionHeader(title: "Today's Performance"),
                const SizedBox(height: 12),
                _KpiGrid(kpis: kpis, fmt: fmt),
                const SizedBox(height: 28),
              ],

              // Quick actions
              _SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              _QuickActions(),
              const SizedBox(height: 28),

              // Low stock
              if (lowStock.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _SectionHeader(title: '⚠️ Low Stock Alert'),
                  TextButton(
                    onPressed: () => context.go('/inventory'),
                    child: const Text('View All'),
                  ),
                ]),
                const SizedBox(height: 12),
                LowStockList(items: lowStock),
                const SizedBox(height: 28),
              ],

              // Recent sales
              if (recentSales.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _SectionHeader(title: 'Recent Sales'),
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
    final cols = width > 900 ? 4 : (width > 600 ? 2 : 2);

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
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
    return Row(children: [
      Expanded(
        child: _ActionButton(
          icon: Icons.point_of_sale_rounded,
          label: 'New Sale',
          color: AppColors.accent,
          onTap: () => context.go('/sales'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ActionButton(
          icon: Icons.add_box_rounded,
          label: 'Add Product',
          color: AppColors.chartBlue,
          onTap: () => context.go('/inventory/add'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ActionButton(
          icon: Icons.receipt_long_rounded,
          label: 'Add Expense',
          color: AppColors.chartRed,
          onTap: () => context.go('/expenses/add'),
        ),
      ),
    ]);
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
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
    style: AppTheme.darkTheme.textTheme.titleLarge,
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
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
      Expanded(child: Text(message, style: const TextStyle(color: AppColors.error))),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
