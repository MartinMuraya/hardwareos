// ============================================================
// Inventory Functions — Product CRUD + Stock Management
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertBusinessMember,
  assertActiveSubscription,
  assertProductLimit,
  softDeleteResource,
} from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// createProduct
// Validates plan limits before creating a new product.
// Only owner/manager can create products.
// -----------------------------------------------------------
export const createProduct = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const {
    businessId, name, sku, category,
    quantity, costPrice, sellingPrice, reorderLevel,
  } = request.data as {
    businessId: string;
    name: string;
    sku: string;
    category: string;
    quantity: number;
    costPrice: number;
    sellingPrice: number;
    reorderLevel: number;
  };

  if (!name || !businessId) throw new HttpsError("invalid-argument", "name and businessId required.");
  if (sellingPrice <= 0 || costPrice < 0) throw new HttpsError("invalid-argument", "Invalid prices.");
  if (quantity < 0) throw new HttpsError("invalid-argument", "Quantity cannot be negative.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertProductLimit(businessId);

  // Check for duplicate SKU within business
  if (sku) {
    const dupSnap = await db()
      .collection("products")
      .where("businessId", "==", businessId)
      .where("sku", "==", sku.trim())
      .limit(1)
      .get();
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
    name: name.trim(),
    sku: sku?.trim() || "",
    category: category?.trim() || "General",
    quantity: Math.floor(quantity),
    costPrice: Number(costPrice),
    sellingPrice: Number(sellingPrice),
    reorderLevel: Math.floor(reorderLevel) || 5,
    isActive: true,
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
      quantity: Math.floor(quantity),
      reason: "Initial stock",
      referenceId: productRef.id,
      createdAt: now,
    });
  }

  await batch.commit();

  return { success: true, productId: productRef.id };
});

// -----------------------------------------------------------
// deleteProduct
// Soft-deletes a product by setting isActive to false.
// -----------------------------------------------------------
export const deleteProduct = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, productId } = request.data as {
    businessId: string;
    productId: string;
  };

  if (!businessId || !productId) {
    throw new HttpsError("invalid-argument", "businessId and productId are required.");
  }

  await softDeleteResource({
    businessId,
    resourceId: productId,
    collection: "products",
    callerUid: request.auth.uid,
    targetType: "products",
  });

  return { success: true };
});

// -----------------------------------------------------------
// updateProduct
// Updates product details. Stock changes must use addStock().
// -----------------------------------------------------------
export const updateProduct = onCall({ cors: true }, async (request) => {
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
export const addStock = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, productId, quantity, reason, referenceId } = request.data as {
    businessId: string;
    productId: string;
    quantity: number;
    reason: string;
    referenceId?: string;
  };

  if (!quantity || quantity <= 0) throw new HttpsError("invalid-argument", "Quantity must be > 0.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  // Verify product belongs to business
  const productSnap = await db().collection("products").doc(productId).get();
  if (!productSnap.exists || productSnap.data()!.businessId !== businessId) {
    throw new HttpsError("not-found", "Product not found.");
  }

  const batch = db().batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  // Increment stock
  batch.update(db().collection("products").doc(productId), {
    quantity: admin.firestore.FieldValue.increment(Math.floor(quantity)),
    updatedAt: now,
  });

  // Log movement
  const movRef = db().collection("stockMovements").doc();
  batch.set(movRef, {
    id: movRef.id,
    businessId,
    productId,
    type: "IN",
    quantity: Math.floor(quantity),
    reason: reason || "Stock addition",
    referenceId: referenceId || null,
    createdAt: now,
  });

  await batch.commit();
  return { success: true, movementId: movRef.id };
});

// -----------------------------------------------------------
// getProducts
// Paginated product list with optional search/filter.
// -----------------------------------------------------------
export const getProducts = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 50, startAfter, category } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
    category?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("products")
    .where("businessId", "==", businessId)
    .where("isActive", "==", true)
    .orderBy("name")
    .limit(Math.min(pageLimit, 100));

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
export const getLowStockProducts = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  // Firestore requires a composite index for this query
  const snap = await db()
    .collection("products")
    .where("businessId", "==", businessId)
    .where("isActive", "==", true)
    .orderBy("quantity")
    .limit(20)
    .get();

  // Filter client-side to quantity <= reorderLevel
  const low = snap.docs
    .map((d) => d.data())
    .filter((p) => p.quantity <= p.reorderLevel);

  return { products: low };
});
