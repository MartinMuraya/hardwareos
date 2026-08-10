// ============================================================
// Inventory Functions — Product CRUD + Stock Management
// ============================================================

import * as admin from "firebase-admin";
import { rateLimitCheck } from "../middleware/rateLimiter";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertBusinessMember,
  assertActiveSubscription,
  assertProductLimit,
} from "../middleware/checkPlanLimits";
import { sanitizeInput } from "../middleware/securityMiddleware";

const db = () => admin.firestore();

// -----------------------------------------------------------
// createProduct
// Validates plan limits before creating a new product.
// Only owner/manager can create products.
// -----------------------------------------------------------
export const createProduct = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  await rateLimitCheck(request.rawRequest?.ip || request.auth.uid, "createProduct", 60, 1);

  const {
    businessId, name, sku, category,
    quantity, costPrice, sellingPrice, reorderLevel,
    isPublishedOnline, images, description
  } = request.data as {
    businessId: string;
    name: string;
    sku: string;
    category: string;
    quantity: number;
    costPrice: number;
    sellingPrice: number;
    reorderLevel: number;
    barcodes?: string[];
    branchId?: string;
    isPublishedOnline?: boolean;
    images?: string[];
    description?: string;
    trackSerials?: boolean;
    trackBatches?: boolean;
  };

  if (!name || !businessId) throw new HttpsError("invalid-argument", "name and businessId required.");
  if (sellingPrice <= 0 || costPrice < 0) throw new HttpsError("invalid-argument", "Invalid prices.");
  if (quantity < 0) throw new HttpsError("invalid-argument", "Quantity cannot be negative.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertProductLimit(businessId);

  // Check for duplicate SKU within business
  if (sku) {
    let query = db()
      .collection("products")
      .where("businessId", "==", businessId)
      .where("sku", "==", sku.trim());
      
    if (request.data.branchId) {
      query = query.where("branchId", "==", request.data.branchId.trim());
    }
    
    const dupSnap = await query.limit(1).get();
    if (!dupSnap.empty) {
      throw new HttpsError("already-exists", `SKU "${sku}" already exists in your inventory.`);
    }
  }

  const productRef = db().collection("products").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db().batch();

  batch.set(productRef, {
    id: productRef.id,
    businessId,
    name: sanitizeInput(name),
    sku: sanitizeInput(sku) || "",
    category: sanitizeInput(category) || "General",
    quantity: Number(quantity),
    costPrice: Number(costPrice),
    sellingPrice: Number(sellingPrice),
    reorderLevel: Number(reorderLevel) || 5,
    barcodes: request.data.barcodes || [],
    branchId: sanitizeInput(request.data.branchId) || null,
    isPublishedOnline: !!isPublishedOnline,
    images: images || [],
    description: sanitizeInput(description) || "",
    trackSerials: request.data.trackSerials || false,
    trackBatches: request.data.trackBatches || false,
    createdAt: now,
    updatedAt: now,
  });

  // Log initial stock movement if quantity > 0
  if (quantity > 0) {
    const movRef = db().collection("stockMovements").doc();
    batch.set(movRef, {
      id: movRef.id,
      businessId,
      productId: productRef.id,
      type: "IN",
      quantity: Number(quantity),
      reason: "Initial stock",
      referenceId: productRef.id,
      branchId: request.data.branchId?.trim() || null,
      createdAt: now,
    });
  }

  await batch.commit();

  return { success: true, productId: productRef.id };
});

// -----------------------------------------------------------
// updateProduct
// Updates product details. Stock changes must use addStock().
// -----------------------------------------------------------
export const updateProduct = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, productId, updates } = request.data as {
    businessId: string;
    productId: string;
    updates: Record<string, unknown>;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  // Prevent direct quantity manipulation via updateProduct
  const safeUpdates = { ...updates };
  delete safeUpdates["quantity"];
  delete safeUpdates["businessId"];
  delete safeUpdates["id"];
  safeUpdates["updatedAt"] = admin.firestore.FieldValue.serverTimestamp();

  await db().collection("products").doc(productId).update(safeUpdates);
  return { success: true };
});

// -----------------------------------------------------------
// addStock
// Increases inventory quantity + logs stock movement.
// Used for manual top-ups and purchase receipts.
// -----------------------------------------------------------
export const addStock = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  await rateLimitCheck(request.rawRequest?.ip || request.auth.uid, "addStock", 60, 1);

  const { businessId, productId, quantity, reason, referenceId, branchId } = request.data as {
    businessId: string;
    productId: string;
    quantity: number;
    reason: string;
    referenceId?: string;
    branchId?: string;
  };

  if (!quantity || quantity <= 0) throw new HttpsError("invalid-argument", "Quantity must be > 0.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  let movementId = "";

  await db().runTransaction(async (txn) => {
    const productRef = db().collection("products").doc(productId);
    const productSnap = await txn.get(productRef);
    
    if (!productSnap.exists) {
      throw new HttpsError("not-found", "Product not found.");
    }
    
    if (productSnap.data()!.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Product does not belong to your business.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    // Increment stock
    txn.update(productRef, {
      quantity: admin.firestore.FieldValue.increment(Number(quantity)),
      updatedAt: now,
    });

    // Log movement
    const movRef = db().collection("stockMovements").doc();
    movementId = movRef.id;
    txn.set(movRef, {
      id: movRef.id,
      businessId,
      productId,
      type: "IN",
      quantity: Number(quantity),
      reason: sanitizeInput(reason) || "Stock addition",
      referenceId: sanitizeInput(referenceId) || null,
      branchId: sanitizeInput(branchId) || productSnap.data()!.branchId || null,
      createdAt: now,
    });
  });

  return { success: true, movementId };
});

// -----------------------------------------------------------
// getProducts
// Paginated product list with optional search/filter.
// -----------------------------------------------------------
export const getProducts = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 50, startAfter, category, branchId } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
    category?: string;
    branchId?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("products")
    .where("businessId", "==", businessId)
    .orderBy("name")
    .limit(Math.min(pageLimit, 100));

  if (branchId) {
    // If branchId is provided, filter by it. This requires a composite index.
    query = db()
      .collection("products")
      .where("businessId", "==", businessId)
      .where("branchId", "==", branchId)
      .orderBy("name")
      .limit(Math.min(pageLimit, 100));
  }

  if (category && category !== "All") {
    query = query.where("category", "==", category);
  }

  if (startAfter) {
    const cursor = await db().collection("products").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  // Wrap in an object so Flutter's FunctionsService (which casts result.data
  // to Map<String, dynamic>) does not throw when receiving a top-level list.
  return { products: snap.docs.map((d) => d.data()) };
});

// -----------------------------------------------------------
// getLowStockProducts
// Returns products at or below reorderLevel. Used by dashboard.
// -----------------------------------------------------------
export const getLowStockProducts = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, branchId } = request.data as { businessId: string; branchId?: string };
  await assertBusinessMember(request.auth.uid, businessId);

  // Firestore requires a composite index for this query
  let query = db()
    .collection("products")
    .where("businessId", "==", businessId)
    .orderBy("quantity")
    .limit(20);
    
  if (branchId) {
    query = db()
      .collection("products")
      .where("businessId", "==", businessId)
      .where("branchId", "==", branchId)
      .orderBy("quantity")
      .limit(20);
  }

  const snap = await query.get();

  // Filter client-side to quantity <= reorderLevel
  const low = snap.docs
    .map((d) => d.data())
    .filter((p) => p.quantity <= p.reorderLevel);

  return { products: low };
});
