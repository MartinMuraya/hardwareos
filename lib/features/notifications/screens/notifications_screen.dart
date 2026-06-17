import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/notification_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  NotificationSettings _settings = const NotificationSettings();
  bool _loading = true;
  String? _error;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final params = <String, dynamic>{'businessId': bizId, 'limit': 100};
      if (_filterStatus != 'all') params['status'] = _filterStatus;

      final results = await Future.wait([
        FunctionsService.call('getNotifications', params),
        FunctionsService.call('getNotificationSettings', {'businessId': bizId}),
      ]);

      final raw = (results[0]['notifications'] as List?) ?? [];
      final notifs = raw.map((e) => NotificationItem.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      final settings = NotificationSettings.fromMap(
        Map<String, dynamic>.from((results[1]['settings'] as Map?) ?? {}),
      );

      if (mounted) setState(() { _notifications = notifs; _settings = settings; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _updateSettings(NotificationSettings s) async {
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('updateNotificationSettings', {
        'businessId': bizId,
        'settings': s.toMap(),
      });
      setState(() => _settings = s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } on FunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading...',
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: theme.textTheme.displayMedium),
                const SizedBox(height: 12),
                TabBar(
                  labelColor: AppColors.accent,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: AppColors.accent,
                  tabs: const [
                    Tab(text: 'History'),
                    Tab(text: 'Settings'),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: TabBarView(
                    children: [
                      _buildHistoryTab(theme),
                      _buildSettingsTab(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    return Column(
      children: [
        Row(children: [
          _FilterChip(label: 'All', selected: _filterStatus == 'all', onTap: () { setState(() => _filterStatus = 'all'); _load(); }),
          const SizedBox(width: 8),
          _FilterChip(label: 'Sent', selected: _filterStatus == 'sent', onTap: () { setState(() => _filterStatus = 'sent'); _load(); }),
          const SizedBox(width: 8),
          _FilterChip(label: 'Pending', selected: _filterStatus == 'pending', onTap: () { setState(() => _filterStatus = 'pending'); _load(); }),
          const SizedBox(width: 8),
          _FilterChip(label: 'Failed', selected: _filterStatus == 'failed', onTap: () { setState(() => _filterStatus = 'failed'); _load(); }),
        ]),
        const SizedBox(height: 16),
        if (_error != null) _ErrorBar(message: _error!, onRetry: _load, theme: theme),
        Expanded(
          child: _notifications.isEmpty && !_loading
              ? const EmptyState(icon: Icons.notifications_none_rounded, title: 'No notifications', subtitle: 'Notifications will appear here.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _NotifCard(notif: _notifications[i], theme: theme),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Notification Preferences', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        _SettingTile(
          title: 'Debt Reminders',
          subtitle: 'Send reminders to customers with outstanding balances',
          value: _settings.debtReminders,
          onChanged: (v) => _updateSettings(NotificationSettings(
            debtReminders: v,
            lowStockAlerts: _settings.lowStockAlerts,
            paymentNotifications: _settings.paymentNotifications,
            quotationNotifications: _settings.quotationNotifications,
            provider: _settings.provider,
          )),
        ),
        _SettingTile(
          title: 'Low Stock Alerts',
          subtitle: 'Notify when products are below reorder level',
          value: _settings.lowStockAlerts,
          onChanged: (v) => _updateSettings(NotificationSettings(
            debtReminders: _settings.debtReminders,
            lowStockAlerts: v,
            paymentNotifications: _settings.paymentNotifications,
            quotationNotifications: _settings.quotationNotifications,
            provider: _settings.provider,
          )),
        ),
        _SettingTile(
          title: 'Payment Notifications',
          subtitle: 'Notify customers when payments are received',
          value: _settings.paymentNotifications,
          onChanged: (v) => _updateSettings(NotificationSettings(
            debtReminders: _settings.debtReminders,
            lowStockAlerts: _settings.lowStockAlerts,
            paymentNotifications: v,
            quotationNotifications: _settings.quotationNotifications,
            provider: _settings.provider,
          )),
        ),
        _SettingTile(
          title: 'Quotation Notifications',
          subtitle: 'Notify customers when quotations are ready',
          value: _settings.quotationNotifications,
          onChanged: (v) => _updateSettings(NotificationSettings(
            debtReminders: _settings.debtReminders,
            lowStockAlerts: _settings.lowStockAlerts,
            paymentNotifications: _settings.paymentNotifications,
            quotationNotifications: v,
            provider: _settings.provider,
          )),
        ),
        const SizedBox(height: 16),
        Text('Provider', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _settings.provider,
          decoration: const InputDecoration(labelText: 'Messaging Provider'),
          items: const [
            DropdownMenuItem(value: 'africas_talking', child: Text("Africa's Talking")),
            DropdownMenuItem(value: 'meta_whatsapp', child: Text('Meta WhatsApp Business')),
          ],
          onChanged: (v) {
            if (v != null) {
              _updateSettings(NotificationSettings(
                debtReminders: _settings.debtReminders,
                lowStockAlerts: _settings.lowStockAlerts,
                paymentNotifications: _settings.paymentNotifications,
                quotationNotifications: _settings.quotationNotifications,
                provider: v,
              ));
            }
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.info, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Set your Meta WhatsApp API keys:\nfirebase functions:secrets:set META_WA_TOKEN\nfirebase functions:secrets:set META_WA_PHONE_NUMBER_ID',
              style: TextStyle(fontSize: 11),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingTile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeTrackColor: AppColors.accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : theme.dividerColor),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : theme.colorScheme.onSurface,
          fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotificationItem notif;
  final ThemeData theme;
  const _NotifCard({required this.notif, required this.theme});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'debt_reminder': return Icons.account_balance_wallet_rounded;
      case 'payment_received': return Icons.check_circle_rounded;
      case 'quotation_ready': return Icons.description_rounded;
      case 'low_stock': return Icons.inventory_2_rounded;
      case 'transfer_approved': return Icons.swap_horiz_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent': return AppColors.success;
      case 'pending': return AppColors.warning;
      case 'failed': return AppColors.error;
      default: return theme.colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm');
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.chartBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon(notif.type), color: AppColors.chartBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(notif.type.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(notif.message, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Text(notif.recipient, style: TextStyle(fontSize: 10, color: theme.hintColor)),
              const SizedBox(width: 8),
              Text(fmt.format(notif.createdAt), style: TextStyle(fontSize: 10, color: theme.hintColor)),
            ]),
          ])),
          _Badge(label: notif.status.toUpperCase(), color: _statusColor(notif.status)),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
  );
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
