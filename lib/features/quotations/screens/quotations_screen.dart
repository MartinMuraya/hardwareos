import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/quotation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/quotation_card.dart';

class QuotationsScreen extends StatefulWidget {
  final String? filterStatus;
  const QuotationsScreen({this.filterStatus, super.key});
  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  List<Quotation> _quotations = [];
  List<Quotation> _filtered = [];
  bool _loading = true;
  String? _error;
  String _tabFilter = 'all';

  static const _tabs = ['all', 'draft', 'sent', 'accepted', 'rejected'];

  @override
  void initState() { super.initState(); _tabFilter = widget.filterStatus ?? 'all'; _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getQuotations', {'businessId': bizId, 'limit': 100});
      final rawList = (data['quotations'] as List?) ?? [];
      final items = rawList.map((e) => Quotation.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _quotations = items; _filtered = items; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _applyFilter(String tab) {
    setState(() {
      _tabFilter = tab;
      if (tab == 'all') {
        _filtered = _quotations;
      } else {
        _filtered = _quotations.where((q) => q.status == tab).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/quotations/add');
          if (result == true) _load();
        },
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Quotation', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quotations', style: theme.textTheme.displayMedium),
            const SizedBox(height: 4),
            Text('Create and manage proforma invoices',
              style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),

            // Filter chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final tab = _tabs[i];
                  final sel = _tabFilter == tab;
                  return FilterChip(
                    label: Text(tab == 'all' ? 'All' : tab[0].toUpperCase() + tab.substring(1),
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? AppColors.accent : theme.colorScheme.onSurfaceVariant,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => _applyFilter(tab),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.cardColor,
                    selectedColor: AppColors.accent.withValues(alpha: 0.12),
                    side: BorderSide(color: sel ? AppColors.accent : theme.dividerColor),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.description_outlined,
                          title: _tabFilter == 'all' ? 'No quotations yet' : 'No $_tabFilter quotations',
                          subtitle: _tabFilter == 'all'
                              ? 'Create your first quotation to get started.'
                              : 'No quotations match this status.',
                          actionLabel: 'New Quotation',
                          onAction: () async {
                            final result = await context.push('/quotations/add');
                            if (result == true) _load();
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => QuotationCard(
                              quotation: _filtered[i],
                              onTap: () => context.push('/quotations/${_filtered[i].id}'),
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
