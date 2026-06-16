// ============================================================
// Audit Log Functions — Read-only retrieval + helper for other modules
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// getAuditLogs
// Paginated logs with optional filters: module, action, userId, date range.
// Newest first.
// -----------------------------------------------------------
export const getAuditLogs = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const {
    businessId,
    limit: pageLimit = 50,
    startAfter,
    module,
    action,
    userId,
    dateFrom,
    dateTo,
  } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
    module?: string;
    action?: string;
    userId?: string;
    dateFrom?: string;
    dateTo?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("auditLogs")
    .where("businessId", "==", businessId);

  if (module) {
    query = query.where("module", "==", module);
  }
  if (action) {
    query = query.where("action", "==", action);
  }
  if (userId) {
    query = query.where("userId", "==", userId);
  }
  if (dateFrom) {
    const from = admin.firestore.Timestamp.fromDate(new Date(dateFrom));
    query = query.where("createdAt", ">=", from);
  }
  if (dateTo) {
    const to = admin.firestore.Timestamp.fromDate(new Date(dateTo));
    query = query.where("createdAt", "<=", to);
  }

  query = query.orderBy("createdAt", "desc").limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("auditLogs").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  return {
    logs: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});

// -----------------------------------------------------------
// getAuditModules — Returns distinct modules for filter dropdown
// -----------------------------------------------------------
export const getAuditModules = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db()
    .collection("auditLogs")
    .where("businessId", "==", businessId)
    .orderBy("module")
    .select("module")
    .get();

  const modules = [...new Set(snap.docs.map((d) => d.data().module as string))].sort();
  return { modules };
});

// -----------------------------------------------------------
// getRecentAuditLogs — Latest 10 entries (dashboard widget)
// -----------------------------------------------------------
export const getRecentAuditLogs = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db()
    .collection("auditLogs")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(10)
    .get();

  return {
    logs: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});
