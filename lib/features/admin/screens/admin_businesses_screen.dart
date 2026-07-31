import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hardwareos/core/router/route_paths.dart';

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
      final res = await FunctionsService.call(
          'adminGetAllBusinesses', {'filter': _filter});
      final list = (res['businesses'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _businesses =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _impersonateUser(String ownerUid) async {
    if (ownerUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No owner UID attached to this business')));
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await FunctionsService.call(
          'adminImpersonateTenant', {'targetUserId': ownerUid});
      final customToken = res['customToken'] as String;

      // Sign out of current admin session (locally only, custom token will sign us into new user)
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      if (mounted) {
        context.go(RoutePaths.dashboard);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impersonating user...')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteBusiness(String businessId, String businessName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Business?',
            style: TextStyle(color: AppColors.error)),
        content: Text(
            'Are you sure you want to hard delete "$businessName"?\n\nThis will permanently destroy all products, sales, and users associated with this business. This action CANNOT be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await FunctionsService.call(
          'adminDeleteBusiness', {'businessId': businessId});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business permanently deleted.')));
      _loadBusinesses();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Businesses',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadBusinesses),
          const SizedBox(width: 24),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                    label: 'All',
                    value: 'all',
                    groupValue: _filter,
                    onChanged: (v) {
                      setState(() => _filter = v);
                      _loadBusinesses();
                    },
                    theme: theme),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Pending',
                    value: 'pending',
                    groupValue: _filter,
                    onChanged: (v) {
                      setState(() => _filter = v);
                      _loadBusinesses();
                    },
                    theme: theme),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Active',
                    value: 'approved',
                    groupValue: _filter,
                    onChanged: (v) {
                      setState(() => _filter = v);
                      _loadBusinesses();
                    },
                    theme: theme),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Suspended',
                    value: 'suspended',
                    groupValue: _filter,
                    onChanged: (v) {
                      setState(() => _filter = v);
                      _loadBusinesses();
                    },
                    theme: theme),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error)))
                    : _businesses.isEmpty
                        ? const EmptyState(
                            icon: Icons.store_rounded,
                            title: 'No Businesses Found',
                            subtitle:
                                'No businesses match the selected filter.')
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: _businesses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, i) {
                              final biz = _businesses[i];
                              final status = biz['status'] ?? 'pending';

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
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.storefront_rounded,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              biz['name'] ?? 'Unknown Business',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: theme
                                                      .colorScheme.onSurface)),
                                          const SizedBox(height: 4),
                                          Text('ID: ${biz['id']}',
                                              style: TextStyle(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 13)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _StatusBadge(status: status),
                                              const SizedBox(width: 12),
                                              Text(
                                                  'Created: ${biz['createdAt'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant,
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Actions Menu
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded),
                                      onSelected: (value) {
                                        if (value == 'impersonate') {
                                          _impersonateUser(biz['ownerId'] ??
                                              biz['ownerUid'] ??
                                              '');
                                        } else if (value == 'delete') {
                                          _deleteBusiness(
                                              biz['id'],
                                              biz['name'] ??
                                                  'Unknown Business');
                                        } else {
                                          _updateStatus(biz['id'], value);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (status == 'pending' ||
                                            status == 'suspended')
                                          const PopupMenuItem(
                                              value: 'approved',
                                              child:
                                                  Text('Approve / Reactivate')),
                                        if (status == 'pending')
                                          const PopupMenuItem(
                                              value: 'rejected',
                                              child:
                                                  Text('Reject Application')),
                                        if (status == 'approved')
                                          const PopupMenuItem(
                                              value: 'impersonate',
                                              child: Text('Log In As Business',
                                                  style: TextStyle(
                                                      color:
                                                          AppColors.accent))),
                                        if (status == 'approved')
                                          const PopupMenuItem(
                                              value: 'suspended',
                                              child: Text('Suspend Business',
                                                  style: TextStyle(
                                                      color:
                                                          AppColors.warning))),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete Permanently',
                                                style: TextStyle(
                                                    color: AppColors.error))),
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
  final ThemeData theme;

  const _FilterChip(
      {required this.label,
      required this.value,
      required this.groupValue,
      required this.onChanged,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      backgroundColor: Colors.transparent,
      side:
          BorderSide(color: isSelected ? AppColors.accent : theme.dividerColor),
      labelStyle: TextStyle(
          color: isSelected
              ? AppColors.accent
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
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
      case 'approved':
        color = AppColors.success;
        break;
      case 'suspended':
        color = AppColors.error;
        break;
      case 'rejected':
        color = AppColors.error;
        break;
      case 'pending':
        color = AppColors.warning;
        break;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
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
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
