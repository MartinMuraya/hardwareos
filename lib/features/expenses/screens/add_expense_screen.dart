import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _amountCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  String _category   = 'Operations';
  bool _submitting   = false;
  String? _error;

  static const _categories = [
    'Operations',
    'Rent & Utilities',
    'Salaries & Wages',
    'Transport & Fuel',
    'Stock Purchase',
    'Marketing',
    'Repairs & Maintenance',
    'Bank & Finance',
    'Government & Tax',
    'Other',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('createExpense', {
        'businessId': bizId,
        'category':   _category,
        'amount':     double.parse(_amountCtrl.text),
        'note':       _noteCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense recorded successfully!')),
        );
        context.pop();
      }
    } on FunctionsException catch (e) {
      setState(() { _error = e.message; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LoadingOverlay(
      isLoading: _submitting,
      message: 'Recording expense...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Add Expense'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.padding(context)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _ErrorCard(message: _error!, theme: theme),

                    // Amount
                    _Section(
                      title: 'Amount',
                      theme: theme,
                      child: TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          prefixText: 'KES  ',
                          prefixStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          return (n == null || n <= 0) ? 'Enter a valid amount' : null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Category
                    _Section(
                      title: 'Category',
                      theme: theme,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((c) {
                          final sel = c == _category;
                          return GestureDetector(
                            onTap: () => setState(() => _category = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.chartRed.withValues(alpha: 0.12)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? AppColors.chartRed
                                      : theme.dividerColor,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(c,
                                style: TextStyle(
                                  color: sel
                                      ? AppColors.chartRed
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: sel
                                      ? FontWeight.w600 : FontWeight.w400,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Note
                    _Section(
                      title: 'Note (optional)',
                      theme: theme,
                      child: TextFormField(
                        controller: _noteCtrl,
                        maxLines: 3,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Add a description...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Record Expense'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.chartRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final ThemeData theme;

  const _Section({required this.title, required this.child, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final ThemeData theme;
  const _ErrorCard({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
          style: const TextStyle(color: AppColors.error, fontSize: 13))),
      ]),
    );
  }
}
