import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/user.dart';

class EditStaffDialog extends StatefulWidget {
  final User user;
  final VoidCallback onUserUpdated;
  
  const EditStaffDialog({super.key, required this.user, required this.onUserUpdated});

  @override
  State<EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<EditStaffDialog> {
  late final TextEditingController _commissionCtrl;
  late String _role;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _commissionCtrl = TextEditingController(text: ((widget.user.commissionRate ?? 0) * 100).toStringAsFixed(1));
  }

  @override
  void dispose() {
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    final commission = double.tryParse(_commissionCtrl.text.trim()) ?? 0.0;

    setState(() { _loading = true; _error = null; });

    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('updateStaff', {
        'targetUid': widget.user.uid,
        'role': _role,
        'businessId': bizId,
        'commissionRate': commission / 100.0,
      });

      if (mounted) {
        widget.onUserUpdated();
        Navigator.of(context).pop();
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEditRole = widget.user.role != 'owner'; // Owners can't demote themselves here

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text('Edit Staff: ${widget.user.displayName}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (canEditRole) ...[
              Text('Role', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _role,
                dropdownColor: theme.cardColor,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff (Cashier)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _role = val);
                },
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _commissionCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Commission Rate (%)',
                hintText: 'e.g. 2.5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        FilledButton(
          onPressed: _loading ? null : _update,
          child: _loading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Save Changes'),
        ),
      ],
    );
  }
}
