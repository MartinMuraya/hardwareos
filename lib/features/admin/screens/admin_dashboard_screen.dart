import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/empty_state.dart';

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
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loadingStats = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Platform Admin', style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
            Text('Platform Overview', style: AppTheme.darkTheme.textTheme.displaySmall),
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
                    _AdminKpiCard(title: 'Total Businesses', value: _loadingStats ? '...' : '$_totalBusinesses', icon: Icons.store_rounded, color: AppColors.chartBlue),
                    _AdminKpiCard(title: 'Active Businesses', value: _loadingStats ? '...' : '$_activeBusinesses', icon: Icons.verified_rounded, color: AppColors.chartGreen),
                    _AdminKpiCard(title: 'Pending Approvals', value: _loadingStats ? '...' : '$_pendingBusinessesCount', icon: Icons.hourglass_empty_rounded, color: AppColors.chartAmber),
                    _AdminKpiCard(title: 'Suspended Businesses', value: _loadingStats ? '...' : '$_suspendedBusinessesCount', icon: Icons.block_rounded, color: AppColors.error),
                    _AdminKpiCard(title: 'Trial Accounts', value: _loadingStats ? '...' : '$_trialAccounts', icon: Icons.timer_rounded, color: AppColors.accent),
                    _AdminKpiCard(title: 'Expired Subscriptions', value: _loadingStats ? '...' : '$_expiredSubscriptions', icon: Icons.alarm_off_rounded, color: AppColors.textSecondary),
                    _AdminKpiCard(title: 'Platform Users', value: _loadingStats ? '...' : '$_totalUsers', icon: Icons.people_rounded, color: AppColors.chartPurple),
                    _AdminKpiCard(title: 'Transactions (Sales)', value: _loadingStats ? '...' : '$_totalSales', icon: Icons.point_of_sale_rounded, color: AppColors.success),
                    _AdminKpiCard(title: 'Monthly Revenue', value: _loadingStats ? '...' : '\$${_monthlyRevenue.toStringAsFixed(2)}', icon: Icons.monetization_on_rounded, color: AppColors.chartGreen),
                  ],
                );
              },
            ),

            const SizedBox(height: 48),
            // The pending approvals list has been moved to AdminBusinessesScreen
          ],
        ),
      ),
    );
  }
}

class _AdminKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AdminKpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
