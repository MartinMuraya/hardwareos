import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/business_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatefulWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded,    label: 'Dashboard', route: '/dashboard'),
    _NavItem(icon: Icons.inventory_2_rounded,  label: 'Inventory', route: '/inventory'),
    _NavItem(icon: Icons.point_of_sale_rounded,label: 'Sales',     route: '/sales'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Expenses',  route: '/expenses'),
    _NavItem(icon: Icons.bar_chart_rounded,    label: 'Reports',   route: '/reports'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isWide     = MediaQuery.of(context).size.width >= 800;
    final selectedIdx = _selectedIndex(context);
    final auth       = context.watch<AuthProvider>();
    final biz        = context.watch<BusinessProvider>();

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _SideNav(
              selectedIndex: selectedIdx,
              navItems: _navItems,
              businessName: biz.businessName ?? 'HardwareOS',
              userRole:     auth.userRole ?? 'staff',
              plan:         biz.plan ?? 'free',
              onSignOut:    () => auth.signOut(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // Mobile — bottom nav
    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: selectedIdx,
        onDestinationSelected: (i) => context.go(_navItems[i].route),
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon:          Icon(item.icon),
                  selectedIcon:  Icon(item.icon, color: AppColors.accent),
                  label:         item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final String businessName;
  final String userRole;
  final String plan;
  final VoidCallback onSignOut;

  const _SideNav({
    required this.selectedIndex,
    required this.navItems,
    required this.businessName,
    required this.userRole,
    required this.plan,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hardware_rounded, color: AppColors.background, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('HardwareOS',
                      style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(businessName,
                  style: AppTheme.darkTheme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(children: [
                  _PlanBadge(plan: plan),
                  const SizedBox(width: 8),
                  _RoleBadge(role: userRole),
                ]),
              ],
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item     = navItems[i];
                final selected = selectedIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: selected
                        ? AppColors.accent.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.go(item.route),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Row(children: [
                          Icon(item.icon,
                            size: 20,
                            color: selected ? AppColors.accent : AppColors.textHint,
                          ),
                          const SizedBox(width: 12),
                          Text(item.label,
                            style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                              color: selected ? AppColors.accent : AppColors.textSecondary,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          if (selected) ...[
                            const Spacer(),
                            Container(
                              width: 4, height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Sign out
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onSignOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(children: [
                    const Icon(Icons.logout_rounded, size: 20, color: AppColors.textHint),
                    const SizedBox(width: 12),
                    Text('Sign Out',
                      style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (plan) {
      case 'pro':     color = AppColors.planPro;     break;
      case 'starter': color = AppColors.planStarter; break;
      default:        color = AppColors.planFree;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(plan.toUpperCase(),
        style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(role,
        style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}
