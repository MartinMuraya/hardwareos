import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';

enum _Period { today, week, month }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.month;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getReportStats', {
        'businessId': bizId,
        'period': _period.name,
      });
      if (mounted) setState(() { _stats = data; _loading = false; });
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
      message: 'Generating report...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: RefreshIndicator(
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
                  Expanded(child: Text('Reports',
                    style: theme.textTheme.displayMedium)),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _load,
                    tooltip: 'Refresh',
                  ),
                ]),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: _Period.values.map((p) {
                      final sel = p == _period;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_period != p) {
                              setState(() => _period = p);
                              _load();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              p == _Period.today ? 'Today'
                                  : p == _Period.week ? 'This Week' : 'This Month',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: sel ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                if (_error != null && !_loading)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                  ),

                if (_stats != null) ...[
                  _PLCard(stats: _stats!, fmt: _fmt, theme: theme),
                  const SizedBox(height: 20),
                  _SalesCard(stats: _stats!, fmt: _fmt, theme: theme),
                  const SizedBox(height: 20),
                  if ((_stats!['topProducts'] as List?)?.isNotEmpty == true) ...[
                    _TopProductsCard(stats: _stats!, fmt: _fmt, theme: theme),
                    const SizedBox(height: 20),
                  ],
                  if ((_stats!['expenseByCategory'] as Map?)?.isNotEmpty == true)
                    _ExpenseBreakdownCard(stats: _stats!, fmt: _fmt, theme: theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PLCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final NumberFormat fmt;
  final ThemeData theme;

  const _PLCard({required this.stats, required this.fmt, required this.theme});

  @override
  Widget build(BuildContext context) {
    final revenue  = (stats['totalRevenue']  as num?)?.toDouble() ?? 0;
    final cogs     = (stats['totalCOGS']     as num?)?.toDouble() ?? 0;
    final expenses = (stats['totalExpenses'] as num?)?.toDouble() ?? 0;
    final profit   = (stats['netProfit']     as num?)?.toDouble() ?? 0;
    final margin   = revenue > 0 ? (profit / revenue * 100) : 0.0;
    final isPos    = profit >= 0;

    return _ReportCard(
      title: 'Profit & Loss',
      icon: Icons.account_balance_rounded,
      iconColor: isPos ? AppColors.success : AppColors.error,
      theme: theme,
      child: Column(children: [
        _StatRow('Revenue',  fmt.format(revenue),  color: AppColors.chartGreen, theme: theme),
        const SizedBox(height: 8),
        _StatRow('Cost of Goods', fmt.format(cogs), color: theme.colorScheme.onSurfaceVariant, theme: theme),
        const SizedBox(height: 8),
        _StatRow('Expenses', fmt.format(expenses), color: AppColors.chartRed, theme: theme),
        Divider(height: 24, color: theme.dividerColor),
        _StatRow('Net Profit', fmt.format(profit),
          color: isPos ? AppColors.success : AppColors.error,
          large: true, theme: theme),
        const SizedBox(height: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Margin', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            Text('${margin.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isPos ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (margin.abs() / 100).clamp(0.0, 1.0),
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation(isPos ? AppColors.success : AppColors.error),
              minHeight: 6,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SalesCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final NumberFormat fmt;
  final ThemeData theme;

  const _SalesCard({required this.stats, required this.fmt, required this.theme});

  @override
  Widget build(BuildContext context) {
    final totalSales  = (stats['totalSales']  as num?)?.toInt() ?? 0;
    final cashTotal   = (stats['cashTotal']   as num?)?.toDouble() ?? 0;
    final mpesaTotal  = (stats['mpesaTotal']  as num?)?.toDouble() ?? 0;
    final creditTotal = (stats['creditTotal'] as num?)?.toDouble() ?? 0;

    return _ReportCard(
      title: 'Sales Breakdown',
      icon: Icons.point_of_sale_rounded,
      iconColor: AppColors.accent,
      theme: theme,
      child: Column(children: [
        _StatRow('Total Transactions', '$totalSales', theme: theme),
        const SizedBox(height: 8),
        Divider(height: 16, color: theme.dividerColor),
        _StatRow('Cash',   fmt.format(cashTotal),   color: AppColors.chartBlue, theme: theme),
        const SizedBox(height: 8),
        _StatRow('M-Pesa', fmt.format(mpesaTotal),  color: AppColors.success, theme: theme),
        const SizedBox(height: 8),
        _StatRow('Credit', fmt.format(creditTotal), color: AppColors.warning, theme: theme),
      ]),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final NumberFormat fmt;
  final ThemeData theme;

  const _TopProductsCard({required this.stats, required this.fmt, required this.theme});

  @override
  Widget build(BuildContext context) {
    final top = (stats['topProducts'] as List?)?.cast<Map>() ?? [];

    return _ReportCard(
      title: 'Top Products',
      icon: Icons.emoji_events_rounded,
      iconColor: AppColors.accent,
      theme: theme,
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: i == 0
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: i == 0 ? AppColors.accent : theme.hintColor,
                    )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(p['name'] as String? ?? '',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmt.format((p['revenue'] as num?)?.toDouble() ?? 0),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                    color: theme.colorScheme.onSurface)),
                Text('${p['qty']} sold',
                  style: TextStyle(color: theme.hintColor, fontSize: 11)),
              ]),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _ExpenseBreakdownCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final NumberFormat fmt;
  final ThemeData theme;

  const _ExpenseBreakdownCard({required this.stats, required this.fmt, required this.theme});

  @override
  Widget build(BuildContext context) {
    final byCategory = (stats['expenseByCategory'] as Map?)
        ?.cast<String, dynamic>() ?? {};
    final total = byCategory.values
        .fold<double>(0, (s, v) => s + (v as num).toDouble());

    return _ReportCard(
      title: 'Expense Breakdown',
      icon: Icons.receipt_rounded,
      iconColor: AppColors.chartRed,
      theme: theme,
      child: Column(
        children: byCategory.entries.map((e) {
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
                  Text(fmt.format((e.value as num).toDouble()),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                      color: theme.colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.toDouble().clamp(0.0, 1.0),
                  backgroundColor: theme.dividerColor,
                  valueColor: const AlwaysStoppedAnimation(AppColors.chartRed),
                  minHeight: 5,
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final ThemeData theme;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title, style: theme.textTheme.titleLarge),
          ]),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool large;
  final ThemeData theme;

  const _StatRow(this.label, this.value, {this.color, this.large = false, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: large ? 15 : 13,
          )),
        Text(value,
          style: TextStyle(
            color: color ?? theme.colorScheme.onSurface,
            fontWeight: large ? FontWeight.w800 : FontWeight.w600,
            fontSize: large ? 16 : 14,
          )),
      ],
    );
  }
}
