import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class POStatusBadge extends StatelessWidget {
  final String status;
  const POStatusBadge({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (status) {
      'draft' => (AppColors.info, Icons.edit_note_rounded),
      'sent' => (AppColors.accent, Icons.send_rounded),
      'received' => (AppColors.success, Icons.check_circle_rounded),
      'cancelled' => (AppColors.error, Icons.cancel_rounded),
      _ => (Theme.of(context).colorScheme.onSurfaceVariant, Icons.help_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(_label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  String get _label {
    switch (status) {
      case 'draft': return 'Draft';
      case 'sent': return 'Sent';
      case 'received': return 'Received';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }
}
