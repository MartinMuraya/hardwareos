import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class AdminScaffold extends StatelessWidget {
  final Widget child;
  const AdminScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: AppColors.surface,
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo/Brand
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hardware_rounded, color: AppColors.accent, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'AdminOS',
                      style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                
                // Nav Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _NavItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Overview',
                        isSelected: location == '/admin' || location == '/admin/dashboard',
                        onTap: () => context.go('/admin/dashboard'),
                      ),
                      _NavItem(
                        icon: Icons.store_rounded,
                        label: 'Businesses',
                        isSelected: location.startsWith('/admin/businesses'),
                        onTap: () => context.go('/admin/businesses'),
                      ),
                      _NavItem(
                        icon: Icons.card_membership_rounded,
                        label: 'Subscriptions',
                        isSelected: location.startsWith('/admin/subscriptions'),
                        onTap: () => context.go('/admin/subscriptions'),
                      ),
                      _NavItem(
                        icon: Icons.people_rounded,
                        label: 'Users',
                        isSelected: location.startsWith('/admin/users'),
                        onTap: () => context.go('/admin/users'),
                      ),
                      _NavItem(
                        icon: Icons.view_list_rounded,
                        label: 'Plans',
                        isSelected: location.startsWith('/admin/plans'),
                        onTap: () => context.go('/admin/plans'),
                      ),
                      _NavItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isSelected: location.startsWith('/admin/settings'),
                        onTap: () => context.go('/admin/settings'),
                      ),
                    ],
                  ),
                ),
                
                // User Profile & Logout
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accent,
                        child: Icon(Icons.shield_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Super Admin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('Platform Control', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => context.read<AuthProvider>().signOut(),
                        tooltip: 'Sign Out',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          
          // Main Content
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.surfaceLight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
