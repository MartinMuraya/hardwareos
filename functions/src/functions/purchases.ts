// ============================================================
// Purchase Functions — Stock purchasing from suppliers
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

export interface PurchaseItem {
  productId: string;
  name: string;
  quantity: number;
  costPrice: number;
}

// -----------------------------------------------------------
// createPurchase
// Records a supplier purchase and increases stock for each item.
// Also logs stock movements.
// -----------------------------------------------------------
export const createPurchase = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, supplierId, supplierName, items, note } = request.data as {
    businessId: string;
    supplierId?: string;
    supplierName?: string;
    items: PurchaseItem[];
    note?: string;
  };

  if (!items || items.length === 0) {
    throw new HttpsError("invalid-argument", "Purchase must have at least one item.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  let total = 0;
  const validatedItems: PurchaseItem[] = [];

  // Validate all products belong to business
  for (const item of items) {
    if (item.quantity <= 0) throw new HttpsError("invalid-argument", "Item quantity must be > 0.");
    const productSnap = await db().collection("products").doc(item.productId).get();
    if (!productSnap.exists || productSnap.data()!.businessId !== businessId) {
      throw new HttpsError("not-found", `Product ${item.productId} not found.`);
    }
    total += (item.costPrice || productSnap.data()!.costPrice) * item.quantity;
    validatedItems.push({
      productId: item.productId,
      name: productSnap.data()!.name,
      quantity: Math.floor(item.quantity),
      costPrice: Number(item.costPrice || productSnap.data()!.costPrice),
    });
  }

  const batch = db().batch();
  const now = admin.firestore.Timestamp.now();

  // Create purchase document
  const purchaseRef = db().collection("purchases").doc();
  batch.set(purchaseRef, {
    id: purchaseRef.id,
    businessId,
    supplierId: supplierId || null,
    supplierName: supplierName?.trim() || "Unknown Supplier",
    items: validatedItems,
    total: Number(total.toFixed(2)),
    note: note?.trim() || "",
    createdBy: request.auth.uid,
    createdAt: now,
  });

  // Update stock + log movements
  for (const item of validatedItems) {
    batch.update(db().collection("products").doc(item.productId), {
      quantity: admin.firestore.FieldValue.increment(item.quantity),
      updatedAt: now,
    });

    const movRef = db().collection("stockMovements").doc();
    batch.set(movRef, {
      id: movRef.id,
      businessId,
      productId: item.productId,
      type: "IN",
      quantity: item.quantity,
      reason: "Purchase",
      referenceId: purchaseRef.id,
      createdAt: now,
    });
  }

  await batch.commit();

  return { success: true, purchaseId: purchaseRef.id, total: Number(total.toFixed(2)) };
});

// -----------------------------------------------------------
// getPurchases
// -----------------------------------------------------------
export const getPurchases = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 30, startAfter } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("purchases")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("purchases").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  return {
    purchases: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});
