import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/customer_card.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _lastDocId;
  bool _hasMore = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_filter); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) { setState(() { _loading = true; _error = null; _lastDocId = null; _hasMore = true; }); }
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getCustomers', {
        'businessId': bizId,
        'limit': 50,
        if (_lastDocId != null && !refresh) 'startAfter': _lastDocId,
      });
      final rawList = (data['customers'] as List?) ?? [];
      final items = rawList.map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) {
        setState(() {
          if (refresh || _lastDocId == null) {
            _customers = items;
          } else {
            _customers.addAll(items);
          }
          _filtered = _customers;
          _loading = false;
          _loadingMore = false;
          _hasMore = items.length >= 50;
          if (items.isNotEmpty) _lastDocId = items.last.id;
        });
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; _loadingMore = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _customers
          : _customers.where((c) =>
              c.fullName.toLowerCase().contains(q) || c.phoneNumber.contains(q)).toList();
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
                Text('Customers', style: theme.textTheme.displayMedium),
                const SizedBox(height: 4),
                Text('Manage customer accounts and credit',
                  style: theme.textTheme.bodyMedium),
              ])),
              FilledButton.icon(
                onPressed: () async {
                  final result = await context.push('/customers/add');
                  if (result == true) _load(refresh: true);
                },
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add Customer'),
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
            if (_error != null && _customers.isEmpty)
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
              child: _loading && _customers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty && !_loading
                      ? EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No customers yet',
                          subtitle: 'Add your first customer to start tracking credit sales.',
                          actionLabel: 'Add Customer',
                          onAction: () async {
                            final result = await context.push('/customers/add');
                            if (result == true) _load(refresh: true);
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(refresh: true),
                          child: ListView.builder(
                            itemCount: _filtered.length + (_hasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _filtered.length) {
                                if (!_loadingMore) {
                                  _loadingMore = true;
                                  _load();
                                }
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final c = _filtered[i];
                              return CustomerCard(
                                customer: c,
                                onTap: () => context.push('/customers/${c.id}'),
                              );
                            },
                          ),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
