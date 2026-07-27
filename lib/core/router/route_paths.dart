class RoutePaths {
  // Auth
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const pendingApproval = '/pending-approval';
  static const authError = '/auth-error';

  // Main app
  static const dashboard = '/dashboard';
  static const subscription = '/subscription';
  static const storefront = '/store'; // base for /store/:tenantSlug
  static const storefrontSettings = '/storefront-settings';
  static const profile = '/profile';

  // Admin
  static const adminBase = '/admin';
  static const adminDashboard = '/admin/dashboard';
  static const adminBusinesses = '/admin/businesses';
  static const adminSubscriptions = '/admin/subscriptions';
  static const adminPlans = '/admin/plans';
  static const adminAnalytics = '/admin/analytics';
  static const adminUsers = '/admin/users';
  static const adminSecurity = '/admin/security';
  static const adminSettings = '/admin/settings';
  static const adminSupport = '/admin/support';
  static const adminSystemLogs = '/admin/system-logs';

  // Common features
  static const inventory = '/inventory';
  static const sales = '/sales';
  static const expenses = '/expenses';
  static const reports = '/reports';
  static const team = '/team';
  static const customers = '/customers';
  static const suppliers = '/suppliers';
  static const creditLedger = '/credit-ledger';
  static const purchaseOrders = '/purchase-orders';
  static const stockAdjustments = '/stock-adjustments';
  static const auditLogs = '/audit-logs';
  static const returns = '/returns';
  static const cashDrawer = '/cash-drawer';
  static const branches = '/branches';
  static const stockTransfers = '/stock-transfers';
  static const accounting = '/accounting';
  static const hr = '/hr';
  static const advancedAnalytics = '/advanced-analytics';
  static const support = '/support';
  static const notifications = '/notifications';
  static const printerSettings = '/printer-settings';
  static const labelSettings = '/label-settings';
  static const supplierDebt = '/supplier-debt';
  static const aiAssistant = '/ai-assistant';
  static const pending = '/pending-approval';
}
