import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';

class InviteUserDialog extends StatefulWidget {
  final VoidCallback onUserInvited;
  const InviteUserDialog({super.key, required this.onUserInvited});

  @override
  State<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<InviteUserDialog> {
  final _uidCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _role = 'staff';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _uidCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final uid = _uidCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (uid.isEmpty || name.isEmpty) {
      setState(() => _error = 'UID and Name are required.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('inviteUser', {
        'targetUid': uid,
        'role': _role,
        'businessId': bizId,
        'displayName': name,
      });

      if (mounted) {
        widget.onUserInvited();
        Navigator.of(context).pop();
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Invite Staff', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Firebase UID of the user you wish to invite. The user must have already created an account on the login screen.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _uidCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'User UID',
                hintText: 'e.g. jX9f2...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g. John Doe',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Role', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('Staff (Cashier)')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _invite,
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          child: _loading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
            : const Text('Invite'),
        ),
      ],
    );
  }
}
