import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});
  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _idCtrl.dispose(); _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('createCustomer', {
        'businessId': bizId,
        'fullName': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'nationalId': _idCtrl.text.trim(),
        'creditLimit': double.tryParse(_limitCtrl.text.trim()) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer created successfully.')),
        );
        context.pop(true);
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _submitting,
      message: 'Creating customer...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Add Customer'),
          actions: [
            TextButton(onPressed: _submitting ? null : _submit, child: const Text('Save')),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ]),
                    ),
                  _Section(label: 'Personal Information', child: Column(children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. John Kamau'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone Number *', hintText: 'e.g. 0712345678'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _idCtrl,
                      decoration: const InputDecoration(labelText: 'National ID (optional)', hintText: 'e.g. 12345678'),
                    ),
                  ])),
                  const SizedBox(height: 20),
                  _Section(label: 'Credit Settings', child: Column(children: [
                    TextFormField(
                      controller: _limitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Credit Limit (KES)',
                        hintText: 'Leave empty for no limit',
                        prefixText: 'KES ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ])),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Create Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: child,
      ),
    ]);
  }
}


