import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final res = await FunctionsService.call('adminGetUsers', {});
      final list = (res['users'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _editUser(Map<String, dynamic> user) async {
    String selectedRole = user['role'] ?? 'staff';
    bool disabled = user['disabled'] ?? false;
    bool resetPassword = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              title: Text('Edit User: ${user['displayName']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    dropdownColor: AppColors.card,
                    items: const [
                      DropdownMenuItem(value: 'owner', child: Text('Owner')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Disable Login'),
                    value: disabled,
                    onChanged: (val) => setDialogState(() => disabled = val),
                    activeColor: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Generate Password Reset Link'),
                    value: resetPassword,
                    activeColor: AppColors.accent,
                    onChanged: (val) => setDialogState(() => resetPassword = val ?? false),
                  ),
                ],
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
        final res = await FunctionsService.call('adminUpdateUser', {
          'uid': user['uid'],
          'role': selectedRole,
          'disabled': disabled,
          'resetPassword': resetPassword,
        });

        if (resetPassword && res['resetLink'] != null) {
          final link = res['resetLink'] as String;
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.card,
                title: const Text('Password Reset Link'),
                content: SelectableText(link, style: const TextStyle(fontFamily: 'monospace')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ],
              ),
            );
          }
        }
        _loadUsers();
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
        title: Text('Platform Users', style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadUsers),
          const SizedBox(width: 24),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _users.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_rounded,
                      title: 'No Users Found',
                      subtitle: 'Register businesses to see user accounts.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final u = _users[i];
                        final isSuspended = u['disabled'] == true;

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
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  u['role'] == 'owner'
                                      ? Icons.admin_panel_settings_rounded
                                      : (u['role'] == 'manager' ? Icons.shield_rounded : Icons.person_rounded),
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (u['displayName'] as String).isNotEmpty ? u['displayName'] : 'No Name Set',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(u['email'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                                          ),
                                          child: Text((u['role'] ?? 'staff').toUpperCase(), style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                        if (isSuspended) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                                            ),
                                            child: const Text('SUSPENDED', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                        const SizedBox(width: 12),
                                        Text('Business: ${u['businessId']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary),
                                onPressed: () => _editUser(u),
                                tooltip: 'Edit User Settings',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
