import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final res = await FunctionsService.call('getSubscriptionAnalytics', {});
      if (mounted) {
        setState(() {
          _stats = res;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Subscription Analytics', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAnalytics),
          const SizedBox(width: 24),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _stats == null
                  ? const EmptyState(icon: Icons.analytics_rounded, title: 'No Data', subtitle: 'Analytics will appear once computed.')
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCards(theme),
                          const SizedBox(height: 32),
                          _buildDistributionSection(theme),
                          const SizedBox(height: 32),
                          _buildHealthSection(theme),
                          const SizedBox(height: 32),
                          _buildComputedAt(theme),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final mrr = (_stats?['monthlyRecurringRevenue'] as num?)?.toDouble() ?? 0;
    final totalRevenue = (_stats?['totalRevenue'] as num?)?.toDouble() ?? 0;
    final churnRate = (_stats?['churnRate'] as num?)?.toDouble() ?? 0;
    final paymentSuccessRate = (_stats?['paymentSuccessRate'] as num?)?.toDouble() ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Metrics', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2,
          children: [
            _MetricCard(
              label: 'MRR (KES)',
              value: mrr.toStringAsFixed(0),
              icon: Icons.trending_up_rounded,
              color: AppColors.success,
            ),
            _MetricCard(
              label: 'Total Revenue (KES)',
              value: totalRevenue.toStringAsFixed(0),
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.accent,
            ),
            _MetricCard(
              label: 'Churn Rate (30d)',
              value: '${(churnRate * 100).toStringAsFixed(1)}%',
              icon: Icons.people_outline_rounded,
              color: churnRate > 0.1 ? AppColors.error : AppColors.success,
            ),
            _MetricCard(
              label: 'Payment Success Rate',
              value: '${(paymentSuccessRate * 100).toStringAsFixed(0)}%',
              icon: Icons.check_circle_rounded,
              color: paymentSuccessRate > 0.8 ? AppColors.success : AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistributionSection(ThemeData theme) {
    final total = (_stats?['totalBusinesses'] as num?)?.toInt() ?? 0;
    final active = (_stats?['activeSubscriptions'] as num?)?.toInt() ?? 0;
    final trial = (_stats?['trialAccounts'] as num?)?.toInt() ?? 0;
    final grace = (_stats?['gracePeriodAccounts'] as num?)?.toInt() ?? 0;
    final expired = (_stats?['expiredSubscriptions'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account Distribution', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              _buildDistributionRow('Total Businesses', total, AppColors.accent, total),
              const Divider(height: 24),
              _buildDistributionRow('Active', active, AppColors.success, total),
              const SizedBox(height: 8),
              _buildDistributionRow('Trial', trial, AppColors.info, total),
              const SizedBox(height: 8),
              _buildDistributionRow('Grace Period', grace, AppColors.warning, total),
              const SizedBox(height: 8),
              _buildDistributionRow('Expired', expired, AppColors.error, total),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionRow(String label, int count, Color color, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text('$count', textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildHealthSection(ThemeData theme) {
    final churnCount = (_stats?['churnCount'] as num?)?.toInt() ?? 0;
    final recoveryCount = (_stats?['recoveryCount'] as num?)?.toInt() ?? 0;
    final failedPayments = (_stats?['failedPayments'] as num?)?.toInt() ?? 0;
    final totalPayments = (_stats?['totalPaymentsLast30'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Health Overview (Last 30 Days)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _HealthIndicator(
                      label: 'Churned',
                      value: churnCount.toString(),
                      icon: Icons.person_off_rounded,
                      color: churnCount > 10 ? AppColors.error : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _HealthIndicator(
                      label: 'Recovered',
                      value: recoveryCount.toString(),
                      icon: Icons.person_add_alt_1_rounded,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HealthIndicator(
                      label: 'Failed Payments',
                      value: failedPayments.toString(),
                      icon: Icons.cancel_rounded,
                      color: failedPayments > 5 ? AppColors.error : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _HealthIndicator(
                      label: 'Total Payments',
                      value: totalPayments.toString(),
                      icon: Icons.payments_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComputedAt(ThemeData theme) {
    final computedAt = _stats?['computedAt'] as String?;
    if (computedAt == null) return const SizedBox.shrink();
    return Center(
      child: Text('Last updated: ${DateTime.tryParse(computedAt)?.toLocal().toString() ?? computedAt}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.onSurface)),
                Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthIndicator extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HealthIndicator({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
            Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
