import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';

class RecentSalesList extends StatelessWidget {
  final List<Map<String, dynamic>> sales;
  final NumberFormat fmt;
  const RecentSalesList({super.key, required this.sales, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: sales.asMap().entries.map((entry) {
          final i = entry.key;
          final sale = entry.value;
          final total = (sale['total'] as num).toDouble();
          final profit = (sale['profit'] as num).toDouble();
          final method = sale['paymentMethod'] as String? ?? 'cash';
          final createdAt = DateTime.tryParse(sale['createdAt']?.toString() ?? '') ?? DateTime.now();

          return Column(children: [
            if (i > 0) const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_rounded, color: AppColors.accent, size: 18),
              ),
              title: Text(fmt.format(total),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Row(children: [
                _PaymentChip(method: method),
                const SizedBox(width: 8),
                Text(DateFormat('h:mm a').format(createdAt),
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
              ]),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+${fmt.format(profit)}',
                    style: const TextStyle(color: AppColors.success,
                      fontWeight: FontWeight.w600, fontSize: 13)),
                  const Text('profit',
                    style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                ],
              ),
            ),
          ]);
        }).toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(method.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
