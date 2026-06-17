import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  List<Product> _all = [];
  List<Product> _filtered = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getProducts', {'businessId': bizId, 'limit': 100});
      final rawList = (data['products'] as List?) ?? [];
      final prods = rawList
          .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      final cats = <String>{'All', ...prods.map((p) => p.category)}.toList()..sort();
      if (mounted) {
        setState(() {
          _all = prods; _filtered = prods;
          _categories = cats; _loading = false;
        });
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        final matchCat = _selectedCategory == 'All' || p.category == _selectedCategory;
        final matchQ   = q.isEmpty || p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q);
        return matchCat && matchQ;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowCount = _all.where((p) => p.isLowStock || p.isOutOfStock).length;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
    final padding = Responsive.padding(context);

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading inventory...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Inventory', style: theme.textTheme.displayMedium),
                    const SizedBox(height: 4),
                    Text('${_all.length} products${lowCount > 0 ? ' · $lowCount low stock' : ''}',
                      style: theme.textTheme.bodyMedium),
                  ]),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await context.push('/inventory/add');
                    _load();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Product'),
                ),
              ]),
              const SizedBox(height: 20),

              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or SKU...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _CategoryFilter(
                  categories: _categories,
                  selected: _selectedCategory,
                  onChanged: (c) { setState(() => _selectedCategory = c); _filter(); },
                  theme: theme,
                ),
              ]),
              const SizedBox(height: 16),

              if (_error != null)
                _ErrorBar(message: _error!, onRetry: _load, theme: theme),

              Expanded(
                child: _filtered.isEmpty && !_loading
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: _all.isEmpty ? 'No products yet' : 'No results found',
                        subtitle: _all.isEmpty
                            ? 'Add your first product to start tracking inventory.'
                            : 'Try a different search or category.',
                        actionLabel: _all.isEmpty ? 'Add Product' : null,
                        onAction: _all.isEmpty ? () => context.go('/inventory/add') : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        backgroundColor: theme.cardColor,
                        child: isWide 
                          ? GridView.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 100,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _ProductCard(
                                product: _filtered[i],
                                theme: theme,
                                onTap: () async {
                                  await context.push('/inventory/${_filtered[i].id}');
                                  _load();
                                },
                              ),
                            )
                          : ListView.separated(
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _ProductCard(
                                product: _filtered[i],
                                theme: theme,
                                onTap: () async {
                                  await context.push('/inventory/${_filtered[i].id}');
                                  _load();
                                },
                              ),
                            ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final ThemeData theme;
  const _ProductCard({required this.product, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    Color stockColor;
    String stockLabel;
    if (product.isOutOfStock) { stockColor = AppColors.stockCritical; stockLabel = 'OUT'; }
    else if (product.isLowStock) { stockColor = AppColors.stockLow; stockLabel = 'LOW'; }
    else { stockColor = AppColors.stockGood; stockLabel = '${product.quantity}'; }

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: product.isBulkChild
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : product.isBulkParent
                      ? AppColors.chartPurple.withValues(alpha: 0.1)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  product.isBulkChild ? Icons.content_copy_rounded
                    : product.isBulkParent ? Icons.inventory_rounded
                    : Icons.hardware_rounded,
                  color: product.isBulkChild
                    ? AppColors.warning
                    : product.isBulkParent
                      ? AppColors.chartPurple
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, 
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Text(product.name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                    color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  _Chip(label: product.category, color: AppColors.chartBlue),
                  if (product.sku.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Chip(label: product.sku, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ],
                  if (product.isBulkParent || product.isBulkChild) ...[
                    const SizedBox(width: 6),
                    _Chip(
                      label: product.isBulkParent ? 'BULK' : 'Sub-unit',
                      color: product.isBulkParent ? AppColors.chartPurple : AppColors.warning,
                    ),
                  ],
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, 
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(stockLabel,
                  style: TextStyle(color: stockColor, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(height: 6),
              Text('KES ${product.sellingPrice.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
  );
}

class _CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;
  final ThemeData theme;
  const _CategoryFilter({required this.categories, required this.selected, required this.onChanged, required this.theme});
  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        dropdownColor: theme.cardColor,
        style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13),
        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  final ThemeData theme;
  const _ErrorBar({required this.message, required this.onRetry, required this.theme});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
