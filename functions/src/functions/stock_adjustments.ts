// ============================================================
// Stock Adjustments — Reconcile inventory for damage, loss, expiry, etc.
// Only owner/manager can adjust; staff view only.
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// adjustInventoryStock
// Atomically: validate → create adjustment → update stock → audit log
// -----------------------------------------------------------
export const adjustInventoryStock = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, productId, newQty, reason, notes } = request.data as {
    businessId: string;
    productId: string;
    newQty: number;
    reason: string;
    notes?: string;
  };

  if (!productId || newQty === undefined || newQty < 0 || !reason) {
    throw new HttpsError("invalid-argument", "productId, non-negative newQty, and reason are required.");
  }

  const validReasons = ["Damaged", "Lost", "Expired", "Stolen", "Physical Count", "Returned", "Other"];
  if (!validReasons.includes(reason)) {
    throw new HttpsError("invalid-argument", `Reason must be one of: ${validReasons.join(", ")}`);
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  // Fetch user profile for name
  const userSnap = await db().collection("users").doc(request.auth.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";

  const result = await db().runTransaction(async (txn) => {
    const prodSnap = await txn.get(db().collection("products").doc(productId));
    if (!prodSnap.exists) {
      throw new HttpsError("not-found", "Product not found.");
    }
    const product = prodSnap.data()!;
    if (product.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Product does not belong to your business.");
    }

    const previousQty = (product.quantity as number) || 0;
    const difference = newQty - previousQty;
    const now = admin.firestore.Timestamp.now();

    // 1. Create adjustment record
    const adjRef = db().collection("stockAdjustments").doc();
    txn.set(adjRef, {
      id: adjRef.id,
      businessId,
      productId,
      productName: product.name,
      previousQty,
      newQty: Math.floor(newQty),
      difference,
      reason,
      notes: notes?.trim() || "",
      adjustedBy: request.auth!.uid,
      adjustedByName: userName,
      createdAt: now,
    });

    // 2. Update product quantity
    txn.update(db().collection("products").doc(productId), {
      quantity: Math.floor(newQty),
      updatedAt: now,
    });

    // 3. Log stock movement
    const movRef = db().collection("stockMovements").doc();
    txn.set(movRef, {
      id: movRef.id,
      businessId,
      productId,
      type: difference >= 0 ? "IN" : "OUT",
      quantity: Math.abs(difference),
      reason: `Adjustment: ${reason}`,
      referenceId: adjRef.id,
      createdAt: now,
    });

    // 4. Create audit trail
    const auditRef = db().collection("auditLogs").doc();
    txn.set(auditRef, {
      id: auditRef.id,
      businessId,
      userId: request.auth!.uid,
      userName,
      module: "Inventory",
      action: "Stock Adjustment",
      entityId: productId,
      entityName: product.name,
      oldValues: { quantity: previousQty },
      newValues: { quantity: newQty, reason },
      metadata: { adjustmentId: adjRef.id, difference },
      createdAt: now,
    });

    return {
      adjustmentId: adjRef.id,
      previousQty,
      newQty: Math.floor(newQty),
      difference,
    };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getStockAdjustments
// Paginated adjustment history, newest first.
// -----------------------------------------------------------
export const getStockAdjustments = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 50, startAfter } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("stockAdjustments")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("stockAdjustments").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  return {
    adjustments: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});

// -----------------------------------------------------------
// getAdjustmentStats
// Today's adjustment count and value (for dashboard KPIs).
// -----------------------------------------------------------
export const getAdjustmentStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  try {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfDayTs = admin.firestore.Timestamp.fromDate(startOfDay);

    const snap = await db()
      .collection("stockAdjustments")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", startOfDayTs)
      .get();

    let totalAdjustmentsToday = 0;
    let totalValue = 0;

    // To get value, need product prices — batch query all product IDs
    const productIds = [...new Set(snap.docs.map((d) => d.data().productId))];
    if (productIds.length > 0) {
      // Firestore 'in' query up to 30
      const chunks: string[][] = [];
      for (let i = 0; i < productIds.length; i += 30) {
        chunks.push(productIds.slice(i, i + 30));
      }
      const priceMap: Record<string, number> = {};
      for (const chunk of chunks) {
        const prodSnap = await db()
          .collection("products")
          .where("businessId", "==", businessId)
          .where("__name__", "in", chunk)
          .get();
        prodSnap.docs.forEach((d) => {
          priceMap[d.id] = d.data().sellingPrice || 0;
        });
      }

      snap.docs.forEach((d) => {
        const data = d.data();
        totalAdjustmentsToday++;
        const diff = Math.abs(data.difference || 0);
        totalValue += diff * (priceMap[data.productId] || 0);
      });
    }

    return {
      totalAdjustmentsToday,
      totalAdjustmentValueToday: Number(totalValue.toFixed(2)),
    };
  } catch (e) {
    return { totalAdjustmentsToday: 0, totalAdjustmentValueToday: 0 };
  }
});
