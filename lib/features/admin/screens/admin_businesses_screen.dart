import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';

class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _businesses = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _loading = true);
    try {
      final res = await FunctionsService.call('adminGetAllBusinesses', {'filter': _filter});
      final list = (res['businesses'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _businesses = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _updateStatus(String businessId, String newStatus) async {
    try {
      await FunctionsService.call('adminUpdateBusinessStatus', {
        'businessId': businessId,
        'status': newStatus,
      });
      _loadBusinesses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Businesses', style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadBusinesses),
          const SizedBox(width: 24),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', value: 'all', groupValue: _filter, onChanged: (v) { setState(() => _filter = v); _loadBusinesses(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Pending', value: 'pending', groupValue: _filter, onChanged: (v) { setState(() => _filter = v); _loadBusinesses(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Active', value: 'approved', groupValue: _filter, onChanged: (v) { setState(() => _filter = v); _loadBusinesses(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Suspended', value: 'suspended', groupValue: _filter, onChanged: (v) { setState(() => _filter = v); _loadBusinesses(); }),
              ],
            ),
          ),
          
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                : _businesses.isEmpty
                  ? const EmptyState(icon: Icons.store_rounded, title: 'No Businesses Found', subtitle: 'No businesses match the selected filter.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _businesses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final biz = _businesses[i];
                        final status = biz['status'] ?? 'pending';
                        
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.storefront_rounded, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(biz['name'] ?? 'Unknown Business', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('ID: ${biz['id']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _StatusBadge(status: status),
                                        const SizedBox(width: 12),
                                        Text('Created: ${biz['createdAt'] ?? 'N/A'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Actions Menu
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (value) => _updateStatus(biz['id'], value),
                                itemBuilder: (context) => [
                                  if (status == 'pending' || status == 'suspended')
                                    const PopupMenuItem(value: 'approved', child: Text('Approve / Reactivate')),
                                  if (status == 'pending')
                                    const PopupMenuItem(value: 'rejected', child: Text('Reject Application')),
                                  if (status == 'approved')
                                    const PopupMenuItem(value: 'suspended', child: Text('Suspend Business', style: TextStyle(color: AppColors.error))),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _FilterChip({required this.label, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
      labelStyle: TextStyle(color: isSelected ? AppColors.accent : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'approved': color = AppColors.success; break;
      case 'suspended': color = AppColors.error; break;
      case 'rejected': color = AppColors.error; break;
      case 'pending': color = AppColors.warning; break;
      default: color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
