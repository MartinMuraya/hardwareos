// ============================================================
// Cloud Functions Entry Point — exports all callables
// ============================================================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({ maxInstances: 100 });

// Initialize Firebase Admin SDK (once)
admin.initializeApp();

// Auth
const functionName = process.env.FUNCTION_TARGET || process.env.K_SERVICE;
function lazyExport(modulePath: string, exportsList: string[]) {
  exportsList.forEach((name) => {
    if (!functionName || functionName === name) {
      exports[name] = require(modulePath)[name];
    }
  });
}

lazyExport('./functions/auth', ['createBusiness', 'inviteUser', 'updateStaff', 'getMyProfile', 'getUsers']);

// Security - Login/Password Abuse Protection
lazyExport('./functions/loginSecurity', ['checkLoginLocked', 'reportFailedLogin', 'reportSuccessfulLogin', 'requestPasswordReset']);

// Inventory
lazyExport('./functions/inventory', ['createProduct', 'updateProduct', 'addStock', 'getProducts', 'getLowStockProducts']);

// Bulk Import
lazyExport('./functions/import_products', ['importProducts']);

// Inventory — Stock Adjustments
lazyExport('./functions/stock_adjustments', ['adjustInventoryStock', 'getStockAdjustments', 'getAdjustmentStats']);

// Inventory Ledger
lazyExport('./functions/inventory_ledger', ['migrateToLedger']);

// AI Intelligence & Business Analyst
lazyExport('./functions/ai', ['analyzeInventoryHealth']);
lazyExport('./functions/ai_assistant', ['getAIInsights', 'getAIQuickInsights']);
lazyExport('./functions/ai_business_analyst', ['runAIBusinessAnalyst', 'approveAIDraftedAction']);

// Sales
lazyExport('./functions/sales', ['createSale', 'getSales']);

// Supplier Debt
lazyExport('./functions/supplier_debt', ['recordSupplierPayment', 'getSupplierDebts', 'getSupplierDebtDashboard']);

// EOD Daily Report
lazyExport('./functions/eod_report', ['sendDailyEodReport', 'updateEodReportSettings']);

// Expenses
lazyExport('./functions/expenses', ['createExpense', 'getExpenses']);

// Purchases & Suppliers
lazyExport('./functions/purchases', ['createPurchase', 'getPurchases']);
lazyExport('./functions/suppliers', ['createSupplier', 'getSuppliers', 'getSupplier', 'updateSupplier']);
lazyExport('./functions/purchase_orders', ['createPurchaseOrder', 'getPurchaseOrders', 'getPurchaseOrder', 'updatePurchaseOrderStatus', 'receivePurchaseOrder']);

// Dashboard & Reports
lazyExport('./functions/dashboard', ['getDashboardStats', 'getReportStats', 'seedDemoData']);

// System Health
lazyExport('./functions/health', ['healthCheck']);

// Super Admin Operations & Plan Configs
lazyExport('./functions/super_admin', ['getPlatformStats', 'adminGrantSuperAdmin', 'adminRevokeSuperAdmin']);
lazyExport('./functions/admin_businesses', ['adminGetAllBusinesses', 'adminUpdateBusinessStatus', 'adminDeleteBusiness']);
lazyExport('./functions/admin_operations', ['adminGetSubscriptions', 'adminUpdateSubscription', 'getMySubscriptionPayments', 'adminImpersonateTenant', 'createGlobalAnnouncement', 'adminGetSystemLogs', 'adminGetPlanConfigs', 'adminSavePlanConfig', 'adminGetPlans', 'adminCreatePlan', 'adminUpdatePlan', 'adminDeletePlan', 'adminGetUsers', 'adminUpdateUser', 'adminGetSettings', 'adminUpdateSettings']);

// Support
lazyExport('./functions/support', ['createSupportTicket', 'adminGetSupportTickets', 'adminRespondToTicket']);

// M-Pesa Billing & Subscription Lifecycle
lazyExport('./functions/mpesa_billing', ['createSubscriptionPayment', 'mpesaCallback', 'simulateMpesaCallback']);
lazyExport('./functions/subscriptionLifecycle', ['expireSubscriptions', 'sendRenewalReminders', 'getSubscriptionAnalytics', 'checkSubscriptionHealth']);
lazyExport('./functions/subscriptionHistory', ['getMySubscriptionHistory', 'adminGetBusinessHistory']);
lazyExport('./functions/mpesa', ['initiateStkPush', 'posMpesaCallback']);

// Customers & Credit Debt
lazyExport('./functions/customers', ['createCustomer', 'getCustomers', 'getCustomer', 'updateCustomer']);
lazyExport('./functions/debt', ['createCreditSale', 'recordDebtPayment', 'adjustDebt', 'getDebtTransactions', 'getCustomerStatement', 'getDebtDashboard']);

// Quotations
lazyExport('./functions/quotations', ['createQuotation', 'getQuotations', 'getQuotation', 'updateQuotationStatus', 'convertQuotationToSale']);

// Audit Trail, Returns, Cash Drawer
lazyExport('./functions/audit_log', ['getAuditLogs', 'getAuditModules', 'getRecentAuditLogs']);
lazyExport('./functions/returns', ['processReturn', 'getReturns', 'getReturnStats']);
lazyExport('./functions/cash_drawer', ['openCashSession', 'closeCashSession', 'getCashSessions', 'getCashVarianceReport', 'calculateCashVariance', 'getDailyCashReport', 'getMonthlyCashReport']);

// Broken-Bulk Inventory & Branches
lazyExport('./functions/bulk_inventory', ['bulkCreateProduct', 'autoConvertDuringSale', 'validateConversion', 'convertParentToChild']);
lazyExport('./functions/branches', ['createBranch', 'getBranch', 'getBranches', 'updateBranch', 'requestStockTransfer', 'approveStockTransfer', 'getStockTransfers', 'getBranchInventory', 'getBranchPerformance', 'getPendingTransfers', 'getSalesByBranch', 'getBranchExpensesReport', 'getBranchProfitReport']);

// WhatsApp Automation & Security Dashboard
lazyExport('./functions/whatsapp_automation', ['enqueueNotification', 'getNotificationSettings', 'updateNotificationSettings', 'getNotifications', 'getNotificationStats', 'processNotificationQueue']);
lazyExport('./functions/securityDashboard', ['getSecurityMetrics', 'getSecurityEvents']);
lazyExport('./functions/advanced_analytics', ['getAdvancedAnalytics', 'getDemandForecast']);

// Storefront API
lazyExport('./functions/storefront', ['getPublicStorefront', 'getPublicProducts', 'getStorefrontCategories', 'createOnlineOrder', 'approveOnlineOrder', 'rejectOnlineOrder', 'getStorefrontSettings', 'updateStorefrontSettings', 'checkSlugAvailability']);

// Accounting, HR & Tax
lazyExport('./functions/accounting', ['initializeChartOfAccounts', 'getChartOfAccounts', 'postManualJournalEntry', 'getTrialBalance', 'migrateHistoricalData']);
lazyExport('./functions/hr', ['saveHrSettings', 'getHrSettings', 'createEmployee', 'updateEmployee', 'submitTimesheet', 'processLeave', 'generatePayroll', 'processPayroll', 'payoutCommission']);
lazyExport('./functions/tax', ['getTaxSettings', 'updateTaxSettings']);
lazyExport('./functions/admin_reports', ['exportAdminReport']);
lazyExport('./functions/sms_reminders', ['sendDebtReminders']);
lazyExport('./functions/system_maintenance', ['runSystemMaintenance']);

export {};