// ============================================================
// Quotation / Proforma Functions
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// Helpers
// -----------------------------------------------------------
async function nextQuotationNumber(businessId: string): Promise<string> {
  const ref = db().collection("quotation_numbers").doc(businessId);
  const result = await db().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    let counter = 1;
    if (snap.exists) {
      counter = (snap.data()!.counter || 0) + 1;
    }
    txn.set(ref, { counter, updatedAt: admin.firestore.Timestamp.now() });
    return counter;
  });
  return `QT-${String(result).padStart(5, "0")}`;
}

// -----------------------------------------------------------
// createQuotation
// -----------------------------------------------------------
export const createQuotation = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const {
    businessId,
    customerId,
    customerName,
    customerPhone,
    items,
    discount,
    discountType,
    validUntil,
    notes,
    terms,
  } = request.data as {
    businessId: string;
    customerId?: string;
    customerName: string;
    customerPhone?: string;
    items: { productId: string; name: string; quantity: number; unitPrice: number }[];
    discount?: number;
    discountType?: "percentage" | "fixed";
    validUntil?: string;
    notes?: string;
    terms?: string;
  };

  if (!customerName || !items || items.length === 0) {
    throw new HttpsError("invalid-argument", "Customer name and at least one item are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);
  await assertActiveSubscription(businessId);

  const quotationNumber = await nextQuotationNumber(businessId);

  let subtotal = 0;
  const validatedItems = items.map((item) => {
    const lineTotal = item.unitPrice * item.quantity;
    subtotal += lineTotal;
    return {
      productId: item.productId || "",
      name: item.name,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      total: Number(lineTotal.toFixed(2)),
    };
  });

  const discPct = discountType === "percentage" ? (discount || 0) : 0;
  const discFixed = discountType === "fixed" ? (discount || 0) : 0;
  const discountAmount = discPct > 0 ? (subtotal * discPct) / 100 : discFixed;
  const total = Math.max(0, subtotal - discountAmount);

  const now = admin.firestore.Timestamp.now();
  const ref = db().collection("quotations").doc();

  await ref.set({
    id: ref.id,
    businessId,
    quotationNumber,
    customerId: customerId || "",
    customerName: customerName.trim(),
    customerPhone: customerPhone?.trim() || "",
    items: validatedItems,
    subtotal: Number(subtotal.toFixed(2)),
    discount: discount || 0,
    discountType: discountType || "fixed",
    discountAmount: Number(discountAmount.toFixed(2)),
    total: Number(total.toFixed(2)),
    status: "draft",
    validUntil: validUntil ? admin.firestore.Timestamp.fromDate(new Date(validUntil)) : null,
    notes: notes?.trim() || "",
    terms: terms?.trim() || "Payment due within 30 days.",
    createdBy: request.auth!.uid,
    createdAt: now,
    updatedAt: now,
  });

  return { success: true, quotationId: ref.id, quotationNumber };
});

// -----------------------------------------------------------
// getQuotations
// -----------------------------------------------------------
export const getQuotations = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 50, startAfter, status } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
    status?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  try {
    let query: admin.firestore.Query = db()
      .collection("quotations")
      .where("businessId", "==", businessId)
      .orderBy("createdAt", "desc")
      .limit(Math.min(pageLimit, 100));

    if (status) {
      query = query.where("status", "==", status);
    }

    if (startAfter) {
      const cursor = await db().collection("quotations").doc(startAfter).get();
      if (cursor.exists) query = query.startAfter(cursor);
    }

    const snap = await query.get();

    return {
      quotations: snap.docs.map((d) => {
        const data = d.data();
        return {
          ...data,
          createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
          updatedAt: (data.updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
          validUntil: data.validUntil
            ? (data.validUntil as admin.firestore.Timestamp).toDate().toISOString()
            : null,
        };
      }),
    };
  } catch (e) {
    return { quotations: [] };
  }
});

// -----------------------------------------------------------
// getQuotation
// -----------------------------------------------------------
export const getQuotation = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, quotationId } = request.data as {
    businessId: string;
    quotationId: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db().collection("quotations").doc(quotationId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Quotation not found.");
  }

  const data = snap.data()!;
  if (data.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Quotation does not belong to your business.");
  }

  return {
    quotation: {
      ...data,
      createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      updatedAt: (data.updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
      validUntil: data.validUntil
        ? (data.validUntil as admin.firestore.Timestamp).toDate().toISOString()
        : null,
    },
  };
});

// -----------------------------------------------------------
// updateQuotationStatus
// -----------------------------------------------------------
export const updateQuotationStatus = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, quotationId, status } = request.data as {
    businessId: string;
    quotationId: string;
    status: "draft" | "sent" | "accepted" | "rejected" | "converted";
  };

  const validStatuses = ["draft", "sent", "accepted", "rejected", "converted"];
  if (!validStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", `Invalid status. Must be one of: ${validStatuses.join(", ")}.`);
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const snap = await db().collection("quotations").doc(quotationId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Quotation not found.");
  }
  if (snap.data()!.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Quotation does not belong to your business.");
  }

  await db().collection("quotations").doc(quotationId).update({
    status,
    updatedAt: admin.firestore.Timestamp.now(),
  });

  return { success: true };
});

// -----------------------------------------------------------
// convertQuotationToSale
// Converts an accepted quotation into a sale.
// -----------------------------------------------------------
export const convertQuotationToSale = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, quotationId, paymentMethod } = request.data as {
    businessId: string;
    quotationId: string;
    paymentMethod: "cash" | "mpesa" | "credit";
  };

  if (!paymentMethod) {
    throw new HttpsError("invalid-argument", "Payment method is required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const result = await db().runTransaction(async (txn) => {
    const qtSnap = await txn.get(db().collection("quotations").doc(quotationId));
    if (!qtSnap.exists) {
      throw new HttpsError("not-found", "Quotation not found.");
    }

    const qt = qtSnap.data()!;
    if (qt.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Quotation does not belong to your business.");
    }
    if (qt.status !== "accepted") {
      throw new HttpsError("failed-precondition", "Only accepted quotations can be converted to sales.");
    }

    // Validate stock for each item
    const saleItems: any[] = [];
    let total = 0;
    let totalCost = 0;

    for (const item of qt.items) {
      if (!item.productId) continue;
      const prodSnap = await txn.get(db().collection("products").doc(item.productId));
      if (!prodSnap.exists) {
        throw new HttpsError("not-found", `Product "${item.name}" not found.`);
      }
      const prod = prodSnap.data()!;
      if (prod.businessId !== businessId) {
        throw new HttpsError("permission-denied", `Product "${item.name}" does not belong to your business.`);
      }
      if (prod.quantity < item.quantity) {
        throw new HttpsError(
          "resource-exhausted",
          `Insufficient stock for "${prod.name}". Available: ${prod.quantity}, Requested: ${item.quantity}.`
        );
      }

      total += prod.sellingPrice * item.quantity;
      totalCost += prod.costPrice * item.quantity;

      saleItems.push({
        productId: item.productId,
        name: prod.name,
        quantity: item.quantity,
        sellingPrice: prod.sellingPrice,
        costPrice: prod.costPrice,
      });

      // Decrement stock
      const now = admin.firestore.Timestamp.now();
      txn.update(prodSnap.ref, {
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
        reason: "Sale from Quotation",
        referenceId: quotationId,
        createdAt: now,
      });
    }

    const profit = total - totalCost;
    const now = admin.firestore.Timestamp.now();

    // Create sale document
    const saleRef = db().collection("sales").doc();
    txn.set(saleRef, {
      id: saleRef.id,
      businessId,
      quotationId,
      quotationNumber: qt.quotationNumber,
      customerId: qt.customerId || "",
      customerName: qt.customerName,
      items: saleItems,
      total: Number(total.toFixed(2)),
      totalCost: Number(totalCost.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      paymentMethod,
      amountPaid: Number(total.toFixed(2)),
      outstanding: 0,
      note: `From quotation ${qt.quotationNumber}`,
      createdBy: request.auth!.uid,
      createdAt: now,
    });

    // Update quotation status
    txn.update(qtSnap.ref, {
      status: "converted",
      updatedAt: now,
    });

    return {
      saleId: saleRef.id,
      total: Number(total.toFixed(2)),
      profit: Number(profit.toFixed(2)),
    };
  });

  return { success: true, ...result };
});
