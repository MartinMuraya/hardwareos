import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PlanCard extends StatelessWidget {
  final String planId;
  final String name;
  final String price;
  final String billing;
  final List<String> features;
  final bool isSelected;
  final VoidCallback onSelect;

  const PlanCard({
    required this.planId,
    required this.name,
    required this.price,
    required this.billing,
    required this.features,
    required this.isSelected,
    required this.onSelect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent),
                  ),
                  TextSpan(
                    text: billing,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .take(3)
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(f.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            if (features.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+ ${features.length - 3} more', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}
