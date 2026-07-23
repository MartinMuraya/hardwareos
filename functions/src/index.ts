// ============================================================
// Cloud Functions Entry Point — exports all callables
// ============================================================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({ maxInstances: 10 });

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

// AI Intelligence
export { analyzeInventoryHealth } from "./functions/ai";

// Sales
export { createSale, getSales } from "./functions/sales";

// Expenses
export { createExpense, getExpenses } from "./functions/expenses";

// Purchases
export { createPurchase, getPurchases } from "./functions/purchases";

// Dashboard & Reports
export { getDashboardStats, getReportStats, seedDemoData } from "./functions/dashboard";

// Super Admin
export { getPlatformStats, adminGrantSuperAdmin, adminRevokeSuperAdmin } from "./functions/super_admin";
export { adminGetAllBusinesses, adminUpdateBusinessStatus, adminDeleteBusiness } from "./functions/admin_businesses";
export {
  adminGetSubscriptions,
  adminUpdateSubscription,
  adminGetPlans,
  adminCreatePlan,
  adminUpdatePlan,
  adminDeletePlan,
  adminGetUsers,
  adminUpdateUser,
  adminGetSettings,
  adminUpdateSettings,
  getMySubscriptionPayments,
  adminImpersonateTenant,
  createGlobalAnnouncement,
  adminGetSystemLogs,
} from "./functions/admin_operations";

// Support
export {
  createSupportTicket,
  adminGetSupportTickets,
  adminRespondToTicket,
} from "./functions/support";

// M-Pesa Billing
export { createSubscriptionPayment, mpesaCallback, simulateMpesaCallback } from "./functions/mpesa_billing";

// Subscription Lifecycle
export {
  expireSubscriptions,
  sendRenewalReminders,
  getSubscriptionAnalytics,
  checkSubscriptionHealth,
} from "./functions/subscriptionLifecycle";

// Subscription History
export {
  getMySubscriptionHistory,
  adminGetBusinessHistory,
} from "./functions/subscriptionHistory";

// Customers & Debt
export {
  createCustomer,
  getCustomers,
  getCustomer,
  updateCustomer,
} from "./functions/customers";

export {
  createCreditSale,
  recordDebtPayment,
  adjustDebt,
  getDebtTransactions,
  getCustomerStatement,
  getDebtDashboard,
} from "./functions/debt";

// Quotations
export {
  createQuotation,
  getQuotations,
  getQuotation,
  updateQuotationStatus,
  convertQuotationToSale,
} from "./functions/quotations";

// Suppliers & Purchase Orders
export {
  createSupplier,
  getSuppliers,
  getSupplier,
  updateSupplier,
} from "./functions/suppliers";

export {
  createPurchaseOrder,
  getPurchaseOrders,
  getPurchaseOrder,
  updatePurchaseOrderStatus,
  receivePurchaseOrder,
} from "./functions/purchase_orders";

// Audit Trail
export {
  getAuditLogs,
  getAuditModules,
  getRecentAuditLogs,
} from "./functions/audit_log";

// Returns & Refunds
export {
  processReturn,
  getReturns,
  getReturnStats,
} from "./functions/returns";

// Cash Drawer Reconciliation
export {
  openCashSession,
  closeCashSession,
  getCashSessions,
  getCashVarianceReport,
  calculateCashVariance,
  getDailyCashReport,
  getMonthlyCashReport,
} from "./functions/cash_drawer";

// Broken-Bulk Inventory
export {
  bulkCreateProduct,
  autoConvertDuringSale,
  validateConversion,
  convertParentToChild,
} from "./functions/bulk_inventory";

// Multi-Branch Operations
export {
  createBranch,
  getBranch,
  getBranches,
  updateBranch,
  requestStockTransfer,
  approveStockTransfer,
  getStockTransfers,
  getBranchInventory,
  getBranchPerformance,
  getPendingTransfers,
  getSalesByBranch,
  getBranchExpensesReport,
  getBranchProfitReport,
} from "./functions/branches";

// WhatsApp Automation
export {
  enqueueNotification,
  getNotificationSettings,
  updateNotificationSettings,
  getNotifications,
  getNotificationStats,
  processNotificationQueue,
} from "./functions/whatsapp_automation";

// Security Dashboard
export {
  getSecurityMetrics,
  getSecurityEvents,
} from "./functions/securityDashboard";

// AI Assistant
export {
  getAIInsights,
  getAIQuickInsights,
} from "./functions/ai_assistant";

// Advanced Analytics
export {
  getAdvancedAnalytics,
  getDemandForecast,
} from "./functions/advanced_analytics";

// Storefront (Real Implementation)
export {
  getPublicStorefront,
  getPublicProducts,
  getStorefrontCategories,
  createOnlineOrder,
  approveOnlineOrder,
  rejectOnlineOrder,
} from "./functions/storefront";

// Accounting
export {
  initializeChartOfAccounts,
  getChartOfAccounts,
  postManualJournalEntry,
  getTrialBalance,
  migrateHistoricalData,
} from "./functions/accounting";

// HR & Payroll
export {
  saveHrSettings,
  getHrSettings,
  createEmployee,
  updateEmployee,
  submitTimesheet,
  processLeave,
  generatePayroll,
  processPayroll,
  payoutCommission,
} from "./functions/hr";

// Storefront Stubs (To prevent deletion during deployment)
export {
  addToCart,
  approveReturn,
  cancelOrder,
  checkSlugAvailability,
  clearCart,
  createDeliveryZone,
  createStorefrontCategory,
  deleteCart,
  deleteCustomer,
  deleteCustomerAddress,
  deleteDeliveryZone,
  deleteProduct,
  deleteStorefrontCategory,
  deleteSupplier,
  disableStorefront,
  enableStorefront,
  getActiveHolds,
  getCart,
  getCarts,
  getCheckoutAttempts,
  getCommerceAnalytics,
  getCommerceTemplates,
  getCustomerAddresses,
  getDeliveryZones,
  getOnlineOrder,
  getOnlineOrders,
  getOrderMetrics,
  getOrderReturns,
  getPublicCategories,
  getPublicProductDetails,
  getStorefrontSettings,
  processFailedSyncRetries,
  processRefund,
  processStaleCheckouts,
  recordCheckoutAttempt,
  rejectReturn,
  releaseExpiredHolds,
  releaseStockHold,
  removeFromCart,
  requestReturn,
  resetCommerceTemplate,
  retryCheckout,
  rollupAnalytics,
  saveCustomerAddress,
  scanAbandonedCarts,
  trackEvent,
  updateCartQuantity,
  updateCommerceTemplate,
  updateDeliveryZone,
  updateOrderStatus,
  updateStorefrontCategory,
  updateStorefrontSettings,
} from "./functions/storefront_stubs";
