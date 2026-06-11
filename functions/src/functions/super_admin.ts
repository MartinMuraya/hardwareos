// ============================================================
// Super Admin Functions — Platform management and analytics
// ============================================================

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
// getPlatformStats
// -----------------------------------------------------------
export const getPlatformStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const businessesQuery = db().collection("businesses");
  
  const totalBusinesses = await businessesQuery.count().get();
  const activeBusinesses = await businessesQuery.where("active", "==", true).count().get();
  const pendingBusinesses = await businessesQuery.where("status", "==", "pending").count().get();
  const suspendedBusinesses = await businessesQuery.where("status", "==", "suspended").count().get();
  
  const trialAccounts = await businessesQuery.where("subscriptionStatus", "==", "trial").count().get();
  const expiredSubscriptions = await businessesQuery.where("subscriptionStatus", "==", "expired").count().get();

  const totalUsers = await db().collection("users").count().get();
  const totalSales = await db().collectionGroup("sales").count().get();

  // Monthly Revenue would be calculated by summing active subscription values.
  // For now, we return a mock value until subscriptions are fully integrated.
  const monthlyRevenue = 0;

  return {
    totalBusinesses: totalBusinesses.data().count,
    activeBusinesses: activeBusinesses.data().count,
    pendingBusinesses: pendingBusinesses.data().count,
    suspendedBusinesses: suspendedBusinesses.data().count,
    trialAccounts: trialAccounts.data().count,
    expiredSubscriptions: expiredSubscriptions.data().count,
    totalUsers: totalUsers.data().count,
    totalSales: totalSales.data().count,
    monthlyRevenue,
  };
});


