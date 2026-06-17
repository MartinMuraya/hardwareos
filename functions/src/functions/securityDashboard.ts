import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

async function assertSuperAdmin(uid: string): Promise<void> {
  const snap = await db().collection("platformAdmins").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "Only platform administrators can access security data.");
  }
}

export const getSecurityMetrics = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);
  const oneHourAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 60 * 60 * 1000);
  const oneDayAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
  const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const [
    loginAttemptsHour,
    loginAttemptsDay,
    loginAttemptsAll,
    lockedAccounts,
    resetRequestsHour,
    resetRequestsDay,
    roleChanges,
    functionErrors,
    recentEventsSnap,
    crossTenantLogs,
  ] = await Promise.all([
    db().collection("auditLogs")
      .where("action", "==", "LOGIN_FAILED")
      .where("timestamp", ">=", oneHourAgo)
      .count().get(),
    db().collection("auditLogs")
      .where("action", "==", "LOGIN_FAILED")
      .where("timestamp", ">=", oneDayAgo)
      .count().get(),
    db().collection("auditLogs")
      .where("action", "==", "LOGIN_FAILED")
      .count().get(),
    db().collection("loginAttempts")
      .where("lockUntil", "!=", null)
      .count().get(),
    db().collection("auditLogs")
      .where("action", "==", "PASSWORD_RESET_REQUESTED")
      .where("timestamp", ">=", oneHourAgo)
      .count().get(),
    db().collection("auditLogs")
      .where("action", "==", "PASSWORD_RESET_REQUESTED")
      .where("timestamp", ">=", oneDayAgo)
      .count().get(),
    db().collection("auditLogs")
      .where("action", "==", "ROLE_CHANGED")
      .where("timestamp", ">=", sevenDaysAgo)
      .count().get(),
    db().collection("auditLogs")
      .where("action", "==", "FUNCTION_ERROR")
      .where("timestamp", ">=", oneDayAgo)
      .count().get(),
    db().collection("auditLogs")
      .orderBy("timestamp", "desc")
      .limit(20)
      .get(),
    db().collection("auditLogs")
      .where("action", "==", "CROSS_TENANT_VIOLATION")
      .where("timestamp", ">=", sevenDaysAgo)
      .count().get(),
  ]);

  const recentEvents = recentEventsSnap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      action: d.action,
      userId: d.userId || null,
      businessId: d.businessId || null,
      metadata: d.metadata || null,
      timestamp: (d.timestamp as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
    };
  });

  return {
    failedLogins: {
      lastHour: loginAttemptsHour.data().count,
      lastDay: loginAttemptsDay.data().count,
      total: loginAttemptsAll.data().count,
    },
    lockedAccounts: lockedAccounts.data().count,
    passwordResets: {
      lastHour: resetRequestsHour.data().count,
      lastDay: resetRequestsDay.data().count,
    },
    roleChanges7Days: roleChanges.data().count,
    crossTenantViolations7Days: crossTenantLogs.data().count,
    functionErrors24h: functionErrors.data().count,
    recentEvents,
  };
});

export const getSecurityEvents = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { action, limit: reqLimit = 50, startAfter } = request.data as {
    action?: string;
    limit?: number;
    startAfter?: string;
  };

  let query: admin.firestore.Query = db()
    .collection("auditLogs")
    .orderBy("timestamp", "desc")
    .limit(Math.min(reqLimit, 200));

  if (action) {
    query = query.where("action", "==", action);
  }

  if (startAfter) {
    const cursor = await db().collection("auditLogs").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();

  return {
    events: snap.docs.map((doc) => {
      const d = doc.data();
      return {
        id: doc.id,
        action: d.action,
        userId: d.userId || null,
        businessId: d.businessId || null,
        targetId: d.targetId || null,
        targetType: d.targetType || null,
        metadata: d.metadata || null,
        timestamp: (d.timestamp as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
      };
    }),
  };
});
