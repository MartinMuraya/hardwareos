import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class PlanStatusBanner extends StatelessWidget {
  final Map subscription;
  const PlanStatusBanner({super.key, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final plan          = subscription['plan'] as String? ?? 'free';
    final status        = subscription['status'] as String? ?? 'trial';
    final trialDaysLeft = subscription['trialDaysLeft'] as int?;
    final isExpired     = subscription['isExpired'] == true;

    if (isExpired) {
      return _BannerCard(
        icon: Icons.warning_amber_rounded,
        bgColor: AppColors.error.withValues(alpha: 0.1),
        borderColor: AppColors.error.withValues(alpha: 0.3),
        iconColor: AppColors.error,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Subscription Expired',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              const Text('Renew your plan to continue using all features.',
                style: TextStyle(color: AppColors.error, fontSize: 12)),
            ]),
          ),
          FilledButton(
            onPressed: () => GoRouter.of(context).go('/subscription'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Renew Now', style: TextStyle(fontSize: 12)),
          ),
        ]),
      );
    }

    if (status == 'trial' && trialDaysLeft != null) {
      final urgent = trialDaysLeft <= 3;
      return _BannerCard(
        icon: Icons.access_time_rounded,
        bgColor: (urgent ? AppColors.warning : AppColors.accent).withValues(alpha: 0.08),
        borderColor: (urgent ? AppColors.warning : AppColors.accent).withValues(alpha: 0.25),
        iconColor: urgent ? AppColors.warning : AppColors.accent,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                urgent ? '⚠️ Trial ending soon!' : '🎉 Free Trial Active',
                style: TextStyle(
                  color: urgent ? AppColors.warning : AppColors.accent,
                  fontWeight: FontWeight.w700, fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text('$trialDaysLeft days remaining on your trial.',
                style: TextStyle(
                  color: urgent ? AppColors.warning : AppColors.textSecondary, fontSize: 12,
                )),
            ]),
          ),
          OutlinedButton(
            onPressed: () => GoRouter.of(context).go('/subscription'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
          ),
        ]),
      );
    }

    if (status == 'active') {
      return _BannerCard(
        icon: Icons.verified_rounded,
        bgColor: AppColors.success.withValues(alpha: 0.07),
        borderColor: AppColors.success.withValues(alpha: 0.2),
        iconColor: AppColors.success,
        child: Row(children: [
          Expanded(
            child: Text('${_planLabel(plan)} Plan — Active',
              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          OutlinedButton(
            onPressed: () => GoRouter.of(context).go('/subscription'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Manage', style: TextStyle(fontSize: 12)),
          ),
        ]),
      );
    }

    return const SizedBox.shrink();
  }

  String _planLabel(String plan) => switch (plan) {
    'starter' => 'Starter',
    'pro'     => 'Pro',
    _         => 'Free',
  };
}

class _BannerCard extends StatelessWidget {
  final IconData icon;
  final Color bgColor, borderColor, iconColor;
  final Widget child;
  const _BannerCard({
    required this.icon, required this.bgColor,
    required this.borderColor, required this.iconColor, required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(child: child),
      ]),
    );
  }
}
