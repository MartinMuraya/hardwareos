// ============================================================
// Purchase Functions — Stock purchasing from suppliers
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";
import { recordInventoryMovement, MovementType } from "./inventory_ledger";

const db = () => admin.firestore();

export interface PurchaseItem {
  productId: string;
  name: string;
  quantity: number;
  costPrice: number;
  batchNumber?: string;
  expiryDate?: string;
  serialNumbers?: string[];
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
      batchNumber: item.batchNumber?.trim(),
      expiryDate: item.expiryDate?.trim(),
      serialNumbers: item.serialNumbers?.filter(s => s.trim().length > 0),
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

    if (item.batchNumber) {
      const batchRef = db().collection("product_batches").doc(`${item.productId}_${item.batchNumber}`);
      batch.set(batchRef, {
        id: batchRef.id,
        businessId,
        productId: item.productId,
        batchNumber: item.batchNumber,
        supplierId: supplierId || null,
        supplierName: supplierName?.trim() || "Unknown",
        purchaseCost: item.costPrice,
        quantityRemaining: admin.firestore.FieldValue.increment(item.quantity),
        expiryDate: item.expiryDate || null,
        createdAt: now,
        updatedAt: now,
      }, { merge: true });
    }

    if (item.serialNumbers && item.serialNumbers.length > 0) {
      if (item.serialNumbers.length !== item.quantity) {
        throw new HttpsError("invalid-argument", `Provided ${item.serialNumbers.length} serials but quantity is ${item.quantity} for product ${item.name}.`);
      }
      for (const serial of item.serialNumbers) {
        const serialRef = db().collection("product_serials").doc(`${item.productId}_${serial}`);
        batch.set(serialRef, {
          id: serialRef.id,
          businessId,
          productId: item.productId,
          serialNumber: serial,
          status: "Available",
          purchaseId: purchaseRef.id,
          createdAt: now,
          updatedAt: now,
        }, { merge: true }); // Merge in case it was a previously returned serial
      }
    }

    recordInventoryMovement(batch, {
      businessId,
      productId: item.productId,
      productName: item.name,
      movementType: MovementType.PURCHASE,
      quantity: item.quantity,
      costAtTime: item.costPrice,
      referenceId: purchaseRef.id,
      performedBy: request.auth!.uid,
      batchNumber: item.batchNumber,
      serialNumbers: item.serialNumbers,
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
