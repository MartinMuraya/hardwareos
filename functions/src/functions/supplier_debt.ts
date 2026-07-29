import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// recordSupplierPayment
// Records a full or partial payment towards a supplier debt.
// -----------------------------------------------------------
export const recordSupplierPayment = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, supplierDebtId, amount, paymentMethod, referenceCode, note } = request.data as {
    businessId: string;
    supplierDebtId: string;
    amount: number;
    paymentMethod: "cash" | "mpesa" | "bank_transfer";
    referenceCode?: string;
    note?: string;
  };

  if (!businessId || !supplierDebtId || !amount || amount <= 0) {
    throw new HttpsError("invalid-argument", "businessId, supplierDebtId, and valid amount required.");
  }

  await assertActiveSubscription(businessId);
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const result = await db().runTransaction(async (txn) => {
    const debtRef = db().collection("supplierDebts").doc(supplierDebtId);
    const debtSnap = await txn.get(debtRef);

    if (!debtSnap.exists) {
      throw new HttpsError("not-found", "Supplier debt record not found.");
    }

    const debtData = debtSnap.data()!;
    if (debtData.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Unauthorized business access.");
    }

    const currentOutstanding = (debtData.outstanding as number) || (debtData.totalAmount - debtData.amountPaid);
    if (currentOutstanding <= 0) {
      throw new HttpsError("failed-precondition", "Debt is already fully settled.");
    }

    const newAmountPaid = (debtData.amountPaid as number) + amount;
    const newOutstanding = Math.max(0, debtData.totalAmount - newAmountPaid);
    const newStatus = newOutstanding === 0 ? "paid" : "partial";

    const now = admin.firestore.FieldValue.serverTimestamp();

    // Update supplier debt record
    txn.update(debtRef, {
      amountPaid: newAmountPaid,
      outstanding: newOutstanding,
      status: newStatus,
      updatedAt: now,
    });

    // Update supplier's current balance
    const supplierRef = db().collection("suppliers").doc(debtData.supplierId);
    txn.update(supplierRef, {
      currentBalance: admin.firestore.FieldValue.increment(-amount),
      updatedAt: now,
    });

    // Record payment ledger entry
    const pmtRef = db().collection("supplierPaymentHistory").doc();
    txn.set(pmtRef, {
      id: pmtRef.id,
      businessId,
      supplierDebtId,
      supplierId: debtData.supplierId,
      supplierName: debtData.supplierName,
      amount,
      paymentMethod: paymentMethod || "cash",
      referenceCode: referenceCode || "",
      note: note || "",
      recordedBy: request.auth!.uid,
      createdAt: now,
    });

    return {
      success: true,
      newAmountPaid,
      newOutstanding,
      newStatus,
    };
  });

  return result;
});

// -----------------------------------------------------------
// getSupplierDebts
// -----------------------------------------------------------
export const getSupplierDebts = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const snap = await db()
    .collection("supplierDebts")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(100)
    .get();

  const debts = snap.docs.map((doc) => {
    const data = doc.data();
    return {
      ...data,
      createdAt: (data.createdAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
      paymentDueDate: (data.paymentDueDate as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
    };
  });

  return { debts };
});

// -----------------------------------------------------------
// getSupplierDebtDashboard
// Returns summary statistics of supplier payables
// -----------------------------------------------------------
export const getSupplierDebtDashboard = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const snap = await db()
    .collection("supplierDebts")
    .where("businessId", "==", businessId)
    .where("status", "in", ["pending", "partial", "overdue"])
    .get();

  let totalPayables = 0;
  let overdueTotal = 0;
  let overdueCount = 0;
  const now = new Date();

  snap.docs.forEach((doc) => {
    const data = doc.data();
    const outstanding = (data.outstanding as number) || 0;
    totalPayables += outstanding;

    const dueDate = (data.paymentDueDate as admin.firestore.Timestamp)?.toDate();
    if (dueDate && dueDate < now && outstanding > 0) {
      overdueTotal += outstanding;
      overdueCount++;
    }
  });

  return {
    totalPayables,
    overdueTotal,
    overdueCount,
    activeDebtsCount: snap.docs.length,
  };
});
