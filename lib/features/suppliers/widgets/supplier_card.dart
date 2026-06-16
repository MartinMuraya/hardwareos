import 'package:flutter/material.dart';
import '../../../core/models/supplier.dart';
import '../../../core/theme/app_colors.dart';

class SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  const SupplierCard({required this.supplier, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              child: const Icon(Icons.store_rounded, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(supplier.name,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(supplier.phoneNumber,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ])),
            if (supplier.contactPerson.isNotEmpty)
              Text(supplier.contactPerson,
                style: TextStyle(fontSize: 11, color: theme.hintColor)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor, size: 20),
          ]),
        ),
      ),
    );
  }
}
