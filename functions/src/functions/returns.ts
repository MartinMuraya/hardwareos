// ============================================================
// Returns & Refunds — Process customer returns with financial integrity
// Only owner/manager can process returns; staff view only.
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

const validReasons = ["Damaged", "Wrong Item", "Defective Product", "Customer Changed Mind", "Duplicate Sale", "Other"];

// -----------------------------------------------------------
// processReturn
// Atomically: validate → restore stock → create return → update reports → audit
// -----------------------------------------------------------
export const processReturn = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, saleId, items, reason, notes } = request.data as {
    businessId: string;
    saleId: string;
    items: { productId: string; name: string; quantity: number; sellingPrice: number; costPrice: number }[];
    reason: string;
    notes?: string;
  };

  if (!saleId || !items || items.length === 0 || !reason) {
    throw new HttpsError("invalid-argument", "saleId, items, and reason are required.");
  }

  if (!validReasons.includes(reason)) {
    throw new HttpsError("invalid-argument", `Reason must be one of: ${validReasons.join(", ")}`);
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  // Fetch user profile for name
  const userSnap = await db().collection("users").doc(request.auth.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";

  const result = await db().runTransaction(async (txn) => {
    // 1. Validate original sale
    const saleSnap = await txn.get(db().collection("sales").doc(saleId));
    if (!saleSnap.exists) {
      throw new HttpsError("not-found", "Sale not found.");
    }
    const sale = saleSnap.data()!;
    if (sale.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Sale does not belong to your business.");
    }
    if (sale.cancelled) {
      throw new HttpsError("failed-precondition", "Cannot process return on a cancelled sale.");
    }

    // 2. Validate return quantities against original sale
    const saleItems: { productId: string; name: string; quantity: number; sellingPrice: number }[] = sale.items || [];
    const subtotal = 0;
    let refundAmount = 0;
    const validatedItems: any[] = [];

    for (const returnItem of items) {
      const origItem = saleItems.find((si: any) => si.productId === returnItem.productId);
      if (!origItem) {
        throw new HttpsError("not-found", `Item "${returnItem.name}" not found in original sale.`);
      }
      if (returnItem.quantity <= 0 || returnItem.quantity > origItem.quantity) {
        throw new HttpsError(
          "invalid-argument",
          `Invalid return quantity for "${origItem.name}". Sold: ${origItem.quantity}, Returning: ${returnItem.quantity}.`
        );
      }
      refundAmount += returnItem.sellingPrice * returnItem.quantity;
      validatedItems.push({
        productId: returnItem.productId,
        name: origItem.name,
        quantity: returnItem.quantity,
        sellingPrice: origItem.sellingPrice,
        costPrice: returnItem.costPrice,
      });
    }

    const now = admin.firestore.Timestamp.now();

    // 3. Create return record
    const returnRef = db().collection("returns").doc();
    const customerId = sale.customerId || "";
    const customerName = sale.customerName || "";

    txn.set(returnRef, {
      id: returnRef.id,
      businessId,
      saleId,
      customerId,
      customerName,
      items: validatedItems,
      subtotal: Number(subtotal.toFixed(2)),
      refundAmount: Number(refundAmount.toFixed(2)),
      reason,
      notes: notes?.trim() || "",
      processedBy: request.auth!.uid,
      processedByName: userName,
      createdAt: now,
    });

    // 4. Restore inventory for each returned item
    for (const item of validatedItems) {
      const prodRef = db().collection("products").doc(item.productId);
      txn.update(prodRef, {
        quantity: admin.firestore.FieldValue.increment(item.quantity),
        updatedAt: now,
      });

      // Stock movement (IN = returned to stock)
      const movRef = db().collection("stockMovements").doc();
      txn.set(movRef, {
        id: movRef.id,
        businessId,
        productId: item.productId,
        type: "IN",
        quantity: item.quantity,
        reason: `Return: ${reason}`,
        referenceId: returnRef.id,
        createdAt: now,
      });
    }

    // 5. Update sale — mark as having returns
    txn.update(db().collection("sales").doc(saleId), {
      totalReturned: admin.firestore.FieldValue.increment(refundAmount),
      updatedAt: now,
    });

    // 6. Create audit trail
    const auditRef = db().collection("auditLogs").doc();
    txn.set(auditRef, {
      id: auditRef.id,
      businessId,
      userId: request.auth!.uid,
      userName,
      module: "Sales",
      action: "Process Return",
      entityId: returnRef.id,
      entityName: `Return on ${saleId}`,
      oldValues: {},
      newValues: { reason, refundAmount, items: validatedItems.length },
      metadata: { saleId, returnId: returnRef.id, customerId },
      createdAt: now,
    });

    return {
      returnId: returnRef.id,
      refundAmount: Number(refundAmount.toFixed(2)),
      itemsReturned: validatedItems.length,
    };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getReturns
// Paginated returns list, newest first.
// -----------------------------------------------------------
export const getReturns = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 50, startAfter } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("returns")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("returns").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  return {
    returns: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});

// -----------------------------------------------------------
// getReturnStats — Today's return count + refund amount (dashboard)
// -----------------------------------------------------------
export const getReturnStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  try {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfDayTs = admin.firestore.Timestamp.fromDate(startOfDay);

    const snap = await db()
      .collection("returns")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", startOfDayTs)
      .get();

    let returnsToday = 0;
    let refundAmountToday = 0;

    snap.docs.forEach((d) => {
      const data = d.data();
      returnsToday++;
      refundAmountToday += data.refundAmount || 0;
    });

    return {
      returnsToday,
      refundAmountToday: Number(refundAmountToday.toFixed(2)),
    };
  } catch (e) {
    return { returnsToday: 0, refundAmountToday: 0 };
  }
});
