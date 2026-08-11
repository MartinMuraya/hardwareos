// ============================================================
// Expense Functions — Business expense tracking
// ============================================================

import * as admin from "firebase-admin";
import { rateLimitCheck } from "../middleware/rateLimiter";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";
import { postJournalEntryHelper, JournalLine } from "./accounting";

const db = () => admin.firestore();

export const EXPENSE_CATEGORIES = [
  "Rent", "Utilities", "Salaries", "Transport", "Supplies",
  "Maintenance", "Marketing", "Tax", "Other",
];

// -----------------------------------------------------------
// createExpense
// -----------------------------------------------------------
export const createExpense = onCall(SECURE_FN_OPTS, async (request) => {
  try {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
    await rateLimitCheck(request.rawRequest?.ip || request.auth.uid, "createExpense", 60, 1);

    const { businessId, branchId, category, amount, note } = request.data as {
      businessId: string;
      branchId?: string;
      category: string;
      amount: number;
      note?: string;
    };

    if (!category || !amount || amount <= 0) {
      throw new HttpsError("invalid-argument", "Category and a positive amount are required.");
    }

    await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
    await assertActiveSubscription(businessId);

    const now = admin.firestore.FieldValue.serverTimestamp();
    
    await db().runTransaction(async (txn) => {
      // READS MUST COME BEFORE WRITES IN FIRESTORE TRANSACTIONS
      const accountsSnap = await txn.get(db().collection("chart_of_accounts").where("businessId", "==", businessId));

      const expRef = db().collection("expenses").doc();
      txn.set(expRef, {
        id: expRef.id,
        businessId,
        branchId: branchId || null,
        category: category.trim(),
        amount: Number(amount.toFixed(2)),
        note: note?.trim() || "",
        createdBy: request.auth!.uid,
        createdAt: now,
      });

      if (!accountsSnap.empty) {
        const accounts = accountsSnap.docs.map(d => d.data());
        const getAcc = (name: string) => accounts.find(a => a.name === name)?.id;
        
        const cashAcc = getAcc("Cash in Hand");
        const genExpAcc = getAcc("General Expenses");
        const catAcc = getAcc(`${category.trim()} Expense`) || genExpAcc;

        if (cashAcc && catAcc) {
          const lines: JournalLine[] = [
            { accountId: catAcc, debit: Number(amount.toFixed(2)), credit: 0 },
            { accountId: cashAcc, debit: 0, credit: Number(amount.toFixed(2)) }
          ];
          postJournalEntryHelper(txn, businessId, expRef.id, `Expense: ${category}`, lines);
        }
      }
    });

    return { success: true };
  } catch (err: any) {
    if (err instanceof HttpsError) throw err;
    console.error("CREATE EXPENSE ERROR:", err.message);
    throw new HttpsError("internal", err.message);
  }
});

// -----------------------------------------------------------
// getExpenses
// -----------------------------------------------------------
export const getExpenses = onCall(SECURE_FN_OPTS, async (request) => {
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
  // Wrap in object so Flutter's FunctionsService (Map cast) does not throw.
  return {
    expenses: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});
