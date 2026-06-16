import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LowStockList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const LowStockList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final qty = (item['quantity'] as num).toInt();
          final reorder = (item['reorderLevel'] as num).toInt();
          final isOut = qty <= 0;
          final color = isOut ? AppColors.stockCritical : AppColors.stockLow;

          return Column(
            children: [
              if (i > 0) Divider(height: 1, color: theme.dividerColor),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOut ? Icons.remove_circle_outline : Icons.warning_amber_rounded,
                    color: color, size: 18,
                  ),
                ),
                title: Text(item['name'] as String,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14,
                    color: theme.colorScheme.onSurface)),
                subtitle: Text(item['category'] as String? ?? '',
                  style: TextStyle(color: theme.hintColor, fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isOut ? 'OUT' : 'Qty: $qty',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 2),
                    Text('Reorder: $reorder',
                      style: TextStyle(color: theme.hintColor, fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
