import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loadingStats = true;
  String? _error;
  
  int _totalBusinesses = 0;
  int _activeBusinesses = 0;
  int _pendingBusinessesCount = 0;
  int _suspendedBusinessesCount = 0;
  int _trialAccounts = 0;
  int _expiredSubscriptions = 0;
  int _totalUsers = 0;
  int _totalSales = 0;
  double _monthlyRevenue = 0.0;
  double _totalRevenue = 0.0;
  int _totalTransactions = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final res = await FunctionsService.call('getPlatformStats', {});
      if (mounted) {
        setState(() {
          _totalBusinesses = res['totalBusinesses'] ?? 0;
          _activeBusinesses = res['activeBusinesses'] ?? 0;
          _pendingBusinessesCount = res['pendingBusinesses'] ?? 0;
          _suspendedBusinessesCount = res['suspendedBusinesses'] ?? 0;
          _trialAccounts = res['trialAccounts'] ?? 0;
          _expiredSubscriptions = res['expiredSubscriptions'] ?? 0;
          _totalUsers = res['totalUsers'] ?? 0;
          _totalSales = res['totalSales'] ?? 0;
          _monthlyRevenue = (res['monthlyRevenue'] ?? 0.0).toDouble();
          _totalRevenue = (res['totalRevenue'] ?? 0.0).toDouble();
          _totalTransactions = res['totalTransactions'] ?? 0;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loadingStats = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Platform Admin', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Overview', style: theme.textTheme.displaySmall),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            
            // KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                final crossAxisCount = isDesktop ? 3 : 2;
                final aspectRatio = isDesktop ? 2.5 : 1.8;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: aspectRatio,
                  children: [
                      _AdminKpiCard(title: 'Total Businesses',      value: _loadingStats ? '...' : '$_totalBusinesses',      icon: Icons.store_rounded,           color: AppColors.chartBlue, theme: theme),
                      _AdminKpiCard(title: 'Active Businesses',      value: _loadingStats ? '...' : '$_activeBusinesses',      icon: Icons.verified_rounded,         color: AppColors.chartGreen, theme: theme),
                      _AdminKpiCard(title: 'Pending Approvals',      value: _loadingStats ? '...' : '$_pendingBusinessesCount', icon: Icons.hourglass_empty_rounded,  color: AppColors.chartAmber, theme: theme),
                      _AdminKpiCard(title: 'Suspended Businesses',   value: _loadingStats ? '...' : '$_suspendedBusinessesCount', icon: Icons.block_rounded,          color: AppColors.error, theme: theme),
                      _AdminKpiCard(title: 'Trial Accounts',         value: _loadingStats ? '...' : '$_trialAccounts',         icon: Icons.timer_rounded,            color: AppColors.accent, theme: theme),
                      _AdminKpiCard(title: 'Expired Subscriptions',  value: _loadingStats ? '...' : '$_expiredSubscriptions',  icon: Icons.alarm_off_rounded,        color: theme.colorScheme.onSurfaceVariant, theme: theme),
                      _AdminKpiCard(title: 'Platform Users',         value: _loadingStats ? '...' : '$_totalUsers',            icon: Icons.people_rounded,           color: AppColors.chartPurple, theme: theme),
                      _AdminKpiCard(title: 'Sales Transactions',     value: _loadingStats ? '...' : '$_totalSales',            icon: Icons.point_of_sale_rounded,    color: AppColors.success, theme: theme),
                      _AdminKpiCard(title: 'Revenue This Month',     value: _loadingStats ? '...' : 'KES ${_monthlyRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}', icon: Icons.trending_up_rounded, color: AppColors.chartGreen, theme: theme),
                      _AdminKpiCard(title: 'Total Revenue (All-Time)', value: _loadingStats ? '...' : 'KES ${_totalRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}', icon: Icons.monetization_on_rounded, color: AppColors.chartBlue, theme: theme),
                      _AdminKpiCard(title: 'Paid Subscriptions',     value: _loadingStats ? '...' : '$_totalTransactions',     icon: Icons.receipt_long_rounded,     color: AppColors.chartAmber, theme: theme),
                    ],
                );
              },
            ),

            // Subscription Analytics Summary
            Container(
              padding: const EdgeInsets.all(24),
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
                      Text('Subscription Health', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => context.go('/admin/analytics'),
                        icon: const Icon(Icons.analytics_rounded, size: 16),
                        label: const Text('Full Analytics'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MiniStat(label: 'Active', value: '$_activeBusinesses', color: AppColors.success),
                      const SizedBox(width: 24),
                      _MiniStat(label: 'Trial', value: '$_trialAccounts', color: AppColors.info),
                      const SizedBox(width: 24),
                      _MiniStat(label: 'Expired', value: '$_expiredSubscriptions', color: AppColors.error),
                      const SizedBox(width: 24),
                      _MiniStat(label: 'Revenue', value: 'KES ${_monthlyRevenue.toStringAsFixed(0)}', color: AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _AdminKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final ThemeData theme;

  const _AdminKpiCard({required this.title, required this.value, required this.icon, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
