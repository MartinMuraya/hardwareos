import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/cash_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class CashDrawerScreen extends StatefulWidget {
  const CashDrawerScreen({super.key});
  @override
  State<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends State<CashDrawerScreen> {
  List<CashSession> _sessions = [];
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
      final data = await FunctionsService.call('getCashSessions', {'businessId': bizId, 'limit': 100});
      final raw = (data['sessions'] as List?) ?? [];
      final sessions = raw.map((e) => CashSession.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);
    final role = context.read<AuthProvider>().userRole ?? 'staff';
    final canManage = role == 'owner' || role == 'manager';
    final openSession = _sessions.where((s) => s.isOpen).firstOrNull;

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading cash sessions...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cash Drawer', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 4),
                  Text(openSession != null
                    ? 'Session open · Float: ${_fmt.format(openSession.openingFloat)}'
                    : 'No open session · ${_sessions.length} total',
                    style: theme.textTheme.bodyMedium),
                ])),
                if (canManage)
                  FilledButton.icon(
                    onPressed: openSession == null
                      ? () => _openSession(context)
                      : () => _closeSession(context, openSession),
                    icon: Icon(openSession == null ? Icons.lock_open_rounded : Icons.lock_rounded, size: 18),
                    label: Text(openSession == null ? 'Open Session' : 'Close Session'),
                  ),
              ]),
              const SizedBox(height: 20),

              if (_error != null)
                _ErrorBar(message: _error!, onRetry: _load, theme: theme),

              Expanded(
                child: _sessions.isEmpty && !_loading
                    ? const EmptyState(
                        icon: Icons.monetization_on_rounded,
                        title: 'No sessions yet',
                        subtitle: 'Open a cash session to start tracking.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.separated(
                          itemCount: _sessions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _SessionCard(
                            session: _sessions[i],
                            fmt: _fmt,
                            theme: theme,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSession(BuildContext ctx) async {
    final floatCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Open Cash Session'),
        content: TextField(
          controller: floatCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Opening Float (KES)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, floatCtrl.text), child: const Text('Open')),
        ],
      ),
    );

    if (result == null) return;
    final float = double.tryParse(result) ?? 0;
    if (float < 0) return;

    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('openCashSession', {'businessId': bizId, 'openingFloat': float});
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session opened')),
      );
    } on FunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _closeSession(BuildContext ctx, CashSession session) async {
    final cashCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Close Cash Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expected Cash: ${_fmt.format(session.expectedCash)}'),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual Cash Counted (KES)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, cashCtrl.text), child: const Text('Close')),
        ],
      ),
    );

    if (result == null) return;
    final actual = double.tryParse(result) ?? 0;
    if (actual < 0) return;

    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final res = await FunctionsService.call('closeCashSession', {
        'businessId': bizId,
        'sessionId': session.id,
        'actualCash': actual,
      });
      _load();
      if (mounted) {
        final variance = res['variance'] as num? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(variance == 0
              ? 'Session closed with zero variance'
              : variance > 0
                ? 'Session closed · Variance: +${_fmt.format(variance)}'
                : 'Session closed · Variance: ${_fmt.format(variance)}'),
          ),
        );
      }
    } on FunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }
}

class _SessionCard extends StatelessWidget {
  final CashSession session;
  final NumberFormat fmt;
  final ThemeData theme;
  const _SessionCard({required this.session, required this.fmt, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: session.isOpen ? AppColors.success.withValues(alpha: 0.3) : theme.dividerColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: session.isOpen ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(session.isOpen ? 'OPEN' : 'CLOSED',
              style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12,
                color: session.isOpen ? AppColors.success : theme.colorScheme.onSurfaceVariant,
              )),
            const Spacer(),
            Text(session.openedByName, style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _LabeledValue(label: 'Float', value: fmt.format(session.openingFloat), theme: theme)),
            Expanded(child: _LabeledValue(label: 'Expected', value: fmt.format(session.expectedCash), theme: theme)),
            Expanded(child: _LabeledValue(
              label: 'Variance',
              value: fmt.format(session.variance),
              color: session.variance < 0 ? AppColors.error : (session.variance > 0 ? AppColors.warning : null),
              theme: theme,
            )),
          ]),
        ]),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final ThemeData theme;
  const _LabeledValue({required this.label, required this.value, this.color, required this.theme});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
  ]);
}

class _ErrorBar extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  final ThemeData theme;
  const _ErrorBar({required this.message, required this.onRetry, required this.theme});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
