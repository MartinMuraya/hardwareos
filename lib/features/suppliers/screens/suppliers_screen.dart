import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/supplier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/supplier_card.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> _suppliers = [];
  List<Supplier> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_filter); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getSuppliers', {'businessId': bizId, 'limit': 100});
      final rawList = (data['suppliers'] as List?) ?? [];
      final items = rawList.map((e) => Supplier.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _suppliers = items; _filtered = items; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _suppliers
          : _suppliers.where((s) => s.name.toLowerCase().contains(q) || s.phoneNumber.contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Suppliers', style: theme.textTheme.displayMedium),
                const SizedBox(height: 4),
                Text('Manage vendors and purchase orders',
                  style: theme.textTheme.bodyMedium),
              ])),
              FilledButton.icon(
                onPressed: () async {
                  final result = await context.push('/suppliers/add');
                  if (result == true) _load();
                },
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Add Supplier'),
              ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); _filter(); })
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null && _suppliers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
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
            Expanded(
              child: _loading && _suppliers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty && !_loading
                      ? EmptyState(
                          icon: Icons.store_outlined,
                          title: 'No suppliers yet',
                          subtitle: 'Add your first supplier to start tracking purchases.',
                          actionLabel: 'Add Supplier',
                          onAction: () async {
                            final result = await context.push('/suppliers/add');
                            if (result == true) _load();
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => SupplierCard(
                              supplier: _filtered[i],
                              onTap: () => context.push('/suppliers/${_filtered[i].id}'),
                            ),
                          ),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
