import 'package:flutter/material.dart';
import '../../../core/services/plan_seeder.dart';
import '../../../core/theme/app_colors.dart';

class PlanSeederDialog extends StatefulWidget {
  const PlanSeederDialog({super.key});

  @override
  State<PlanSeederDialog> createState() => _PlanSeederDialogState();
}

class _PlanSeederDialogState extends State<PlanSeederDialog> {
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;
  int? _planCount;

  @override
  void initState() {
    super.initState();
    _checkPlans();
  }

  Future<void> _checkPlans() async {
    final count = await PlanSeeder.getPlanCount();
    setState(() => _planCount = count);
  }

  Future<void> _seedPlans() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _isSuccess = false;
    });

    final success = await PlanSeeder.seedPlans();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = success;
        _message = success
            ? 'Plans seeded successfully! Standard and Pro plans are ready.'
            : 'Failed to seed plans. Check console for details.';
      });

      if (success) {
        await _checkPlans();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansExist = _planCount != null && _planCount! > 0;

    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: const Text('Initialize Plans'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_planCount != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    plansExist ? Icons.check_circle_rounded : Icons.info_rounded,
                    color: plansExist ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    plansExist
                        ? '$_planCount plans already exist'
                        : 'No plans found in database',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_isSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 12,
                  color: _isSuccess ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plans to be created:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Standard: KES 2,600/month (3 users)',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  '• Pro: KES 5,200/month (unlimited users)',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  '• Trial: Free 14-day trial',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!plansExist)
          FilledButton(
            onPressed: _isLoading ? null : _seedPlans,
            child: _isLoading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Seed Plans'),
          ),
      ],
    );
  }
}

/// Show the plan seeder dialog
void showPlanSeederDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const PlanSeederDialog(),
  );
}
