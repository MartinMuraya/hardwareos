import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hr_provider.dart';

class HrSettingsTab extends StatefulWidget {
  const HrSettingsTab({super.key});

  @override
  State<HrSettingsTab> createState() => _HrSettingsTabState();
}

class _HrSettingsTabState extends State<HrSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  double _paye = 30.0;
  double _nhif = 2.75;
  double _nssf = 6.0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HrProvider>();

    if (provider.isLoading && provider.settings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = provider.settings;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Statutory Deduction Rates (%)', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Configure the standard rates for payroll generation. These apply globally to all employees.'),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: settings?.payeRate.toString() ?? _paye.toString(),
                decoration: const InputDecoration(labelText: 'PAYE Rate (%)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _paye = double.tryParse(val!) ?? 30.0,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: settings?.nhifRate.toString() ?? _nhif.toString(),
                decoration: const InputDecoration(labelText: 'NHIF Rate (%)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _nhif = double.tryParse(val!) ?? 2.75,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: settings?.nssfRate.toString() ?? _nssf.toString(),
                decoration: const InputDecoration(labelText: 'NSSF Rate (%)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _nssf = double.tryParse(val!) ?? 6.0,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: provider.isLoading ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    _formKey.currentState!.save();
                    try {
                      await provider.saveSettings(_paye, _nhif, _nssf);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!')));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: provider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
