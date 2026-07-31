import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';

class AdminPlanConfigsScreen extends StatefulWidget {
  const AdminPlanConfigsScreen({super.key});

  @override
  State<AdminPlanConfigsScreen> createState() => _AdminPlanConfigsScreenState();
}

class _AdminPlanConfigsScreenState extends State<AdminPlanConfigsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await FunctionsService.call('adminGetPlanConfigs', {});
      final list = (res['plans'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _plans =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _editPlanModal([Map<String, dynamic>? plan]) async {
    final theme = Theme.of(context);
    final isNew = plan == null;
    final planData = plan ?? {};

    final idCtrl = TextEditingController(text: planData['id'] ?? '');
    final nameCtrl =
        TextEditingController(text: planData['name'] ?? planData['id']);
    final priceCtrl =
        TextEditingController(text: (planData['priceKes'] ?? 0).toString());
    final maxProdCtrl =
        TextEditingController(text: (planData['maxProducts'] ?? -1).toString());
    final maxUsersCtrl =
        TextEditingController(text: (planData['maxUsers'] ?? -1).toString());

    bool aiBasic = planData['aiBasicEnabled'] ?? false;
    bool aiAnalyst = planData['aiAnalystEnabled'] ?? false;
    bool whatsapp = planData['whatsappEnabled'] ?? false;
    bool etims = planData['etimsEnabled'] ?? false;
    bool storefront = planData['storefrontEnabled'] ?? false;
    bool advancedAnalytics = planData['advancedAnalyticsEnabled'] ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text(isNew
                  ? 'Create New Plan Tier'
                  : 'Edit Plan Tier: ${planData['id'].toUpperCase()}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNew) ...[
                      TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Plan ID (e.g. basic, ultra)'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Plan Display Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Monthly Price (KES)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxProdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Products Limit (-1 for unlimited)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxUsersCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Users Limit (-1 for unlimited)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Feature Toggles & Gating',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('AI Chatbot (Basic Q&A)'),
                      subtitle: const Text('Available for Starter & Pro plans'),
                      value: aiBasic,
                      onChanged: (v) => setDialogState(() => aiBasic = v),
                      activeThumbColor: AppColors.accent,
                    ),
                    SwitchListTile(
                      title: const Text('AI Business Analyst & Workflows'),
                      subtitle: const Text(
                          'Run-out predictions & draft PO approvals (Pro exclusive)'),
                      value: aiAnalyst,
                      onChanged: (v) => setDialogState(() => aiAnalyst = v),
                      activeThumbColor: AppColors.accent,
                    ),
                    SwitchListTile(
                      title: const Text('WhatsApp Integration'),
                      value: whatsapp,
                      onChanged: (v) => setDialogState(() => whatsapp = v),
                      activeThumbColor: AppColors.accent,
                    ),
                    SwitchListTile(
                      title: const Text('eTIMS KRA Integration'),
                      value: etims,
                      onChanged: (v) => setDialogState(() => etims = v),
                      activeThumbColor: AppColors.accent,
                    ),
                    SwitchListTile(
                      title: const Text('B2B / B2C Storefront'),
                      value: storefront,
                      onChanged: (v) => setDialogState(() => storefront = v),
                      activeThumbColor: AppColors.accent,
                    ),
                    SwitchListTile(
                      title: const Text('Advanced Analytics'),
                      value: advancedAnalytics,
                      onChanged: (v) =>
                          setDialogState(() => advancedAnalytics = v),
                      activeThumbColor: AppColors.accent,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Plan Config'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) {
      return; // Guard against using context after the dialog if the state was disposed
    }
    final messenger = ScaffoldMessenger.of(context);

    if (result == true) {
      if (isNew && idCtrl.text.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Plan ID is required'),
            backgroundColor: AppColors.error));
        return;
      }
      try {
        await FunctionsService.call('adminSavePlanConfig', {
          'planId': isNew ? idCtrl.text.trim().toLowerCase() : planData['id'],
          'config': {
            'name': nameCtrl.text.trim(),
            'priceKes': double.tryParse(priceCtrl.text) ?? 0,
            'maxProducts': int.tryParse(maxProdCtrl.text) ?? -1,
            'maxUsers': int.tryParse(maxUsersCtrl.text) ?? -1,
            'aiBasicEnabled': aiBasic,
            'aiAnalystEnabled': aiAnalyst,
            'whatsappEnabled': whatsapp,
            'etimsEnabled': etims,
            'storefrontEnabled': storefront,
            'advancedAnalyticsEnabled': advancedAnalytics,
          },
        });
        if (mounted) {
          messenger.showSnackBar(const SnackBar(
              content: Text('Plan configuration updated successfully!')));
          _loadPlans();
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(
              content: Text('Failed saving plan: $e'),
              backgroundColor: AppColors.error));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription Plan CRUD',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text('Super Admin Tier & Feature Configuration',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _loadPlans),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dynamic Tier Pricing & Feature Gating',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Configure feature access for Free, Starter, and Pro tiers dynamically.',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _plans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, i) {
                          final plan = _plans[i];
                          final isPro = plan['id'] == 'pro';
                          final isStarter = plan['id'] == 'starter';

                          return Card(
                            color: theme.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: isPro
                                      ? AppColors.accent
                                      : theme.dividerColor,
                                  width: isPro ? 2 : 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isPro
                                                ? Icons
                                                    .workspace_premium_rounded
                                                : (isStarter
                                                    ? Icons.stars_rounded
                                                    : Icons.label_rounded),
                                            color: isPro
                                                ? AppColors.accent
                                                : (isStarter
                                                    ? Colors.blue
                                                    : Colors.grey),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            plan['name'] ??
                                                plan['id'].toUpperCase(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'KES ${plan['priceKes'] ?? 0} / mo',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: AppColors.accent),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _FeatureBadge(
                                          label:
                                              'Max Products: ${plan['maxProducts'] == -1 ? 'Unlimited' : plan['maxProducts']}'),
                                      _FeatureBadge(
                                          label:
                                              'Max Users: ${plan['maxUsers'] == -1 ? 'Unlimited' : plan['maxUsers']}'),
                                      if (plan['aiBasicEnabled'] == true)
                                        const _FeatureBadge(
                                            label: '🤖 AI Chatbot',
                                            color: Colors.green),
                                      if (plan['aiAnalystEnabled'] == true)
                                        const _FeatureBadge(
                                            label:
                                                '🧠 AI Business Analyst & Workflows',
                                            color: AppColors.accent),
                                      if (plan['whatsappEnabled'] == true)
                                        const _FeatureBadge(
                                            label: '📲 WhatsApp',
                                            color: Colors.teal),
                                      if (plan['etimsEnabled'] == true)
                                        const _FeatureBadge(
                                            label: '📋 eTIMS KRA',
                                            color: Colors.blue),
                                      if (plan['storefrontEnabled'] == true)
                                        const _FeatureBadge(
                                            label: '🛒 Storefront',
                                            color: Colors.purple),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _editPlanModal(plan),
                                      icon: const Icon(Icons.edit_rounded,
                                          size: 16),
                                      label: const Text('Edit Plan Config'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPlanModal(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Plan'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String label;
  final Color? color;
  const _FeatureBadge({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bg)),
    );
  }
}
