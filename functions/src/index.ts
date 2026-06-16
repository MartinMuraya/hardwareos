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
