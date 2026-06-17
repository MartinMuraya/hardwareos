import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

// -----------------------------------------------------------
// Middleware: assertSuperAdmin
// -----------------------------------------------------------
async function assertSuperAdmin(uid: string) {
  const snap = await db().collection("platformAdmins").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "You must be a platform administrator to perform this action.");
  }
}

// -----------------------------------------------------------
// adminGetAllBusinesses
// Fetches all businesses with optional filter and cursor pagination.
// -----------------------------------------------------------
export const adminGetAllBusinesses = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { filter, lastDocId, pageSize } = request.data as {
    filter?: "all" | "pending" | "approved" | "suspended" | "rejected";
    lastDocId?: string;
    pageSize?: number;
  };

  const limit = Math.min(pageSize || 100, 200);
  let query: admin.firestore.Query = db().collection("businesses");
  
  if (filter && filter !== "all") {
    query = query.where("status", "==", filter);
  }
  
  query = query.orderBy("createdAt", "desc").limit(limit);

  if (lastDocId) {
    const cursor = await db().collection("businesses").doc(lastDocId).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();

  return {
    businesses: snap.docs.map(doc => {
      const data = doc.data();
      return {
        ...data,
        createdAt: (data.createdAt as admin.firestore.Timestamp)?.toDate()?.toISOString(),
        updatedAt: (data.updatedAt as admin.firestore.Timestamp)?.toDate()?.toISOString(),
      };
    }),
    lastDocId: snap.docs.length > 0 ? snap.docs[snap.docs.length - 1].id : null,
    hasMore: snap.docs.length >= limit,
  };
});

// -----------------------------------------------------------
// adminUpdateBusinessStatus
// Updates the status of a business (approve, suspend, reject, reactivate)
// -----------------------------------------------------------
export const adminUpdateBusinessStatus = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { businessId, status } = request.data as { businessId: string; status: "pending" | "approved" | "suspended" | "rejected" };
  
  if (!businessId || !status) {
    throw new HttpsError("invalid-argument", "businessId and status are required");
  }

  const active = status === "approved";

  await db().collection("businesses").doc(businessId).update({
    status,
    active,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Log the action in audit logs
  await db().collection("auditLogs").add({
    action: `business_${status}`,
    targetId: businessId,
    targetType: "business",
    performedBy: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
