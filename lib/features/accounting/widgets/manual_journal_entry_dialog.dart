import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../models/accounting_models.dart';

class ManualJournalEntryDialog extends StatefulWidget {
  const ManualJournalEntryDialog({super.key});

  @override
  State<ManualJournalEntryDialog> createState() =>
      _ManualJournalEntryDialogState();
}

class _ManualJournalEntryDialogState extends State<ManualJournalEntryDialog> {
  final _descCtrl = TextEditingController();
  final _debitCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();

  AccountModel? _selectedDebitAccount;
  AccountModel? _selectedCreditAccount;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _debitCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final debitAmt = double.tryParse(_debitCtrl.text) ?? 0;
    final creditAmt = double.tryParse(_creditCtrl.text) ?? 0;

    if (_descCtrl.text.isEmpty ||
        _selectedDebitAccount == null ||
        _selectedCreditAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (debitAmt <= 0 || creditAmt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amounts must be greater than zero')));
      return;
    }

    if ((debitAmt - creditAmt).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debits must equal Credits')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final lines = [
        {
          'accountId': _selectedDebitAccount!.id,
          'debit': debitAmt,
          'credit': 0
        },
        {
          'accountId': _selectedCreditAccount!.id,
          'debit': 0,
          'credit': creditAmt
        },
      ];
      await context
          .read<AccountingProvider>()
          .postManualJournal(_descCtrl.text, lines);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Journal Entry posted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountingProvider>().accounts;

    return AlertDialog(
      title: const Text('New Manual Journal Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description (e.g., Owner Investment)'),
            ),
            const SizedBox(height: 16),
            const Text('Debit (Dr)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<AccountModel>(
              initialValue: _selectedDebitAccount,
              isExpanded: true,
              hint: const Text('Select Debit Account'),
              items: accounts
                  .map((acc) => DropdownMenuItem(
                        value: acc,
                        child: Text('${acc.code} - ${acc.name}'),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedDebitAccount = val),
            ),
            TextField(
              controller: _debitCtrl,
              decoration: const InputDecoration(
                  labelText: 'Debit Amount', prefixText: 'KES '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                // Auto-fill credit if empty
                if (_creditCtrl.text.isEmpty) {
                  _creditCtrl.text = val;
                }
              },
            ),
            const SizedBox(height: 24),
            const Text('Credit (Cr)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<AccountModel>(
              initialValue: _selectedCreditAccount,
              isExpanded: true,
              hint: const Text('Select Credit Account'),
              items: accounts
                  .map((acc) => DropdownMenuItem(
                        value: acc,
                        child: Text('${acc.code} - ${acc.name}'),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCreditAccount = val),
            ),
            TextField(
              controller: _creditCtrl,
              decoration: const InputDecoration(
                  labelText: 'Credit Amount', prefixText: 'KES '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Post Entry'),
        ),
      ],
    );
  }
}
