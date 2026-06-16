import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = true;
  String? _error;

  bool _maintenanceMode = false;
  final _bannerController = TextEditingController();
  String _alertLevel = 'info';
  String _backupFrequency = 'daily';
  String? _lastBackup;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final res = await FunctionsService.call('adminGetSettings', {});
      if (mounted) {
        setState(() {
          _maintenanceMode = res['maintenanceMode'] ?? false;
          _bannerController.text = res['broadcastBanner'] ?? '';
          _alertLevel = res['systemAlertLevel'] ?? 'info';
          _backupFrequency = res['backupFrequency'] ?? 'daily';
          _lastBackup = res['lastBackupTimestamp'] != null
              ? (res['lastBackupTimestamp'] as Map)['formatted'] ?? 'N/A'
              : 'N/A';
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

  Future<void> _saveSettings() async {
    setState(() => _loading = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      await FunctionsService.call('adminUpdateSettings', {
        'maintenanceMode': _maintenanceMode,
        'broadcastBanner': _bannerController.text.trim(),
        'systemAlertLevel': _alertLevel,
        'backupFrequency': _backupFrequency,
      });
      messenger.showSnackBar(const SnackBar(content: Text('Settings saved successfully.')));
      _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _triggerBackup() async {
    setState(() => _loading = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      await FunctionsService.call('adminUpdateSettings', {'triggerBackup': true});
      messenger.showSnackBar(const SnackBar(content: Text('Backup triggered successfully.')));
      _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Platform Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadSettings),
          const SizedBox(width: 24),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Maintenance and Control
                      _buildSectionHeader('System Controls', theme: theme),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Put the application offline for all standard business users.'),
                              value: _maintenanceMode,
                              onChanged: (val) => setState(() => _maintenanceMode = val),
                              activeThumbColor: AppColors.error,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Section 2: Notifications and Alerts
                      _buildSectionHeader('Broadcast Banners & Alerts', theme: theme),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _bannerController,
                              decoration: const InputDecoration(
                                labelText: 'System Broadcast Message',
                                hintText: 'Enter text to display as a top banner for all users.',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              initialValue: _alertLevel,
                              decoration: const InputDecoration(labelText: 'Alert Level'),
                              dropdownColor: theme.cardColor,
                              items: const [
                                DropdownMenuItem(value: 'info', child: Text('Info (Blue)')),
                                DropdownMenuItem(value: 'warning', child: Text('Warning (Amber)')),
                                DropdownMenuItem(value: 'critical', child: Text('Critical (Red)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _alertLevel = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Section 3: Backups
                      _buildSectionHeader('System Backup Operations', theme: theme),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _backupFrequency,
                              decoration: const InputDecoration(labelText: 'Backup Frequency'),
                              dropdownColor: theme.cardColor,
                              items: const [
                                DropdownMenuItem(value: 'daily', child: Text('Daily Auto Backup')),
                                DropdownMenuItem(value: 'weekly', child: Text('Weekly Auto Backup')),
                                DropdownMenuItem(value: 'monthly', child: Text('Monthly Auto Backup')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _backupFrequency = val);
                              },
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Last Backup Status',
                                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(_lastBackup ?? 'Never',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                                        color: theme.colorScheme.onSurface)),
                                  ],
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _triggerBackup,
                                  icon: const Icon(Icons.backup_rounded),
                                  label: const Text('Backup Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Actions row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _loadSettings,
                            child: const Text('Reset Changes'),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: _saveSettings,
                            child: const Text('Save Settings'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, {required ThemeData theme}) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent, letterSpacing: 0.8),
    );
  }
}
