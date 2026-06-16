import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/subscription/screens/subscription_screen.dart';
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
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_businesses_screen.dart';
import '../../features/admin/screens/admin_subscriptions_screen.dart';
import '../../features/admin/screens/admin_plans_screen.dart';
import '../../features/admin/screens/admin_users_screen.dart';
import '../../features/admin/screens/admin_settings_screen.dart';
import '../../features/admin/widgets/admin_scaffold.dart';
import '../../features/auth/screens/pending_approval_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../features/customers/screens/add_customer_screen.dart';
import '../../features/customers/screens/customer_detail_screen.dart';
import '../../features/customers/screens/customer_statement_screen.dart';
import '../../features/customers/screens/credit_ledger_screen.dart';
import '../../features/quotations/screens/quotations_screen.dart';
import '../../features/quotations/screens/add_quotation_screen.dart';
import '../../features/quotations/screens/quotation_detail_screen.dart';
import '../../features/suppliers/screens/suppliers_screen.dart';
import '../../features/suppliers/screens/add_supplier_screen.dart';
import '../../features/suppliers/screens/supplier_detail_screen.dart';
import '../../features/purchase_orders/screens/purchase_orders_screen.dart';
import '../../features/purchase_orders/screens/add_purchase_order_screen.dart';
import '../../features/purchase_orders/screens/purchase_order_detail_screen.dart';
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
                                state.matchedLocation == '/register' ||
                                state.matchedLocation == '/forgot-password';
        final isSubscriptionRoute = state.matchedLocation == '/subscription';

        if (!isAuthenticated && !isAuthRoute) return '/login';

        if (isAuthenticated) {
          if (!authProvider.isEmailVerified && state.matchedLocation != '/verify-email') {
            return '/verify-email';
          }
          if (authProvider.isEmailVerified && state.matchedLocation == '/verify-email') {
            return '/dashboard';
          }

          if (authProvider.isSuperAdmin) {
            if (!state.matchedLocation.startsWith('/admin')) {
              return '/admin/dashboard';
            }
            return null;
          }

          if (!isRegistered && state.matchedLocation != '/register' && state.matchedLocation != '/verify-email') {
            return '/register';
          }
          if (isRegistered) {
            if (authProvider.businessStatus == 'pending' && state.matchedLocation != '/pending-approval') {
              return '/pending-approval';
            }
            if (authProvider.businessStatus != 'pending' && isAuthRoute) {
              return '/dashboard';
            }
            if (authProvider.businessStatus != 'pending' && state.matchedLocation == '/pending-approval') {
              return '/dashboard';
            }

            final isExpired = authProvider.subscriptionStatus == 'expired';
            final isProtectedRoute = state.matchedLocation.startsWith('/dashboard') ||
                                     state.matchedLocation.startsWith('/inventory') ||
                                     state.matchedLocation.startsWith('/sales') ||
                                     state.matchedLocation.startsWith('/expenses') ||
                                     state.matchedLocation.startsWith('/reports') ||
                                     state.matchedLocation.startsWith('/team') ||
                                     state.matchedLocation.startsWith('/profile') ||
                                     state.matchedLocation.startsWith('/customers') ||
                                     state.matchedLocation.startsWith('/credit-ledger') ||
                                     state.matchedLocation.startsWith('/quotations') ||
                                     state.matchedLocation.startsWith('/suppliers') ||
                                     state.matchedLocation.startsWith('/purchase-orders');

            if (isExpired && isProtectedRoute && !isSubscriptionRoute) {
              return '/subscription';
            }
          }
        }
        return null;
      },
      routes: [
        // Auth
        GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/verify-email', builder: (_, __) => const EmailVerificationScreen()),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/pending-approval', builder: (_, __) => const PendingApprovalScreen()),
        
        // Super Admin Shell
        ShellRoute(
          builder: (context, state, child) => AdminScaffold(child: child),
          routes: [
            GoRoute(
              path: '/admin/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(child: AdminDashboardScreen()),
            ),
            GoRoute(
              path: '/admin/businesses',
              pageBuilder: (context, state) => const NoTransitionPage(child: AdminBusinessesScreen()),
            ),
            GoRoute(
              path: '/admin/subscriptions',
              pageBuilder: (context, state) => const NoTransitionPage(child: AdminSubscriptionsScreen()),
            ),
            GoRoute(
              path: '/admin/plans',
              pageBuilder: (context, state) => const NoTransitionPage(child: AdminPlansScreen()),
            ),
            GoRoute(
              path: '/admin/users',
              pageBuilder: (context, state) => const NoTransitionPage(child: AdminUsersScreen()),
            ),
            GoRoute(
              path: '/admin/settings',
              pageBuilder: (context, state) => const NoTransitionPage(child: AdminSettingsScreen()),
            ),
          ],
        ),

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
            GoRoute(
              path: '/subscription',
              pageBuilder: (context, state) => const NoTransitionPage(child: SubscriptionScreen()),
            ),
            GoRoute(
              path: '/customers',
              builder: (_, __) => const CustomersScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, __) => const AddCustomerScreen(),
                ),
                GoRoute(
                  path: ':customerId',
                  builder: (_, state) => CustomerDetailScreen(
                    customerId: state.pathParameters['customerId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'statement',
                      builder: (_, state) => CustomerStatementScreen(
                        customerId: state.pathParameters['customerId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/credit-ledger',
              builder: (_, __) => const CreditLedgerScreen(),
            ),
            GoRoute(
              path: '/suppliers',
              builder: (_, __) => const SuppliersScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, __) => const AddSupplierScreen(),
                ),
                GoRoute(
                  path: ':supplierId',
                  builder: (_, state) => SupplierDetailScreen(
                    supplierId: state.pathParameters['supplierId']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/purchase-orders',
              builder: (_, __) => const PurchaseOrdersScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, __) => const AddPurchaseOrderScreen(),
                ),
                GoRoute(
                  path: ':purchaseOrderId',
                  builder: (_, state) => PurchaseOrderDetailScreen(
                    purchaseOrderId: state.pathParameters['purchaseOrderId']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/quotations',
              builder: (_, __) => const QuotationsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (_, __) => const AddQuotationScreen(),
                ),
                GoRoute(
                  path: ':quotationId',
                  builder: (_, state) => QuotationDetailScreen(
                    quotationId: state.pathParameters['quotationId']!,
                  ),
                ),
              ],
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