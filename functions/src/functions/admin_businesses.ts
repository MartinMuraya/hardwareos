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
// Fetches all businesses with optional filter
// -----------------------------------------------------------
export const adminGetAllBusinesses = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { filter } = request.data as { filter?: "all" | "pending" | "approved" | "suspended" | "rejected" };

  let query: admin.firestore.Query = db().collection("businesses");
  
  if (filter && filter !== "all") {
    query = query.where("status", "==", filter);
  }
  
  // Sort by newest first
  query = query.orderBy("createdAt", "desc").limit(100); // Pagination could be added later

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

// -----------------------------------------------------------
// adminDeleteBusiness
// Hard deletes a business and all its associated data
// -----------------------------------------------------------
export const adminDeleteBusiness = onCall({ cors: true, timeoutSeconds: 540 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { businessId } = request.data as { businessId: string };
  if (!businessId) {
    throw new HttpsError("invalid-argument", "businessId is required");
  }

  // Define collections that have 'businessId' field
  const collectionsToClean = [
    "products",
    "stockMovements",
    "sales",
    "expenses",
    "suppliers",
    "customers",
    "branches",
    "subscriptions",
    "auditLogs",
    "systemNotifications",
    "stockTransfers",
    "stockAdjustments",
    "purchaseOrders",
    "quotations",
    "returns",
  ];

  const bulkWriter = db().bulkWriter();

  // 1. Delete associated users (auth and firestore)
  const usersSnap = await db().collection("users").where("businessId", "==", businessId).get();
  for (const userDoc of usersSnap.docs) {
    bulkWriter.delete(userDoc.ref);
    try {
      await admin.auth().deleteUser(userDoc.id);
    } catch (e) {
      console.warn(`Failed to delete auth user ${userDoc.id}`, e);
    }
  }

  // 2. Delete all related documents in root collections
  for (const collName of collectionsToClean) {
    const snap = await db().collection(collName).where("businessId", "==", businessId).get();
    snap.docs.forEach(doc => bulkWriter.delete(doc.ref));
  }

  // 3. Delete the business document itself
  const bizRef = db().collection("businesses").doc(businessId);
  bulkWriter.delete(bizRef);

  await bulkWriter.close();

  // Log action
  await db().collection("auditLogs").add({
    action: "admin_delete_business",
    targetId: businessId,
    targetType: "business",
    performedBy: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    details: { message: "Hard deleted business and all associated data." },
  });

  return { success: true };
});
