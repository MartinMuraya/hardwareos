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
