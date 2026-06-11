import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/add_product_screen.dart';
import '../../features/inventory/screens/product_detail_screen.dart';
import '../../features/sales/screens/pos_screen.dart';
import '../../features/sales/screens/sales_history_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/expenses/screens/add_expense_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/team/screens/team_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_scaffold.dart';

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isRegistered    = authProvider.isRegistered;
        final isAuthRoute     = state.matchedLocation == '/login' ||
                                state.matchedLocation == '/register';

        if (!isAuthenticated && !isAuthRoute) return '/login';
        if (isAuthenticated && !isRegistered && state.matchedLocation != '/register') {
          return '/register';
        }
        if (isAuthenticated && isRegistered && isAuthRoute) return '/dashboard';
        return null;
      },
      routes: [
        // Auth
        GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

        // Shell with side nav
        ShellRoute(
          builder: (context, state, child) => AppScaffold(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, __) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/inventory',
              builder: (_, __) => const InventoryScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, __) => const AddProductScreen(),
                ),
                GoRoute(
                  path: ':productId',
                  builder: (_, state) => ProductDetailScreen(
                    productId: state.pathParameters['productId']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/sales',
              builder: (_, __) => const POSScreen(),
              routes: [
                GoRoute(
                  path: 'history',
                  builder: (_, __) => const SalesHistoryScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/expenses',
              builder: (_, __) => const ExpensesScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, __) => const AddExpenseScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/reports',
              pageBuilder: (context, state) => const NoTransitionPage(child: ReportsScreen()),
            ),
            GoRoute(
              path: '/team',
              pageBuilder: (context, state) => const NoTransitionPage(child: TeamScreen()),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Page not found: ${state.uri}'),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
