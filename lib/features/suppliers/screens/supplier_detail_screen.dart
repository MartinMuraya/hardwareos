import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/supplier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;
  const SupplierDetailScreen({required this.supplierId, super.key});
  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  Supplier? _supplier;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getSupplier', {
        'businessId': bizId, 'supplierId': widget.supplierId,
      });
      final s = Supplier.fromMap(Map<String, dynamic>.from(data['supplier'] as Map));
      if (mounted) setState(() { _supplier = s; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() { _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(_supplier?.name ?? 'Supplier')),
        body: _supplier == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.padding(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.store_rounded, color: AppColors.accent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_supplier!.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(_supplier!.phoneNumber, style: theme.textTheme.bodyMedium),
                        ])),
                      ]),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'Email', value: _supplier!.email.isNotEmpty ? _supplier!.email : '—', theme: theme),
                      _InfoRow(label: 'Address', value: _supplier!.address.isNotEmpty ? _supplier!.address : '—', theme: theme),
                      _InfoRow(label: 'Contact Person', value: _supplier!.contactPerson.isNotEmpty ? _supplier!.contactPerson : '—', theme: theme),
                      _InfoRow(label: 'Payment Terms', value: _supplier!.paymentTerms, theme: theme),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Quick actions
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/purchase-orders/add?supplierId=${_supplier!.id}&supplierName=${Uri.encodeComponent(_supplier!.name)}'),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: const Text('Create Purchase Order'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/purchase-orders'),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('View Purchase Orders'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final ThemeData theme;
  const _InfoRow({required this.label, required this.value, required this.theme});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13))),
      Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: theme.colorScheme.onSurface))),
    ]),
  );
}
