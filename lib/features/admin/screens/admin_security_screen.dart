import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class AdminSecurityScreen extends StatefulWidget {
  const AdminSecurityScreen({super.key});

  @override
  State<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends State<AdminSecurityScreen> {
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('getSecurityMetrics');
      final result = await fn.call();
      if (mounted) setState(() { _metrics = Map<String, dynamic>.from(result.data as Map); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Security Dashboard')),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryGrid(theme),
                  const SizedBox(height: 24),
                  _buildRecentEvents(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryGrid(ThemeData theme) {
    final failed = _metrics?['failedLogins'] as Map? ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security Overview', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: 'Failed Logins (1h)',
              value: '${failed['lastHour'] ?? 0}',
              icon: Icons.login_rounded,
              color: Colors.orange,
            ),
            _MetricCard(
              title: 'Failed Logins (24h)',
              value: '${failed['lastDay'] ?? 0}',
              icon: Icons.warning_rounded,
              color: Colors.deepOrange,
            ),
            _MetricCard(
              title: 'Locked Accounts',
              value: '${_metrics?['lockedAccounts'] ?? 0}',
              icon: Icons.lock_rounded,
              color: Colors.red,
            ),
            _MetricCard(
              title: 'PW Resets (1h)',
              value: '${(_metrics?['passwordResets'] as Map?)?['lastHour'] ?? 0}',
              icon: Icons.password_rounded,
              color: Colors.blue,
            ),
            _MetricCard(
              title: 'PW Resets (24h)',
              value: '${(_metrics?['passwordResets'] as Map?)?['lastDay'] ?? 0}',
              icon: Icons.password_rounded,
              color: Colors.indigo,
            ),
            _MetricCard(
              title: 'Role Changes (7d)',
              value: '${_metrics?['roleChanges7Days'] ?? 0}',
              icon: Icons.admin_panel_settings_rounded,
              color: Colors.purple,
            ),
            _MetricCard(
              title: 'Cross-Tenant (7d)',
              value: '${_metrics?['crossTenantViolations7Days'] ?? 0}',
              icon: Icons.shield_rounded,
              color: Colors.red.shade700,
            ),
            _MetricCard(
              title: 'Function Errors (24h)',
              value: '${_metrics?['functionErrors24h'] ?? 0}',
              icon: Icons.error_outline_rounded,
              color: Colors.amber.shade800,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentEvents(ThemeData theme) {
    final events = (_metrics?['recentEvents'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Security Events', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _loadMetrics,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No recent security events.', style: theme.textTheme.bodyMedium)),
            ),
          )
        else
          ...events.take(20).map((e) => _buildEventRow(e, theme)),
      ],
    );
  }

  Widget _buildEventRow(Map e, ThemeData theme) {
    final action = e['action'] as String? ?? 'UNKNOWN';
    final ts = e['timestamp'] as String?;
    String? displayTime;
    if (ts != null) {
      try {
        final dt = DateTime.parse(ts);
        displayTime = DateFormat('MMM dd HH:mm').format(dt);
      } catch (_) {}
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          _actionIcon(action),
          size: 18,
          color: _actionColor(action),
        ),
        title: Text(action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${displayTime ?? ''}${e['businessId'] != null ? ' | ${e['businessId']}' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: e['userId'] != null
          ? Text(e['userId']!.toString().substring(0, 8), style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))
          : null,
      ),
    );
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'LOGIN_FAILED': case 'LOGIN_LOCKED': return Icons.login_rounded;
      case 'PASSWORD_RESET_REQUESTED': return Icons.password_rounded;
      case 'ROLE_CHANGED': return Icons.admin_panel_settings_rounded;
      case 'CROSS_TENANT_VIOLATION': return Icons.shield_rounded;
      case 'FUNCTION_ERROR': return Icons.error_outline_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'LOGIN_FAILED': case 'LOGIN_LOCKED': return Colors.orange;
      case 'PASSWORD_RESET_REQUESTED': return Colors.blue;
      case 'ROLE_CHANGED': return Colors.purple;
      case 'CROSS_TENANT_VIOLATION': return Colors.red;
      case 'FUNCTION_ERROR': return Colors.amber;
      default: return Colors.grey;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
