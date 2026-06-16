import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _loading = true);
    try {
      final res = await FunctionsService.call('adminGetSubscriptions', {});
      final list = (res['subscriptions'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _subscriptions = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _editSubscription(Map<String, dynamic> sub) async {
    final theme = Theme.of(context);
    String selectedPlan = sub['plan'] ?? 'free';
    String selectedStatus = sub['subscriptionStatus'] ?? 'trial';
    bool active = sub['active'] ?? false;
    
    DateTime? trialEndsAt = sub['trialEndsAt'] != null ? DateTime.parse(sub['trialEndsAt']) : null;
    DateTime? subscriptionEndsAt = sub['subscriptionEndsAt'] != null ? DateTime.parse(sub['subscriptionEndsAt']) : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text('Edit Subscription: ${sub['businessName']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedPlan,
                      decoration: const InputDecoration(labelText: 'Plan'),
                      dropdownColor: theme.cardColor,
                      items: const [
                        DropdownMenuItem(value: 'free', child: Text('Free')),
                        DropdownMenuItem(value: 'starter', child: Text('Starter')),
                        DropdownMenuItem(value: 'pro', child: Text('Pro')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedPlan = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Subscription Status'),
                      dropdownColor: theme.cardColor,
                      items: const [
                        DropdownMenuItem(value: 'trial', child: Text('Trial')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'expired', child: Text('Expired')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active Status'),
                      value: active,
                      onChanged: (val) => setDialogState(() => active = val),
                      activeThumbColor: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Trial Ends: ${trialEndsAt?.toLocal().toString().split(' ')[0] ?? 'None'}'),
                      trailing: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: trialEndsAt ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setDialogState(() => trialEndsAt = picked);
                        }
                      },
                    ),
                    ListTile(
                      title: Text('Subscription Ends: ${subscriptionEndsAt?.toLocal().toString().split(' ')[0] ?? 'None'}'),
                      trailing: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: subscriptionEndsAt ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setDialogState(() => subscriptionEndsAt = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() => _loading = true);
      try {
        await FunctionsService.call('adminUpdateSubscription', {
          'businessId': sub['businessId'],
          'plan': selectedPlan,
          'subscriptionStatus': selectedStatus,
          'active': active,
          'trialEndsAt': trialEndsAt?.toIso8601String(),
          'subscriptionEndsAt': subscriptionEndsAt?.toIso8601String(),
        });
        _loadSubscriptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          setState(() => _loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Subscriptions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadSubscriptions),
          const SizedBox(width: 24),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _subscriptions.isEmpty
                  ? const EmptyState(
                      icon: Icons.card_membership_rounded,
                      title: 'No Subscriptions Found',
                      subtitle: 'Register businesses to see subscription logs.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _subscriptions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final sub = _subscriptions[i];
                        final expires = sub['subscriptionEndsAt'] != null
                            ? DateTime.parse(sub['subscriptionEndsAt']).toLocal().toString().split(' ')[0]
                            : (sub['trialEndsAt'] != null
                                ? DateTime.parse(sub['trialEndsAt']).toLocal().toString().split(' ')[0]
                                : 'Never');

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.credit_card_rounded, color: AppColors.accent),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sub['businessName'] ?? 'Unknown',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                                        color: theme.colorScheme.onSurface)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _Badge(label: (sub['plan'] ?? 'free').toUpperCase(), color: AppColors.accent),
                                        const SizedBox(width: 8),
                                        _Badge(
                                            label: (sub['subscriptionStatus'] ?? 'trial').toUpperCase(),
                                            color: sub['subscriptionStatus'] == 'active' ? AppColors.success : AppColors.warning),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Expires/Trial Ends: $expires',
                                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_rounded, color: theme.colorScheme.onSurfaceVariant),
                                onPressed: () => _editSubscription(sub),
                                tooltip: 'Edit Subscription',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
