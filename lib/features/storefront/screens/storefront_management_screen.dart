import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/storefront_models.dart';

class StorefrontManagementScreen extends StatefulWidget {
  const StorefrontManagementScreen({super.key});

  @override
  State<StorefrontManagementScreen> createState() => _StorefrontManagementScreenState();
}

class _StorefrontManagementScreenState extends State<StorefrontManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _slugCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _bannerUrlCtrl = TextEditingController();
  final _primaryColorCtrl = TextEditingController(text: '#1E88E5');
  final _whatsappCtrl = TextEditingController();
  List<DeliveryZone> _deliveryZones = [];

  bool _loading = true;
  bool _saving = false;
  bool _active = false;
  String? _error;

  StorefrontInfo? _currentInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    _nameCtrl.dispose();
    _logoUrlCtrl.dispose();
    _bannerUrlCtrl.dispose();
    _primaryColorCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final res = await FunctionsService.call('getStorefrontSettings', {'businessId': bizId});
      
      if (res.isNotEmpty && res['tenantSlug'] != null) {
        _currentInfo = StorefrontInfo.fromJson(Map<String, dynamic>.from(res));
        _slugCtrl.text = _currentInfo!.tenantSlug;
        _nameCtrl.text = _currentInfo!.name;
        _active = _currentInfo!.active;
        _logoUrlCtrl.text = _currentInfo!.logoUrl ?? '';
        _bannerUrlCtrl.text = _currentInfo!.bannerUrl ?? '';
        _primaryColorCtrl.text = _currentInfo!.primaryColor ?? '#1E88E5';
        _whatsappCtrl.text = _currentInfo!.whatsappNumber ?? '';
        _deliveryZones = List.from(_currentInfo!.deliveryZones);
      } else {
        // Initialize with default business name
        _nameCtrl.text = context.read<AuthProvider>().userProfile?['businessName'] as String? ?? '';
      }
    } catch (e) {
      _error = 'Failed to load storefront settings: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final slug = _slugCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '-');
      
      // 1. Check Slug Availability if it changed
      if (_currentInfo == null || _currentInfo!.tenantSlug != slug) {
        final checkRes = await FunctionsService.call('checkSlugAvailability', {'slug': slug, 'businessId': bizId});
        if (checkRes['available'] != true) {
          throw Exception('The URL "/store/$slug" is already taken. Please choose another.');
        }
      }

      // 2. Update settings
      await FunctionsService.call('updateStorefrontSettings', {
        'businessId': bizId,
        'name': _nameCtrl.text.trim(),
        'tenantSlug': slug,
        'active': _active,
        'logoUrl': _logoUrlCtrl.text.trim().isEmpty ? null : _logoUrlCtrl.text.trim(),
        'bannerUrl': _bannerUrlCtrl.text.trim().isEmpty ? null : _bannerUrlCtrl.text.trim(),
        'primaryColor': _primaryColorCtrl.text.trim(),
        'whatsappNumber': _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        'deliveryZones': _deliveryZones.map((z) => z.toJson()).toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storefront settings updated successfully!'), backgroundColor: AppColors.success));
        _loadSettings(); // Reload to get fresh state
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openStorefront() {
    if (_currentInfo == null || !_currentInfo!.active) return;
    // Get the base URL
    final String currentUrl = Uri.base.origin;
    final Uri url = Uri.parse('$currentUrl/#/store/${_currentInfo!.tenantSlug}');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Storefront Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error)),
                        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                      ),
                    
                    if (_currentInfo != null && _currentInfo!.active)
                      Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_outlined, color: Colors.white, size: 48),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Your Storefront is LIVE!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Customers can visit: /store/${_currentInfo!.tenantSlug}', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openStorefront,
                              icon: Icon(Icons.open_in_new_rounded, size: 16, color: theme.primaryColor),
                              label: Text('Visit Store', style: TextStyle(color: theme.primaryColor)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Storefront Configuration', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Manage your public-facing B2B/B2C online store.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 32),

                            SwitchListTile(
                              title: const Text('Enable Online Storefront', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Turn this off to temporarily hide your store from the public.'),
                              value: _active,
                              onChanged: (val) => setState(() => _active = val),
                              activeColor: AppColors.accent,
                              contentPadding: EdgeInsets.zero,
                            ),
                            const Divider(height: 48),

                            TextFormField(
                              controller: _nameCtrl,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(
                                labelText: 'Storefront Name',
                                helperText: 'This appears at the top of your public store.',
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 24),

                            TextFormField(
                              controller: _slugCtrl,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(
                                labelText: 'Store URL Slug',
                                prefixText: '/store/',
                                helperText: 'Only lowercase letters, numbers, and hyphens.',
                              ),
                              onChanged: (v) {
                                // Auto-format slug as user types
                                final formatted = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '-');
                                if (formatted != v) {
                                  _slugCtrl.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(offset: formatted.length),
                                  );
                                }
                              },
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length < 3) return 'Must be at least 3 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            const Divider(height: 48),
                            Text('Visual Customization', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _logoUrlCtrl,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(
                                labelText: 'Logo Image URL',
                                helperText: 'Provide a link to your business logo.',
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _bannerUrlCtrl,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(
                                labelText: 'Banner Image URL',
                                helperText: 'Appears at the top of your catalog.',
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _primaryColorCtrl,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(
                                labelText: 'Brand Color (Hex)',
                                helperText: 'e.g. #FF5722',
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _whatsappCtrl,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: const InputDecoration(
                                labelText: 'WhatsApp Number',
                                helperText: 'Include country code, e.g., 254700000000. Leave blank to hide.',
                              ),
                            ),
                            const SizedBox(height: 24),

                            const Divider(height: 48),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Delivery Zones', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Zone'),
                                  onPressed: () {
                                    setState(() {
                                      _deliveryZones.add(DeliveryZone(id: DateTime.now().millisecondsSinceEpoch.toString(), name: 'New Zone', fee: 0));
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_deliveryZones.isEmpty)
                              const Text('No delivery zones added. Storefront will be Click & Collect only.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _deliveryZones.length,
                                itemBuilder: (context, index) {
                                  final zone = _deliveryZones[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            initialValue: zone.name,
                                            decoration: const InputDecoration(labelText: 'Zone Name (e.g. Nairobi CBD)'),
                                            onChanged: (v) => _deliveryZones[index] = DeliveryZone(id: zone.id, name: v, fee: zone.fee),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: zone.fee.toString(),
                                            decoration: const InputDecoration(labelText: 'Fee (KES)'),
                                            keyboardType: TextInputType.number,
                                            onChanged: (v) => _deliveryZones[index] = DeliveryZone(id: zone.id, name: zone.name, fee: double.tryParse(v) ?? 0),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => setState(() => _deliveryZones.removeAt(index)),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 48),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _saving 
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
