import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _forecast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final biz = context.read<BusinessProvider>();
    if (biz.businessId == null) return;

    if (biz.plan != 'pro') {
      setState(() => _loading = false);
      _showUpgradeDialog();
      return;
    }

    try {
      final fns = FirebaseFunctions.instance;

      final results = await Future.wait([
        fns
            .httpsCallable('getAdvancedAnalytics')
            .call({'businessId': biz.businessId}),
        fns
            .httpsCallable('getDemandForecast')
            .call({'businessId': biz.businessId}),
      ]);

      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(results[0].data as Map);
          _forecast = Map<String, dynamic>.from(results[1].data as Map);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e')),
        );
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.planPro),
            SizedBox(width: 8),
            Text('Pro Feature'),
          ],
        ),
        content: const Text(
            'Advanced Analytics is available exclusively on the Pro plan. Upgrade to unlock powerful insights.'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Go back
              },
              child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Implement upgrade navigation
            },
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = Responsive.padding(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
            title: const Text('Advanced Analytics'),
            backgroundColor: Colors.transparent,
            elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_data == null || _forecast == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
            title: const Text('Advanced Analytics'),
            backgroundColor: Colors.transparent,
            elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium,
                  size: 64, color: AppColors.planPro),
              const SizedBox(height: 16),
              Text('Available on Pro Plan', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      );
    }

    final trends =
        List<Map<String, dynamic>>.from(_data!['salesTrend'] as List);
    final margins = List<Map<String, dynamic>>.from(_data!['margins'] as List);
    final forecasts =
        List<Map<String, dynamic>>.from(_forecast!['forecast'] as List);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartCard(
              title: '30-Day Sales Trend',
              child: SizedBox(
                height: 250,
                child: _buildSalesLineChart(trends, theme),
              ),
              theme: theme,
            ),
            const SizedBox(height: 24),
            _buildChartCard(
              title: 'Margin Analysis by Category',
              child: SizedBox(
                height: 250,
                child: _buildMarginsBarChart(margins, theme),
              ),
              theme: theme,
            ),
            const SizedBox(height: 24),
            Text('Demand Forecast (Next 30 Days)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildForecastTable(forecasts, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
      {required String title,
      required Widget child,
      required ThemeData theme}) {
    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSalesLineChart(
      List<Map<String, dynamic>> trends, ThemeData theme) {
    if (trends.isEmpty) return const Center(child: Text('No data'));

    final spots = <FlSpot>[];
    double maxVal = 0;

    for (int i = 0; i < trends.length; i++) {
      final val = (trends[i]['revenue'] as num).toDouble();
      if (val > maxVal) maxVal = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: theme.dividerColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= trends.length) return const SizedBox();
                if (idx % 7 != 0) return const SizedBox();
                final dateStr = trends[idx]['date'] as String;
                final dt = DateTime.parse(dateStr);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('MMM d').format(dt),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (val, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(NumberFormat.compact().format(val),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (trends.length - 1).toDouble(),
        minY: 0,
        maxY: maxVal * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginsBarChart(
      List<Map<String, dynamic>> margins, ThemeData theme) {
    if (margins.isEmpty) return const Center(child: Text('No data'));

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < margins.length && i < 10; i++) {
      // Max 10 categories
      final m = margins[i];
      final pct = (m['marginPercentage'] as num).toDouble();
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pct,
              color: pct >= 30
                  ? AppColors.success
                  : (pct >= 15 ? AppColors.warning : AppColors.error),
              width: 16,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: theme.dividerColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= margins.length) return const SizedBox();
                final cat = margins[idx]['category'] as String;
                final shortCat =
                    cat.length > 8 ? '${cat.substring(0, 6)}..' : cat;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(shortCat,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, meta) {
                return Text('${val.toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildForecastTable(
      List<Map<String, dynamic>> forecasts, ThemeData theme) {
    if (forecasts.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Not enough sales data to generate forecast.')));
    }

    return Card(
      color: theme.cardColor,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: forecasts.length > 10 ? 10 : forecasts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final f = forecasts[idx];
          final name = f['name'] as String;
          final stock = f['currentStock'] as num;
          final demand = f['predictedDemand30d'] as num;
          final reorder = f['suggestedReorderQuantity'] as num;

          return ListTile(
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Stock: $stock | Est. 30d Demand: $demand'),
            trailing: reorder > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text('Order $reorder',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  )
                : const Icon(Icons.check_circle,
                    color: AppColors.success, size: 20),
          );
        },
      ),
    );
  }
}
