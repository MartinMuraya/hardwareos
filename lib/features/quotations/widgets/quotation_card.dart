import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/quotation.dart';
import '../../../core/theme/app_colors.dart';
import 'quotation_status_badge.dart';

class QuotationCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;
  const QuotationCard({required this.quotation, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

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
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_rounded, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(quotation.quotationNumber,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 3),
              Text(quotation.customerName,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(quotation.total),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 4),
              QuotationStatusBadge(status: quotation.status),
            ]),
          ]),
        ),
      ),
    );
  }
}
