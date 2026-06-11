// ============================================================
// Expense Functions — Business expense tracking
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

export const EXPENSE_CATEGORIES = [
  "Rent", "Utilities", "Salaries", "Transport", "Supplies",
  "Maintenance", "Marketing", "Tax", "Other",
];

// -----------------------------------------------------------
// createExpense
// -----------------------------------------------------------
export const createExpense = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, category, amount, note } = request.data as {
    businessId: string;
    category: string;
    amount: number;
    note?: string;
  };

  if (!category || !amount || amount <= 0) {
    throw new HttpsError("invalid-argument", "Category and a positive amount are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const expRef = db().collection("expenses").doc();
  await expRef.set({
    id: expRef.id,
    businessId,
    category: category.trim(),
    amount: Number(amount.toFixed(2)),
    note: note?.trim() || "",
    createdBy: request.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, expenseId: expRef.id };
});

// -----------------------------------------------------------
// getExpenses
// -----------------------------------------------------------
export const getExpenses = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 30, startAfter } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("expenses")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("expenses").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  return snap.docs.map((d) => ({
    ...d.data(),
    createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
  }));
});
