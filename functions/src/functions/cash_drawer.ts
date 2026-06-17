// ============================================================
// Cash Drawer Reconciliation — Track cash discrepancies
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// openCashSession
// Start a new cash session with opening float.
// Only one session can be open at a time.
// -----------------------------------------------------------
export const openCashSession = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, branchId, openingFloat } = request.data as {
    businessId: string;
    branchId?: string;
    openingFloat: number;
  };

  if (openingFloat === undefined || openingFloat < 0) {
    throw new HttpsError("invalid-argument", "A non-negative opening float is required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  // Check no open session exists
  const openSnap = await db()
    .collection("cashSessions")
    .where("businessId", "==", businessId)
    .where("status", "==", "open")
    .limit(1)
    .get();

  if (!openSnap.empty) {
    throw new HttpsError("failed-precondition", "A cash session is already open. Close it first.");
  }

  const userSnap = await db().collection("users").doc(request.auth.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";

  const sessionRef = db().collection("cashSessions").doc();
  const now = admin.firestore.Timestamp.now();

  const sessionData: Record<string, unknown> = {
    id: sessionRef.id,
    businessId,
    branchId: branchId || null,
    openedBy: request.auth!.uid,
    openedByName: userName,
    openingFloat: Number(openingFloat.toFixed(2)),
    cashSales: 0,
    cashRefunds: 0,
    expectedCash: Number(openingFloat.toFixed(2)),
    actualCash: 0,
    variance: 0,
    openedAt: now,
    closedAt: null,
    status: "open",
  };

  await db().runTransaction(async (txn) => {
    txn.set(sessionRef, sessionData);

    // Audit log
    const auditRef = db().collection("auditLogs").doc();
    txn.set(auditRef, {
      id: auditRef.id,
      businessId,
      userId: request.auth!.uid,
      userName,
      module: "Cash Drawer",
      action: "Open Session",
      entityId: sessionRef.id,
      entityName: `Cash Session ${sessionRef.id}`,
      oldValues: {},
      newValues: { openingFloat, status: "open" },
      metadata: { branchId: branchId || null },
      createdAt: now,
    });
  });

  return { success: true, sessionId: sessionRef.id };
});

// -----------------------------------------------------------
// closeCashSession
// Manager enters actual cash counted; system calculates variance.
// -----------------------------------------------------------
export const closeCashSession = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, sessionId, actualCash } = request.data as {
    businessId: string;
    sessionId: string;
    actualCash: number;
  };

  if (!sessionId || actualCash === undefined || actualCash < 0) {
    throw new HttpsError("invalid-argument", "sessionId and non-negative actualCash are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const userSnap = await db().collection("users").doc(request.auth.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";

  const result = await db().runTransaction(async (txn) => {
    const snap = await txn.get(db().collection("cashSessions").doc(sessionId));
    if (!snap.exists) {
      throw new HttpsError("not-found", "Cash session not found.");
    }
    const session = snap.data()!;
    if (session.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Session does not belong to your business.");
    }
    if (session.status !== "open") {
      throw new HttpsError("failed-precondition", "Session is already closed.");
    }

    const cashSales = session.cashSales || 0;
    const cashRefunds = session.cashRefunds || 0;
    const openingFloat = session.openingFloat || 0;
    const expectedCash = openingFloat + cashSales - cashRefunds;
    const variance = Number((actualCash - expectedCash).toFixed(2));
    const now = admin.firestore.Timestamp.now();

    txn.update(db().collection("cashSessions").doc(sessionId), {
      actualCash: Number(actualCash.toFixed(2)),
      expectedCash: Number(expectedCash.toFixed(2)),
      variance,
      closedAt: now,
      status: "closed",
    });

    // Audit log
    const auditRef = db().collection("auditLogs").doc();
    txn.set(auditRef, {
      id: auditRef.id,
      businessId,
      userId: request.auth!.uid,
      userName,
      module: "Cash Drawer",
      action: "Close Session",
      entityId: sessionId,
      entityName: `Cash Session ${sessionId}`,
      oldValues: { status: "open", actualCash: session.actualCash || 0 },
      newValues: { status: "closed", actualCash, expectedCash, variance },
      metadata: { branchId: session.branchId || null },
      createdAt: now,
    });

    return { expectedCash: Number(expectedCash.toFixed(2)), variance };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getCashSessions
// Paginated session list.
// -----------------------------------------------------------
export const getCashSessions = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, status, limit: pageLimit = 50, startAfter } = request.data as {
    businessId: string;
    status?: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("cashSessions")
    .where("businessId", "==", businessId);

  if (status) {
    query = query.where("status", "==", status);
  }

  query = query.orderBy("openedAt", "desc").limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("cashSessions").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  return {
    sessions: snap.docs.map((d) => {
      const data = d.data();
      return {
        ...data,
        openedAt: (data.openedAt as admin.firestore.Timestamp).toDate().toISOString(),
        closedAt: data.closedAt ? (data.closedAt as admin.firestore.Timestamp).toDate().toISOString() : null,
      };
    }),
  };
});

// -----------------------------------------------------------
// getCashVarianceReport
// Summary stats for today / period.
// -----------------------------------------------------------
export const getCashVarianceReport = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  try {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfDayTs = admin.firestore.Timestamp.fromDate(startOfDay);

    const snap = await db()
      .collection("cashSessions")
      .where("businessId", "==", businessId)
      .where("openedAt", ">=", startOfDayTs)
      .get();

    let totalExpected = 0;
    let totalActual = 0;
    let totalVariance = 0;
    let sessionCount = 0;

    snap.docs.forEach((d) => {
      const data = d.data();
      totalExpected += data.expectedCash || 0;
      totalActual += data.actualCash || 0;
      totalVariance += data.variance || 0;
      sessionCount++;
    });

    return {
      totalExpectedCash: Number(totalExpected.toFixed(2)),
      totalActualCash: Number(totalActual.toFixed(2)),
      totalVariance: Number(totalVariance.toFixed(2)),
      sessionCount,
    };
  } catch (e) {
    return { totalExpectedCash: 0, totalActualCash: 0, totalVariance: 0, sessionCount: 0 };
  }
});
