// ============================================================
// Purchase Order Functions — Full PO workflow
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// Helpers
// -----------------------------------------------------------
async function nextPONumber(businessId: string): Promise<string> {
  const ref = db().collection("purchase_order_numbers").doc(businessId);
  const result = await db().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    let counter = 1;
    if (snap.exists) {
      counter = (snap.data()!.counter || 0) + 1;
    }
    txn.set(ref, { counter, updatedAt: admin.firestore.Timestamp.now() });
    return counter;
  });
  return `PO-${String(result).padStart(5, "0")}`;
}

// -----------------------------------------------------------
// createPurchaseOrder
// -----------------------------------------------------------
export const createPurchaseOrder = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, supplierId, supplierName, items, notes } = request.data as {
    businessId: string;
    supplierId?: string;
    supplierName: string;
    items: { productId: string; name: string; quantity: number; unitCost: number }[];
    notes?: string;
  };

  if (!supplierName || !items || items.length === 0) {
    throw new HttpsError("invalid-argument", "Supplier name and at least one item are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const poNumber = await nextPONumber(businessId);

  let subtotal = 0;
  const validatedItems = items.map((item) => {
    const lineTotal = item.unitCost * item.quantity;
    subtotal += lineTotal;
    return {
      productId: item.productId || "",
      name: item.name,
      quantity: item.quantity,
      unitCost: item.unitCost,
      total: Number(lineTotal.toFixed(2)),
    };
  });

  const now = admin.firestore.Timestamp.now();
  const ref = db().collection("purchase_orders").doc();

  await ref.set({
    id: ref.id,
    businessId,
    poNumber,
    supplierId: supplierId || "",
    supplierName: supplierName.trim(),
    items: validatedItems,
    subtotal: Number(subtotal.toFixed(2)),
    total: Number(subtotal.toFixed(2)),
    status: "draft",
    notes: notes?.trim() || "",
    createdBy: request.auth!.uid,
    createdAt: now,
    updatedAt: now,
    receivedAt: null,
  });

  return { success: true, purchaseOrderId: ref.id, poNumber };
});

// -----------------------------------------------------------
// getPurchaseOrders
// -----------------------------------------------------------
export const getPurchaseOrders = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 50, startAfter, status } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
    status?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("purchase_orders")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (status) {
    query = query.where("status", "==", status);
  }

  if (startAfter) {
    const cursor = await db().collection("purchase_orders").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();

  return {
    purchaseOrders: snap.docs.map((d) => {
      const data = d.data();
      return {
        ...data,
        createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
        updatedAt: (data.updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
        receivedAt: data.receivedAt
          ? (data.receivedAt as admin.firestore.Timestamp).toDate().toISOString()
          : null,
      };
    }),
  };
});

// -----------------------------------------------------------
// getPurchaseOrder
// -----------------------------------------------------------
export const getPurchaseOrder = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, purchaseOrderId } = request.data as {
    businessId: string;
    purchaseOrderId: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db().collection("purchase_orders").doc(purchaseOrderId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Purchase order not found.");
  }
  const data = snap.data()!;
  if (data.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Purchase order does not belong to your business.");
  }

  return {
    purchaseOrder: {
      ...data,
      createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      updatedAt: (data.updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
      receivedAt: data.receivedAt
        ? (data.receivedAt as admin.firestore.Timestamp).toDate().toISOString()
        : null,
    },
  };
});

// -----------------------------------------------------------
// updatePurchaseOrderStatus
// -----------------------------------------------------------
export const updatePurchaseOrderStatus = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, purchaseOrderId, status } = request.data as {
    businessId: string;
    purchaseOrderId: string;
    status: "draft" | "sent" | "received" | "cancelled";
  };

  const validStatuses = ["draft", "sent", "received", "cancelled"];
  if (!validStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", `Invalid status. Must be one of: ${validStatuses.join(", ")}.`);
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const snap = await db().collection("purchase_orders").doc(purchaseOrderId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Purchase order not found.");
  }
  if (snap.data()!.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Purchase order does not belong to your business.");
  }

  const updates: Record<string, any> = { status, updatedAt: admin.firestore.Timestamp.now() };
  if (status === "received") {
    updates.receivedAt = admin.firestore.Timestamp.now();
  }

  await db().collection("purchase_orders").doc(purchaseOrderId).update(updates);

  return { success: true };
});

// -----------------------------------------------------------
// receivePurchaseOrder
// Full receiving workflow: add stock + log movements + update status.
// -----------------------------------------------------------
export const receivePurchaseOrder = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, purchaseOrderId } = request.data as {
    businessId: string;
    purchaseOrderId: string;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  await db().runTransaction(async (txn) => {
    const poSnap = await txn.get(db().collection("purchase_orders").doc(purchaseOrderId));
    if (!poSnap.exists) {
      throw new HttpsError("not-found", "Purchase order not found.");
    }

    const po = poSnap.data()!;
    if (po.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Purchase order does not belong to your business.");
    }
    if (po.status === "received") {
      throw new HttpsError("failed-precondition", "Purchase order has already been received.");
    }
    if (po.status === "cancelled") {
      throw new HttpsError("failed-precondition", "Cannot receive a cancelled purchase order.");
    }

    const now = admin.firestore.Timestamp.now();

    // Validate and update stock for each item
    for (const item of po.items) {
      if (!item.productId) continue;

      const prodSnap = await txn.get(db().collection("products").doc(item.productId));
      if (!prodSnap.exists) {
        throw new HttpsError("not-found", `Product "${item.name}" not found.`);
      }
      const prod = prodSnap.data()!;
      if (prod.businessId !== businessId) {
        throw new HttpsError("permission-denied", `Product "${item.name}" does not belong to your business.`);
      }

      // Increase stock
      txn.update(prodSnap.ref, {
        quantity: admin.firestore.FieldValue.increment(item.quantity),
        updatedAt: now,
      });

      // Log stock movement
      const movRef = db().collection("stockMovements").doc();
      txn.set(movRef, {
        id: movRef.id,
        businessId,
        productId: item.productId,
        type: "IN",
        quantity: item.quantity,
        reason: "Purchase Order",
        referenceId: purchaseOrderId,
        createdAt: now,
      });
    }

    // Update PO status
    txn.update(poSnap.ref, {
      status: "received",
      receivedAt: now,
      updatedAt: now,
    });

    // Update supplier balance if supplier exists
    if (po.supplierId) {
      const supRef = db().collection("suppliers").doc(po.supplierId);
      const supSnap = await txn.get(supRef);
      if (supSnap.exists) {
        const currentBalance = (supSnap.data()!.currentBalance || 0) + po.total;
        txn.update(supRef, {
          currentBalance: Number(currentBalance.toFixed(2)),
          updatedAt: now,
        });
      }
    }

    return;
  });

  return { success: true };
});
