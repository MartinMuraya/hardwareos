// ============================================================
// Debt Functions — Credit sales, payments, ledger, statements
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// createCreditSale
// Full credit sale with optional partial payment.
// Flow:
//  1. Validate stock (same as createSale)
//  2. Create sale document
//  3. Decrement stock + log movements
//  4. Create debt transaction for outstanding balance
//  5. Update customer balance
//  6. Record payment if partial amount received
// -----------------------------------------------------------
export const createCreditSale = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, customerId, customerName, items, amountPaid, note } = request.data as {
    businessId: string;
    customerId: string;
    customerName: string;
    items: { productId: string; name: string; quantity: number; sellingPrice: number; costPrice: number }[];
    amountPaid?: number;
    note?: string;
  };

  if (!customerId || !items || items.length === 0) {
    throw new HttpsError("invalid-argument", "Customer and at least one item are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);
  await assertActiveSubscription(businessId);

  const result = await db().runTransaction(async (txn) => {
    // 1. Validate customer exists and belongs to business
    const custSnap = await txn.get(db().collection("customers").doc(customerId));
    if (!custSnap.exists) {
      throw new HttpsError("not-found", "Customer not found.");
    }
    const customer = custSnap.data()!;
    if (customer.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Customer does not belong to your business.");
    }

    // 2. Validate stock for all items
    const productRefs = items.map((item) => db().collection("products").doc(item.productId));
    const productSnaps = await Promise.all(productRefs.map((ref) => txn.get(ref)));

    let total = 0;
    let totalCost = 0;
    const validatedItems: any[] = [];

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

      total += product.sellingPrice * item.quantity;
      totalCost += product.costPrice * item.quantity;

      validatedItems.push({
        productId: item.productId,
        name: product.name,
        quantity: item.quantity,
        sellingPrice: product.sellingPrice,
        costPrice: product.costPrice,
      });
    }

    const profit = total - totalCost;
    const paid = Math.min(amountPaid ?? 0, total);
    const outstanding = total - paid;
    const now = admin.firestore.Timestamp.now();

    // 3. Create sale document
    const saleRef = db().collection("sales").doc();
    txn.set(saleRef, {
      id: saleRef.id,
      businessId,
      customerId,
      customerName,
      items: validatedItems,
      total: Number(total.toFixed(2)),
      totalCost: Number(totalCost.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      paymentMethod: outstanding > 0 ? "credit" : "cash",
      amountPaid: Number(paid.toFixed(2)),
      outstanding: Number(outstanding.toFixed(2)),
      note: note || "",
      createdBy: request.auth!.uid,
      createdAt: now,
    });

    // 4. Decrement stock + log movements
    for (let i = 0; i < validatedItems.length; i++) {
      const item = validatedItems[i];
      txn.update(productRefs[i], {
        quantity: admin.firestore.FieldValue.increment(-item.quantity),
        updatedAt: now,
      });

      const movRef = db().collection("stockMovements").doc();
      txn.set(movRef, {
        id: movRef.id,
        businessId,
        productId: item.productId,
        type: "OUT",
        quantity: item.quantity,
        reason: "Credit Sale",
        referenceId: saleRef.id,
        createdAt: now,
      });
    }

    // 5. Record payment if partial amount received
    if (paid > 0) {
      const payRef = db().collection("debtPayments").doc();
      txn.set(payRef, {
        id: payRef.id,
        businessId,
        customerId,
        customerName,
        saleId: saleRef.id,
        amount: Number(paid.toFixed(2)),
        type: "partial_payment",
        createdAt: now,
      });
    }

    // 6. Create debt transaction
    const prevBalance = customer.currentBalance || 0;
    const newBalance = prevBalance + outstanding;
    const txRef = db().collection("debtTransactions").doc();
    txn.set(txRef, {
      id: txRef.id,
      businessId,
      customerId,
      customerName,
      type: "credit_sale",
      amount: Number(outstanding.toFixed(2)),
      referenceId: saleRef.id,
      previousBalance: Number(prevBalance.toFixed(2)),
      newBalance: Number(newBalance.toFixed(2)),
      note: paid > 0
        ? `Credit sale KES ${total.toFixed(2)} with KES ${paid.toFixed(2)} deposit`
        : `Credit sale KES ${total.toFixed(2)}`,
      createdAt: now,
    });

    // 7. Update customer balance
    txn.update(db().collection("customers").doc(customerId), {
      currentBalance: Number(newBalance.toFixed(2)),
      totalDebt: Number(newBalance.toFixed(2)),
      updatedAt: now,
    });

    return {
      saleId: saleRef.id,
      total: Number(total.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      amountPaid: Number(paid.toFixed(2)),
      outstanding: Number(outstanding.toFixed(2)),
      itemCount: validatedItems.length,
    };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// recordDebtPayment
// Record a payment against a customer's outstanding debt.
// -----------------------------------------------------------
export const recordDebtPayment = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, customerId, amount, note } = request.data as {
    businessId: string;
    customerId: string;
    amount: number;
    note?: string;
  };

  if (!customerId || !amount || amount <= 0) {
    throw new HttpsError("invalid-argument", "Customer and positive amount are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const result = await db().runTransaction(async (txn) => {
    const custSnap = await txn.get(db().collection("customers").doc(customerId));
    if (!custSnap.exists) {
      throw new HttpsError("not-found", "Customer not found.");
    }

    const customer = custSnap.data()!;
    if (customer.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Customer does not belong to your business.");
    }

    const prevBalance = customer.currentBalance || 0;
    const newBalance = Math.max(0, prevBalance - amount);
    const now = admin.firestore.Timestamp.now();

    // Create payment record
    const payRef = db().collection("debtPayments").doc();
    txn.set(payRef, {
      id: payRef.id,
      businessId,
      customerId,
      customerName: customer.fullName,
      amount: Number(amount.toFixed(2)),
      type: "direct_payment",
      note: note?.trim() || "",
      createdAt: now,
    });

    // Create debt transaction (negative amount = decrease)
    const txRef = db().collection("debtTransactions").doc();
    txn.set(txRef, {
      id: txRef.id,
      businessId,
      customerId,
      customerName: customer.fullName,
      type: "debt_payment",
      amount: Number((-amount).toFixed(2)),
      referenceId: payRef.id,
      previousBalance: Number(prevBalance.toFixed(2)),
      newBalance: Number(newBalance.toFixed(2)),
      note: note?.trim() || "Debt payment",
      createdAt: now,
    });

    // Update customer balance
    txn.update(db().collection("customers").doc(customerId), {
      currentBalance: Number(newBalance.toFixed(2)),
      totalDebt: Number(newBalance.toFixed(2)),
      updatedAt: now,
    });

    return {
      paymentId: payRef.id,
      previousBalance: Number(prevBalance.toFixed(2)),
      newBalance: Number(newBalance.toFixed(2)),
    };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// adjustDebt
// Manually adjust a customer's debt (for corrections).
// -----------------------------------------------------------
export const adjustDebt = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, customerId, amount, reason } = request.data as {
    businessId: string;
    customerId: string;
    amount: number; // positive = increase debt, negative = decrease
    reason: string;
  };

  if (!customerId || amount === 0 || !reason) {
    throw new HttpsError("invalid-argument", "Customer, non-zero amount, and reason are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);
  await assertActiveSubscription(businessId);

  const result = await db().runTransaction(async (txn) => {
    const custSnap = await txn.get(db().collection("customers").doc(customerId));
    if (!custSnap.exists) {
      throw new HttpsError("not-found", "Customer not found.");
    }

    const customer = custSnap.data()!;
    if (customer.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Customer does not belong to your business.");
    }

    const prevBalance = customer.currentBalance || 0;
    const newBalance = Math.max(0, prevBalance + amount);
    const now = admin.firestore.Timestamp.now();

    const txRef = db().collection("debtTransactions").doc();
    txn.set(txRef, {
      id: txRef.id,
      businessId,
      customerId,
      customerName: customer.fullName,
      type: "debt_adjustment",
      amount: Number(amount.toFixed(2)),
      referenceId: "",
      previousBalance: Number(prevBalance.toFixed(2)),
      newBalance: Number(newBalance.toFixed(2)),
      note: reason.trim(),
      createdAt: now,
    });

    txn.update(db().collection("customers").doc(customerId), {
      currentBalance: Number(newBalance.toFixed(2)),
      totalDebt: Number(newBalance.toFixed(2)),
      updatedAt: now,
    });

    return { previousBalance: Number(prevBalance.toFixed(2)), newBalance: Number(newBalance.toFixed(2)) };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getDebtTransactions
// Paginated debt transactions for a customer.
// -----------------------------------------------------------
export const getDebtTransactions = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, customerId, limit: pageLimit = 50, startAfter } = request.data as {
    businessId: string;
    customerId: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("debtTransactions")
    .where("businessId", "==", businessId)
    .where("customerId", "==", customerId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("debtTransactions").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();

  return {
    transactions: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});

// -----------------------------------------------------------
// getCustomerStatement
// Full statement: opening balance + transactions + current balance.
// -----------------------------------------------------------
export const getCustomerStatement = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, customerId } = request.data as {
    businessId: string;
    customerId: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  // Fetch customer
  const custSnap = await db().collection("customers").doc(customerId).get();
  if (!custSnap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }
  const customer = custSnap.data()!;
  if (customer.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Customer does not belong to your business.");
  }

  // Fetch all transactions
  const txSnap = await db()
    .collection("debtTransactions")
    .where("businessId", "==", businessId)
    .where("customerId", "==", customerId)
    .orderBy("createdAt", "asc")
    .get();

  const transactions = txSnap.docs.map((d) => ({
    ...d.data(),
    createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
  }));

  const totalDebt = transactions
    .filter((t: any) => t.type === "credit_sale")
    .reduce((sum: number, t: any) => sum + Math.abs(t.amount), 0);

  const totalPaid = transactions
    .filter((t: any) => t.type === "debt_payment")
    .reduce((sum: number, t: any) => sum + Math.abs(t.amount), 0);

  return {
    customer: {
      ...customer,
      createdAt: (customer.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      updatedAt: (customer.updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
    },
    transactions,
    summary: {
      totalTransactions: transactions.length,
      totalDebt: Number(totalDebt.toFixed(2)),
      totalPaid: Number(totalPaid.toFixed(2)),
      currentBalance: Number((customer.currentBalance || 0).toFixed(2)),
    },
  };
});

// -----------------------------------------------------------
// getDebtDashboard
// Aggregated debt metrics for the dashboard.
// -----------------------------------------------------------
export const getDebtDashboard = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  // Fetch all customers with debt
  const custSnap = await db()
    .collection("customers")
    .where("businessId", "==", businessId)
    .where("currentBalance", ">", 0)
    .orderBy("currentBalance", "desc")
    .limit(10)
    .get();

  const topDebtors = custSnap.docs.map((d) => {
    const data = d.data();
    return {
      id: data.id,
      fullName: data.fullName,
      phoneNumber: data.phoneNumber,
      currentBalance: data.currentBalance,
      creditLimit: data.creditLimit,
    };
  });

  // Compute total outstanding
  const totalOutstanding = topDebtors.reduce((sum, d) => sum + (d.currentBalance || 0), 0);

  // Count overdue accounts (balance > creditLimit where creditLimit > 0)
  const overdueCount = custSnap.docs.filter((d) => {
    const data = d.data();
    return data.creditLimit > 0 && data.currentBalance > data.creditLimit;
  }).length;

  // Get total customer count
  const totalCustSnap = await db()
    .collection("customers")
    .where("businessId", "==", businessId)
    .count()
    .get();
  const totalCustomers = totalCustSnap.data().count;

  return {
    totalOutstanding: Number(totalOutstanding.toFixed(2)),
    topDebtors,
    overdueCount,
    totalCustomers,
  };
});
