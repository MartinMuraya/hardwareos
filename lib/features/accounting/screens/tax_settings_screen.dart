import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  bool _isLoading = true;
  String? _error;

  bool _eTimsEnabled = false;
  final _pinCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _branchCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final res =
          await FunctionsService.call('getTaxSettings', {'businessId': bizId});

      if (res.isNotEmpty) {
        _eTimsEnabled = res['eTimsEnabled'] ?? false;
        _pinCtrl.text = res['kraPin'] ?? '';
        _branchCodeCtrl.text = res['branchCode'] ?? '';
      }
    } catch (e) {
      _error = 'Failed to load tax settings: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('updateTaxSettings', {
        'businessId': bizId,
        'eTimsEnabled': _eTimsEnabled,
        'kraPin': _pinCtrl.text.trim(),
        'branchCode': _branchCodeCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax Settings saved successfully')),
        );
      }
    } catch (e) {
      _error = 'Failed to save: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 24),
            color: Colors.red.withValues(alpha: 0.1),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.blue, size: 28),
                    SizedBox(width: 12),
                    Text('KRA eTIMS Integration',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                    'Configure electronic tax invoice management for your branch.',
                    style: TextStyle(color: Colors.grey)),
                const Divider(height: 32),
                SwitchListTile(
                  title: const Text('Enable eTIMS Registration',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'Automatically send all completed sales to the revenue authority via the OSC API.'),
                  value: _eTimsEnabled,
                  onChanged: (val) => setState(() => _eTimsEnabled = val),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.blue,
                ),
                if (_eTimsEnabled) ...[
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _pinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'KRA PIN',
                      border: OutlineInputBorder(),
                      helperText: 'E.g. P051234567Z',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _branchCodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'eTIMS Branch Code',
                      border: OutlineInputBorder(),
                      helperText: 'E.g. 00',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Note: In this development environment, saving these settings will simulate eTIMS integration. Real KRA integration requires OSC API onboarding and production credentials.',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
