import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/debt_transaction.dart';
import '../../../core/theme/app_colors.dart';

class DebtTxTile extends StatelessWidget {
  final DebtTransaction transaction;
  final NumberFormat fmt;
  final ThemeData theme;
  const DebtTxTile({required this.transaction, required this.fmt, required this.theme, super.key});

  @override
  Widget build(BuildContext context) {
    final isIncrease = transaction.isIncrease;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (isIncrease ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: isIncrease ? AppColors.warning : AppColors.success,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(transaction.typeLabel,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: theme.colorScheme.onSurface)),
          if (transaction.note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(transaction.note,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isIncrease ? '' : ''}${fmt.format(transaction.amount.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13,
              color: isIncrease ? AppColors.warning : AppColors.success,
            ),
          ),
          Text(fmt.format(transaction.newBalance),
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}
