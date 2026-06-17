import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/business_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

class AppScaffold extends StatefulWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded,    label: 'Dashboard',     route: '/dashboard'),
    _NavItem(icon: Icons.inventory_2_rounded,  label: 'Inventory',     route: '/inventory'),
    _NavItem(icon: Icons.point_of_sale_rounded,label: 'Sales',         route: '/sales'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Expenses',      route: '/expenses'),
    _NavItem(icon: Icons.people_rounded,       label: 'Customers',     route: '/customers'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Credit', route: '/credit-ledger'),
    _NavItem(icon: Icons.description_rounded,  label: 'Quotations',    route: '/quotations'),
    _NavItem(icon: Icons.store_rounded,        label: 'Suppliers',     route: '/suppliers'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Purchases',     route: '/purchase-orders'),
    _NavItem(icon: Icons.bar_chart_rounded,    label: 'Reports',       route: '/reports'),
    _NavItem(icon: Icons.people_rounded,       label: 'Team',          route: '/team'),
    _NavItem(icon: Icons.workspace_premium_rounded, label: 'Subscription', route: '/subscription'),
    _NavItem(icon: Icons.balance_rounded,       label: 'Stock Adj.',    route: '/stock-adjustments'),
    _NavItem(icon: Icons.history_rounded,       label: 'Audit Trail',   route: '/audit-logs'),
    _NavItem(icon: Icons.replay_rounded,        label: 'Returns',       route: '/returns'),
    _NavItem(icon: Icons.monetization_on_rounded, label: 'Cash Drawer', route: '/cash-drawer'),
    _NavItem(icon: Icons.business_rounded,       label: 'Branches',     route: '/branches'),
    _NavItem(icon: Icons.swap_horiz_rounded,     label: 'Transfers',    route: '/stock-transfers'),
  ];

  // Primary items shown in bottom nav (mobile)
  static const _primaryNav = [
    _NavItem(icon: Icons.dashboard_rounded,    label: 'Dashboard',     route: '/dashboard'),
    _NavItem(icon: Icons.point_of_sale_rounded,label: 'Sales',         route: '/sales'),
    _NavItem(icon: Icons.inventory_2_rounded,  label: 'Inventory',     route: '/inventory'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Expenses',      route: '/expenses'),
  ];

  // Items shown in the "More" bottom sheet (mobile)
  List<_NavItem> get _moreItems => _navItems.where(
    (item) => !_primaryNav.any((p) => p.route == item.route)
  ).toList();

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }

  int _mobileNavIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _primaryNav.length; i++) {
      if (location.startsWith(_primaryNav[i].route)) return i;
    }
    return _primaryNav.length;
  }

  void _openMoreSheet(BuildContext context) {
    final selectedIdx = _selectedIndex(context);
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSheetSection(ctx, 'Customers & Credit', _moreItems.where(
                    (i) => i.route == '/customers' || i.route == '/credit-ledger'
                  ).toList(), selectedIdx),
                  const SizedBox(height: 8),
                  _buildSheetSection(ctx, 'Orders & Documents', _moreItems.where(
                    (i) => i.route == '/quotations' || i.route == '/suppliers' || i.route == '/purchase-orders'
                  ).toList(), selectedIdx),
                  const SizedBox(height: 8),
                  _buildSheetSection(ctx, 'Analytics & Admin', _moreItems.where(
                    (i) => i.route == '/reports' || i.route == '/team' || i.route == '/subscription'
                  ).toList(), selectedIdx),
                  const SizedBox(height: 8),
                  _buildSheetSection(ctx, 'Operations', _moreItems.where(
                    (i) => i.route == '/stock-adjustments' || i.route == '/returns' || i.route == '/audit-logs' || i.route == '/cash-drawer'
                  ).toList(), selectedIdx),
                  const SizedBox(height: 8),
                  _buildSheetSection(ctx, 'Multi-Branch', _moreItems.where(
                    (i) => i.route == '/branches' || i.route == '/stock-transfers'
                  ).toList(), selectedIdx),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetSection(BuildContext context, String title, List<_NavItem> items, int selectedIdx) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...items.map((item) {
          final idx = _navItems.indexOf(item);
          final selected = selectedIdx == idx;
          return ListTile(
            leading: Icon(item.icon, color: selected ? AppColors.accent : null),
            title: Text(item.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.accent : null,
              ),
            ),
            trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.accent, size: 18) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              Navigator.pop(context);
              context.go(item.route);
            },
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final selectedIdx = _selectedIndex(context);
    final auth = context.watch<AuthProvider>();
    final biz = context.watch<BusinessProvider>();
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);

    final connectivity = context.watch<ConnectivityProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: !isDesktop ? Drawer(
        child: _SideNav(
          selectedIndex: selectedIdx,
          navItems: _navItems,
          businessName: biz.businessName ?? 'HardwareOS',
          userRole: auth.userRole ?? 'staff',
          plan: biz.plan ?? 'free',
          subscriptionStatus: biz.subscriptionStatus ?? 'trial',
          onSignOut: () => auth.signOut(),
          isDrawer: true,
        ),
      ) : null,
      appBar: !isDesktop ? AppBar(
        title: Text(_navItems[selectedIdx].label),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
          ),
          const SizedBox(width: 8),
        ],
      ) : null,
      body: Column(
        children: [
          if (connectivity.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Offline Mode — sales will sync when connection restores',
                    style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Expanded(child: Row(
        children: [
          if (isDesktop)
            _SideNav(
              selectedIndex: selectedIdx,
              navItems: _navItems,
              businessName: biz.businessName ?? 'HardwareOS',
              userRole: auth.userRole ?? 'staff',
              plan: biz.plan ?? 'free',
              subscriptionStatus: biz.subscriptionStatus ?? 'trial',
              onSignOut: () => auth.signOut(),
            ),
          if (Responsive.isTablet(context))
            NavigationRail(
              extended: false,
              selectedIndex: selectedIdx,
              onDestinationSelected: (i) => context.go(_navItems[i].route),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hardware_rounded, color: Colors.white, size: 20),
                ),
              ),
              trailing: Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                      onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
                    ),
                    const SizedBox(height: 12),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => auth.signOut(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              destinations: _navItems.map((item) => NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.icon, color: AppColors.accent),
                label: Text(item.label),
              )).toList(),
            ),
          if (isDesktop || Responsive.isTablet(context)) const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      )),
        ],
      ),
      bottomNavigationBar: isMobile ? SizedBox(
        height: 80,
        child: NavigationBar(
          selectedIndex: _mobileNavIndex(context),
          onDestinationSelected: (i) {
            if (i < _primaryNav.length) {
              context.go(_primaryNav[i].route);
            } else {
              _openMoreSheet(context);
            }
          },
          height: 80,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            ..._primaryNav.map((item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon, color: AppColors.accent),
              label: item.label,
            )),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(Icons.more_horiz_rounded, color: AppColors.accent),
              label: 'More',
            ),
          ],
        ),
      ) : null,
    );
  }
}

class _SideNav extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final String businessName;
  final String userRole;
  final String plan;
  final String subscriptionStatus;
  final VoidCallback onSignOut;
  final bool isDrawer;

  const _SideNav({
    required this.selectedIndex,
    required this.navItems,
    required this.businessName,
    required this.userRole,
    required this.plan,
    required this.subscriptionStatus,
    required this.onSignOut,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      width: 260,
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Container(
            padding: EdgeInsets.fromLTRB(20, isDrawer ? 32 : 48, 20, 24),
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
                    child: const Icon(Icons.hardware_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('HardwareOS',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isDrawer)
                    IconButton(
                      icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                      onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
                const SizedBox(height: 12),
                Text(businessName,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
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
                final isSubscriptionItem = item.route == '/subscription';
                final needsUpgrade = isSubscriptionItem &&
                    (subscriptionStatus == 'trial' || subscriptionStatus == 'expired');
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: selected,
                    leading: Icon(item.icon, 
                      color: needsUpgrade ? AppColors.warning : (selected ? AppColors.accent : null)
                    ),
                    title: Text(item.label,
                      style: TextStyle(
                        color: needsUpgrade ? AppColors.warning : (selected ? AppColors.accent : null),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    trailing: needsUpgrade ? _UpgradeBadge(status: subscriptionStatus) : null,
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      context.go(item.route);
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    selectedTileColor: AppColors.accent.withValues(alpha: 0.1),
                    dense: true,
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Sign out
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign Out'),
            onTap: onSignOut,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _UpgradeBadge extends StatelessWidget {
  final String status;
  const _UpgradeBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Text(
        status == 'expired' ? 'EXPIRED' : 'TRIAL',
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.dividerColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(role,
        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
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
