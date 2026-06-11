import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final res = await FunctionsService.call('adminGetPlans', {});
      final list = (res['plans'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _plans = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _deletePlan(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Plan'),
        content: Text('Are you sure you want to delete plan: $id? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await FunctionsService.call('adminDeletePlan', {'id': id});
        _loadPlans();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
          setState(() => _loading = false);
        }
      }
    }
  }

  Future<void> _savePlan([Map<String, dynamic>? plan]) async {
    final isNew = plan == null;
    final idController = TextEditingController(text: plan?['id'] ?? '');
    final nameController = TextEditingController(text: plan?['name'] ?? '');
    final priceController = TextEditingController(text: plan?['price']?.toString() ?? '0');
    final maxProductsController = TextEditingController(text: plan?['maxProducts']?.toString() ?? '50');
    final maxUsersController = TextEditingController(text: plan?['maxUsers']?.toString() ?? '1');
    final maxDailySalesController = TextEditingController(text: plan?['maxDailySales']?.toString() ?? '-1');
    final trialDaysController = TextEditingController(text: plan?['trialDays']?.toString() ?? '14');

    bool reportsEnabled = plan?['reportsEnabled'] ?? true;
    bool aiEnabled = plan?['aiEnabled'] ?? false;
    bool whatsappEnabled = plan?['whatsappEnabled'] ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(isNew ? 'Create New Plan' : 'Edit Plan: ${plan['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNew)
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'Plan ID (e.g. enterprise)'),
                ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Plan Name'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price (\$/month)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxProductsController,
                decoration: const InputDecoration(labelText: 'Max Products (-1 for unlimited)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxUsersController,
                decoration: const InputDecoration(labelText: 'Max Users (-1 for unlimited)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxDailySalesController,
                decoration: const InputDecoration(labelText: 'Max Daily Sales (-1 for unlimited)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: trialDaysController,
                decoration: const InputDecoration(labelText: 'Trial Duration (Days)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setCheckState) {
                  return Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Reports Enabled'),
                        value: reportsEnabled,
                        activeColor: AppColors.accent,
                        onChanged: (val) => setCheckState(() => reportsEnabled = val ?? true),
                      ),
                      CheckboxListTile(
                        title: const Text('AI Features Enabled'),
                        value: aiEnabled,
                        activeColor: AppColors.accent,
                        onChanged: (val) => setCheckState(() => aiEnabled = val ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('WhatsApp Integration Enabled'),
                        value: whatsappEnabled,
                        activeColor: AppColors.accent,
                        onChanged: (val) => setCheckState(() => whatsappEnabled = val ?? false),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      try {
        final payload = {
          'id': isNew ? idController.text.trim() : plan['id'],
          'name': nameController.text.trim(),
          'price': double.tryParse(priceController.text) ?? 0.0,
          'maxProducts': int.tryParse(maxProductsController.text) ?? -1,
          'maxUsers': int.tryParse(maxUsersController.text) ?? -1,
          'maxDailySales': int.tryParse(maxDailySalesController.text) ?? -1,
          'trialDays': int.tryParse(trialDaysController.text) ?? 14,
          'reportsEnabled': reportsEnabled,
          'aiEnabled': aiEnabled,
          'whatsappEnabled': whatsappEnabled,
        };

        if (isNew) {
          await FunctionsService.call('adminCreatePlan', payload);
        } else {
          await FunctionsService.call('adminUpdatePlan', payload);
        }
        _loadPlans();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
          setState(() => _loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Subscription Plans', style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadPlans),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _savePlan(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Plan'),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _plans.isEmpty
                  ? const EmptyState(
                      icon: Icons.view_list_rounded,
                      title: 'No Plans Found',
                      subtitle: 'Click "Create Plan" to define your subscription structures.')
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        mainAxisExtent: 320,
                      ),
                      itemCount: _plans.length,
                      itemBuilder: (context, i) {
                        final p = _plans[i];
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['name'] ?? 'Unnamed Plan',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '\$${p['price']}/mo',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('ID: ${p['id']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const Divider(height: 24, color: AppColors.border),
                              Expanded(
                                child: Column(
                                  children: [
                                    _LimitRow(icon: Icons.inventory_2_rounded, label: 'Products Limit', value: p['maxProducts'] == -1 ? 'Unlimited' : '${p['maxProducts']}'),
                                    _LimitRow(icon: Icons.people_rounded, label: 'Users Limit', value: p['maxUsers'] == -1 ? 'Unlimited' : '${p['maxUsers']}'),
                                    _LimitRow(icon: Icons.auto_awesome_rounded, label: 'AI Assistance', value: p['aiEnabled'] == true ? 'Yes' : 'No'),
                                    _LimitRow(icon: Icons.chat_rounded, label: 'WhatsApp Bot', value: p['whatsappEnabled'] == true ? 'Yes' : 'No'),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary),
                                    onPressed: () => _savePlan(p),
                                    tooltip: 'Edit Plan',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                                    onPressed: () => _deletePlan(p['id']),
                                    tooltip: 'Delete Plan',
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LimitRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
