import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/empty_state.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final List<Sale> _sales = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _lastDocId;
  bool _hasMore = true;

  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales({bool refresh = false}) async {
    if (refresh) {
      setState(() { _loading = true; _error = null; _lastDocId = null; _hasMore = true; _sales.clear(); });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() { _loadingMore = true; _error = null; });
    }

    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getSales', {
        'businessId': bizId,
        'limit': 30,
        if (_lastDocId != null) 'startAfter': _lastDocId,
      });

      final rawList = (data['sales'] as List?) ?? [];
      final newSales = rawList.map((e) => Sale.fromMap(Map<String, dynamic>.from(e as Map))).toList();

      if (mounted) {
        setState(() {
          if (newSales.isNotEmpty) {
            _sales.addAll(newSales);
            _lastDocId = newSales.last.id;
          }
          _hasMore = newSales.length == 30;
          _loading = false;
          _loadingMore = false;
        });
      }
    } on FunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _loading && _sales.isEmpty,
        message: 'Loading sales...',
        child: _error != null && _sales.isEmpty
            ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
            : _sales.isEmpty && !_loading
                ? const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No sales yet',
                    subtitle: 'Sales you make in the POS will appear here.',
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadSales(refresh: true),
                    color: AppColors.accent,
                    backgroundColor: AppColors.card,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _sales.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == _sales.length) {
                          _loadSales(); // Fetch next page
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                          );
                        }
                        final sale = _sales[i];
                        return _SaleCard(sale: sale, fmt: _fmt);
                      },
                    ),
                  ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;
  final NumberFormat fmt;

  const _SaleCard({required this.sale, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d, y • h:mm a').format(sale.createdAt),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              _PaymentChip(method: sale.paymentMethod),
            ],
          ),
          const SizedBox(height: 12),
          ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.quantity}x ${item.name}', style: const TextStyle(fontSize: 14)),
                    Text(fmt.format(item.lineTotal), style: const TextStyle(fontSize: 14)),
                  ],
                ),
              )),
          const Divider(height: 24, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              Text(fmt.format(sale.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profit', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(fmt.format(sale.profit), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String method;
  const _PaymentChip({required this.method});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (method) {
      case 'mpesa':  color = AppColors.success; break;
      case 'credit': color = AppColors.warning; break;
      default:       color = AppColors.chartBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(method.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
