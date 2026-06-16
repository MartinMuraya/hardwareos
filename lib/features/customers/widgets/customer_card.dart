import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/customer.dart';
import '../../../core/theme/app_colors.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  const CustomerCard({required this.customer, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');
    final hasBalance = customer.currentBalance > 0;

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasBalance ? AppColors.warning.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_rounded,
                color: hasBalance ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer.fullName,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(customer.phoneNumber,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(customer.currentBalance > 0 ? fmt.format(customer.currentBalance) : 'KES 0',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: customer.currentBalance > 0
                      ? (customer.isOverLimit ? AppColors.error : AppColors.warning)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (customer.isOverLimit)
                const Text('Over limit',
                  style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor, size: 20),
          ]),
        ),
      ),
    );
  }
}
