import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/expense.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/empty_state.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final List<Expense> _expenses = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _lastDocId;
  bool _hasMore = true;

  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses({bool refresh = false}) async {
    if (refresh) {
      setState(() { _loading = true; _error = null; _lastDocId = null; _hasMore = true; _expenses.clear(); });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() { _loadingMore = true; _error = null; });
    }

    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getExpenses', {
        'businessId': bizId,
        'limit': 30,
        if (_lastDocId != null) 'startAfter': _lastDocId,
      });

      final rawList = data is List ? data : (data['result'] ?? data['expenses'] ?? []);
      final newExpenses = (rawList as List).map((e) => Expense.fromMap(Map<String, dynamic>.from(e as Map))).toList();

      if (mounted) {
        setState(() {
          if (newExpenses.isNotEmpty) {
            _expenses.addAll(newExpenses);
            _lastDocId = newExpenses.last.id;
          }
          _hasMore = newExpenses.length == 30;
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
      body: LoadingOverlay(
        isLoading: _loading && _expenses.isEmpty,
        message: 'Loading expenses...',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expenses', style: AppTheme.darkTheme.textTheme.displayMedium),
                        const SizedBox(height: 4),
                        const Text('Track and manage business expenses', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await context.push('/expenses/add');
                      _loadExpenses(refresh: true);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Expense'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.chartRed, foregroundColor: AppColors.background),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_error != null && _expenses.isEmpty)
                Center(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
              Expanded(
                child: _expenses.isEmpty && !_loading
                    ? EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No expenses recorded',
                        subtitle: 'Click "Add Expense" to start tracking your spending.',
                        actionLabel: 'Add Expense',
                        onAction: () async {
                          await context.push('/expenses/add');
                          _loadExpenses(refresh: true);
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadExpenses(refresh: true),
                        color: AppColors.accent,
                        backgroundColor: AppColors.card,
                        child: ListView.separated(
                          itemCount: _expenses.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            if (i == _expenses.length) {
                              _loadExpenses();
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                              );
                            }
                            final exp = _expenses[i];
                            return _ExpenseCard(expense: exp, fmt: _fmt);
                          },
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

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final NumberFormat fmt;

  const _ExpenseCard({required this.expense, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.chartRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.chartRed, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                if (expense.note.isNotEmpty)
                  Text(expense.note, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(DateFormat('MMM d, y • h:mm a').format(expense.createdAt), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
              ],
            ),
          ),
          Text(fmt.format(expense.amount), style: const TextStyle(color: AppColors.chartRed, fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }
}
