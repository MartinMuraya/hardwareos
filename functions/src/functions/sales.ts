// ============================================================
// Sales Functions — POS processing with stock validation
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

export interface SaleItem {
  productId: string;
  name: string;
  quantity: number;
  sellingPrice: number;
  costPrice: number;
}

// -----------------------------------------------------------
// createSale
// Full POS transaction:
//  1. Validate all items have sufficient stock
//  2. Calculate total + profit
//  3. Write sale document
//  4. Decrement stock for each item (transaction)
//  5. Log stock movement per item
// All steps atomic via Firestore transaction.
// -----------------------------------------------------------
export const createSale = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, items, paymentMethod, note } = request.data as {
    businessId: string;
    items: SaleItem[];
    paymentMethod: "cash" | "mpesa" | "credit";
    note?: string;
  };

  if (!items || items.length === 0) {
    throw new HttpsError("invalid-argument", "Sale must have at least one item.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);
  await assertActiveSubscription(businessId);

  // Run everything in a Firestore transaction for atomicity
  const result = await db().runTransaction(async (txn) => {
    // 1. Read all products
    const productRefs = items.map((item) =>
      db().collection("products").doc(item.productId)
    );
    const productSnaps = await Promise.all(productRefs.map((ref) => txn.get(ref)));

    let total = 0;
    let totalCost = 0;
    const validatedItems: SaleItem[] = [];

    for (let i = 0; i < items.length; i++) {
      const snap = productSnaps[i];
      const item = items[i];

      if (!snap.exists) {
        throw new HttpsError("not-found", `Product ${item.productId} not found.`);
      }

      const product = snap.data()!;

      if (product.businessId !== businessId) {
        throw new HttpsError("permission-denied", "Product does not belong to your business.");
      }

      if (product.quantity < item.quantity) {
        throw new HttpsError(
          "resource-exhausted",
          `Insufficient stock for "${product.name}". Available: ${product.quantity}, Requested: ${item.quantity}.`
        );
      }

      const lineTotal = product.sellingPrice * item.quantity;
      const lineCost = product.costPrice * item.quantity;

      total += lineTotal;
      totalCost += lineCost;

      validatedItems.push({
        productId: item.productId,
        name: product.name,
        quantity: item.quantity,
        sellingPrice: product.sellingPrice,
        costPrice: product.costPrice,
      });
    }

    const profit = total - totalCost;
    const now = admin.firestore.Timestamp.now();

    // 2. Create sale document
    const saleRef = db().collection("sales").doc();
    txn.set(saleRef, {
      id: saleRef.id,
      businessId,
      items: validatedItems,
      total: Number(total.toFixed(2)),
      totalCost: Number(totalCost.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      paymentMethod: paymentMethod || "cash",
      note: note || "",
      createdBy: request.auth!.uid,
      createdAt: now,
    });

    // 3. Decrement stock + log movements
    for (let i = 0; i < validatedItems.length; i++) {
      const item = validatedItems[i];

      // Decrement product quantity
      txn.update(productRefs[i], {
        quantity: admin.firestore.FieldValue.increment(-item.quantity),
        updatedAt: now,
      });

      // Log stock movement
      const movRef = db().collection("stockMovements").doc();
      txn.set(movRef, {
        id: movRef.id,
        businessId,
        productId: item.productId,
        type: "OUT",
        quantity: item.quantity,
        reason: "Sale",
        referenceId: saleRef.id,
        createdAt: now,
      });
    }

    return {
      saleId: saleRef.id,
      total: Number(total.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      itemCount: validatedItems.length,
    };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getSales
// Paginated sales history, ordered by createdAt desc.
// -----------------------------------------------------------
export const getSales = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 30, startAfter } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("sales")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("sales").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  // Wrap in object so Flutter's FunctionsService (Map cast) does not throw.
  return {
    sales: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});
