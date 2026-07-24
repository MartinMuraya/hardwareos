import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class LabelSettingsScreen extends StatefulWidget {
  const LabelSettingsScreen({super.key});

  @override
  State<LabelSettingsScreen> createState() => _LabelSettingsScreenState();
}

class _LabelSettingsScreenState extends State<LabelSettingsScreen> {
  String _paperSize = '58mm'; // '38mm' | '58mm' | '80mm'
  bool _showBusinessName = true;
  bool _showPrice = true;
  bool _showSku = true;
  int _defaultCopies = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paperSize = prefs.getString('label_paper_size') ?? '58mm';
      _showBusinessName = prefs.getBool('label_show_biz_name') ?? true;
      _showPrice = prefs.getBool('label_show_price') ?? true;
      _showSku = prefs.getBool('label_show_sku') ?? true;
      _defaultCopies = prefs.getInt('label_default_copies') ?? 1;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('label_paper_size', _paperSize);
    await prefs.setBool('label_show_biz_name', _showBusinessName);
    await prefs.setBool('label_show_price', _showPrice);
    await prefs.setBool('label_show_sku', _showSku);
    await prefs.setInt('label_default_copies', _defaultCopies);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label printer settings saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/dashboard');
            }
          },
        ),
        title: Text('Barcode Label Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Paper Size & Layout', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _paperSize,
                                decoration: const InputDecoration(
                                  labelText: 'Thermal Label Paper Size',
                                  prefixIcon: Icon(Icons.aspect_ratio_rounded),
                                ),
                                dropdownColor: theme.cardColor,
                                items: const [
                                  DropdownMenuItem(value: '38mm', child: Text('38mm × 25mm (Small Jewelry / Hardware Roll)')),
                                  DropdownMenuItem(value: '58mm', child: Text('58mm × 30mm (Standard Desktop Thermal Printer)')),
                                  DropdownMenuItem(value: '80mm', child: Text('80mm × 40mm (Large Product Tag)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _paperSize = val);
                                },
                              ),
                              const SizedBox(height: 20),
                              SwitchListTile(
                                title: const Text('Show Store / Business Name'),
                                value: _showBusinessName,
                                onChanged: (val) => setState(() => _showBusinessName = val),
                                activeThumbColor: AppColors.accent,
                              ),
                              SwitchListTile(
                                title: const Text('Show Price (KES)'),
                                value: _showPrice,
                                onChanged: (val) => setState(() => _showPrice = val),
                                activeThumbColor: AppColors.accent,
                              ),
                              SwitchListTile(
                                title: const Text('Show SKU Code'),
                                value: _showSku,
                                onChanged: (val) => setState(() => _showSku = val),
                                activeThumbColor: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Label Preview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Center(
                                child: Container(
                                  width: _paperSize == '38mm' ? 160 : (_paperSize == '58mm' ? 220 : 280),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black26),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_showBusinessName)
                                        const Text('KAMAU HARDWARE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                      const SizedBox(height: 2),
                                      const Text('Portland Cement 50kg', style: TextStyle(fontSize: 9, color: Colors.black)),
                                      if (_showSku)
                                        const Text('SKU: CEM-50', style: TextStyle(fontSize: 8, color: Colors.black54)),
                                      const SizedBox(height: 4),
                                      const Icon(Icons.view_column_rounded, size: 28, color: Colors.black),
                                      const Text('123456789', style: TextStyle(fontSize: 8, color: Colors.black)),
                                      if (_showPrice) ...[
                                        const SizedBox(height: 2),
                                        const Text('KES 850.00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Settings', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
