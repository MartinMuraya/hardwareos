import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';

class AdminScaffold extends StatelessWidget {
  final Widget child;
  const AdminScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1100;
    final isMedium = width >= 700 && width < 1100;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: !isWide ? Drawer(
        child: _Sidebar(
          location: location,
          theme: theme,
          themeProvider: themeProvider,
          isDrawer: true,
        ),
      ) : null,
      appBar: !isWide ? AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
          ),
          const SizedBox(width: 8),
        ],
      ) : null,
      body: Row(
        children: [
          if (isWide)
            _Sidebar(
              location: location,
              theme: theme,
              themeProvider: themeProvider,
            ),
          if (isMedium)
            NavigationRail(
              extended: false,
              selectedIndex: _getSelectedIndex(location),
              onDestinationSelected: (i) => _onNavTap(context, i),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
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
                      onPressed: () => context.read<AuthProvider>().signOut(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text('Overview')),
                NavigationRailDestination(icon: Icon(Icons.store_rounded), label: Text('Businesses')),
                NavigationRailDestination(icon: Icon(Icons.card_membership_rounded), label: Text('Subscriptions')),
                NavigationRailDestination(icon: Icon(Icons.people_rounded), label: Text('Users')),
                NavigationRailDestination(icon: Icon(Icons.view_list_rounded), label: Text('Plans')),
                NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Settings')),
              ],
            ),
          if (isWide || isMedium) const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location == '/admin' || location == '/admin/dashboard') return 0;
    if (location.startsWith('/admin/businesses')) return 1;
    if (location.startsWith('/admin/subscriptions')) return 2;
    if (location.startsWith('/admin/users')) return 3;
    if (location.startsWith('/admin/plans')) return 4;
    if (location.startsWith('/admin/settings')) return 5;
    return 0;
  }

  void _onNavTap(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/admin/dashboard'); break;
      case 1: context.go('/admin/businesses'); break;
      case 2: context.go('/admin/subscriptions'); break;
      case 3: context.go('/admin/users'); break;
      case 4: context.go('/admin/plans'); break;
      case 5: context.go('/admin/settings'); break;
    }
  }
}

class _Sidebar extends StatelessWidget {
  final String location;
  final ThemeData theme;
  final ThemeProvider themeProvider;
  final bool isDrawer;

  const _Sidebar({
    required this.location,
    required this.theme,
    required this.themeProvider,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(24, isDrawer ? 32 : 48, 16, 32),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hardware_rounded, color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AdminOS',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (!isDrawer)
                  IconButton(
                    icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                    onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Overview',
                  isSelected: location == '/admin' || location == '/admin/dashboard',
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/dashboard');
                  },
                ),
                _NavItem(
                  icon: Icons.store_rounded,
                  label: 'Businesses',
                  isSelected: location.startsWith('/admin/businesses'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/businesses');
                  },
                ),
                _NavItem(
                  icon: Icons.card_membership_rounded,
                  label: 'Subscriptions',
                  isSelected: location.startsWith('/admin/subscriptions'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/subscriptions');
                  },
                ),
                _NavItem(
                  icon: Icons.people_rounded,
                  label: 'Users',
                  isSelected: location.startsWith('/admin/users'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/users');
                  },
                ),
                _NavItem(
                  icon: Icons.view_list_rounded,
                  label: 'Plans',
                  isSelected: location.startsWith('/admin/plans'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/plans');
                  },
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: location.startsWith('/admin/settings'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin/settings');
                  },
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accent,
                  child: Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Super Admin', style: theme.textTheme.labelLarge),
                      Text('Platform Control', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => context.read<AuthProvider>().signOut(),
                  tooltip: 'Sign Out',
                ),
              ],
            ),
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
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        selected: isSelected,
        leading: Icon(icon, color: isSelected ? AppColors.accent : null),
        title: Text(label, style: TextStyle(
          color: isSelected ? AppColors.accent : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        )),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selectedTileColor: AppColors.accent.withValues(alpha: 0.1),
        dense: true,
      ),
    );
  }
}
