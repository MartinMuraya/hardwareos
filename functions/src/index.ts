// ============================================================
// Cloud Functions Entry Point — exports all callables
// ============================================================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({ maxInstances: 10 });

// Initialize Firebase Admin SDK (once)
admin.initializeApp();

// Auth
export { createBusiness, inviteUser, getMyProfile, getUsers } from "./functions/auth";

// Inventory
export {
  createProduct,
  updateProduct,
  addStock,
  getProducts,
  getLowStockProducts,
} from "./functions/inventory";

// Inventory — Stock Adjustments
export {
  adjustInventoryStock,
  getStockAdjustments,
  getAdjustmentStats,
} from "./functions/stock_adjustments";

// Sales
export { createSale, getSales } from "./functions/sales";

// Expenses
export { createExpense, getExpenses } from "./functions/expenses";

// Purchases
export { createPurchase, getPurchases } from "./functions/purchases";

// Dashboard & Reports
export { getDashboardStats, getReportStats } from "./functions/dashboard";

// Super Admin
export { getPlatformStats } from "./functions/super_admin";
export { adminGetAllBusinesses, adminUpdateBusinessStatus } from "./functions/admin_businesses";
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
} from "./functions/admin_operations";

// M-Pesa Billing
export { createSubscriptionPayment, mpesaCallback, simulateMpesaCallback } from "./functions/mpesa_billing";

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
} from "./functions/cash_drawer";

// Broken-Bulk Inventory
export {
  bulkCreateProduct,
  autoConvertDuringSale,
} from "./functions/bulk_inventory";

// Multi-Branch Operations
export {
  createBranch,
  getBranches,
  updateBranch,
  requestStockTransfer,
  approveStockTransfer,
  getStockTransfers,
  getBranchInventory,
  getBranchPerformance,
  getPendingTransfers,
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
