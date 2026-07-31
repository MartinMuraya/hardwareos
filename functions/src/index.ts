// ============================================================
// Cloud Functions Entry Point — exports all callables
// ============================================================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({ maxInstances: 100 });

// Initialize Firebase Admin SDK (once)
admin.initializeApp();

// Auth
export { createBusiness, inviteUser, updateStaff, getMyProfile, getUsers } from "./functions/auth";

// Security - Login/Password Abuse Protection
export {
  checkLoginLocked,
  reportFailedLogin,
  reportSuccessfulLogin,
  requestPasswordReset,
} from "./functions/loginSecurity";

// Inventory
export {
  createProduct,
  updateProduct,
  addStock,
  getProducts,
  getLowStockProducts,
} from "./functions/inventory";

// Bulk Import
export { importProducts } from "./functions/import_products";

// Inventory — Stock Adjustments
export {
  adjustInventoryStock,
  getStockAdjustments,
  getAdjustmentStats,
} from "./functions/stock_adjustments";

// Inventory Ledger
export { migrateToLedger } from "./functions/inventory_ledger";

// AI Intelligence & Business Analyst
export { analyzeInventoryHealth } from "./functions/ai";
export { getAIInsights, getAIQuickInsights } from "./functions/ai_assistant";
export { runAIBusinessAnalyst, approveAIDraftedAction } from "./functions/ai_business_analyst";

// Sales
export { createSale, getSales } from "./functions/sales";

// Supplier Debt
export { recordSupplierPayment, getSupplierDebts, getSupplierDebtDashboard } from "./functions/supplier_debt";

// EOD Daily Report
export { sendDailyEodReport, updateEodReportSettings } from "./functions/eod_report";

// Expenses
export { createExpense, getExpenses } from "./functions/expenses";

// Purchases & Suppliers
export { createPurchase, getPurchases } from "./functions/purchases";
export { createSupplier, getSuppliers, getSupplier, updateSupplier } from "./functions/suppliers";
export { createPurchaseOrder, getPurchaseOrders, getPurchaseOrder, updatePurchaseOrderStatus, receivePurchaseOrder } from "./functions/purchase_orders";

// Dashboard & Reports
export { getDashboardStats, getReportStats, seedDemoData } from "./functions/dashboard";

// Super Admin Operations & Plan Configs
export { getPlatformStats, adminGrantSuperAdmin, adminRevokeSuperAdmin } from "./functions/super_admin";
export { adminGetAllBusinesses, adminUpdateBusinessStatus, adminDeleteBusiness } from "./functions/admin_businesses";
export {
  adminGetSubscriptions,
  adminUpdateSubscription,
  getMySubscriptionPayments,
  adminImpersonateTenant,
  createGlobalAnnouncement,
  adminGetSystemLogs,
  adminGetPlanConfigs,
  adminSavePlanConfig,
} from "./functions/admin_operations";

// Support
export {
  createSupportTicket,
  adminGetSupportTickets,
  adminRespondToTicket,
} from "./functions/support";

// M-Pesa Billing & Subscription Lifecycle
export { createSubscriptionPayment, mpesaCallback, simulateMpesaCallback } from "./functions/mpesa_billing";
export {
  expireSubscriptions,
  sendRenewalReminders,
  getSubscriptionAnalytics,
  checkSubscriptionHealth,
} from "./functions/subscriptionLifecycle";
export { getMySubscriptionHistory, adminGetBusinessHistory } from "./functions/subscriptionHistory";
export { initiateStkPush, posMpesaCallback } from "./functions/mpesa";

// Customers & Credit Debt
export { createCustomer, getCustomers, getCustomer, updateCustomer } from "./functions/customers";
export { createCreditSale, recordDebtPayment, adjustDebt, getDebtTransactions, getCustomerStatement, getDebtDashboard } from "./functions/debt";

// Quotations
export { createQuotation, getQuotations, getQuotation, updateQuotationStatus, convertQuotationToSale } from "./functions/quotations";

// Audit Trail, Returns, Cash Drawer
export { getAuditLogs, getAuditModules, getRecentAuditLogs } from "./functions/audit_log";
export { processReturn, getReturns, getReturnStats } from "./functions/returns";
export { openCashSession, closeCashSession, getCashSessions, getCashVarianceReport, calculateCashVariance, getDailyCashReport, getMonthlyCashReport } from "./functions/cash_drawer";

// Broken-Bulk Inventory & Branches
export { bulkCreateProduct, autoConvertDuringSale, validateConversion, convertParentToChild } from "./functions/bulk_inventory";
export { createBranch, getBranch, getBranches, updateBranch, requestStockTransfer, approveStockTransfer, getStockTransfers, getBranchInventory, getBranchPerformance, getPendingTransfers, getSalesByBranch, getBranchExpensesReport, getBranchProfitReport } from "./functions/branches";

// WhatsApp Automation & Security Dashboard
export { enqueueNotification, getNotificationSettings, updateNotificationSettings, getNotifications, getNotificationStats, processNotificationQueue } from "./functions/whatsapp_automation";
export { getSecurityMetrics, getSecurityEvents } from "./functions/securityDashboard";
export { getAdvancedAnalytics, getDemandForecast } from "./functions/advanced_analytics";

// Storefront API
export { getPublicStorefront, getPublicProducts, getStorefrontCategories, createOnlineOrder, approveOnlineOrder, rejectOnlineOrder, getStorefrontSettings, updateStorefrontSettings, checkSlugAvailability } from "./functions/storefront";

// Accounting, HR & Tax
export { initializeChartOfAccounts, getChartOfAccounts, postManualJournalEntry, getTrialBalance, migrateHistoricalData } from "./functions/accounting";
export { saveHrSettings, getHrSettings, createEmployee, updateEmployee, submitTimesheet, processLeave, generatePayroll, processPayroll, payoutCommission } from "./functions/hr";
export { getTaxSettings, updateTaxSettings } from "./functions/tax";
export { exportAdminReport } from "./functions/admin_reports";
export { sendDebtReminders } from "./functions/sms_reminders";
export { runSystemMaintenance } from "./functions/system_maintenance";
