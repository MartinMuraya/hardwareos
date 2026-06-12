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

  const [
    totalBusinessesSnap,
    activeBusinessesSnap,
    pendingBusinessesSnap,
    suspendedBusinessesSnap,
    trialAccountsSnap,
    expiredSubscriptionsSnap,
    totalUsersSnap,
    totalSalesSnap,
  ] = await Promise.all([
    businessesQuery.count().get(),
    businessesQuery.where("active", "==", true).count().get(),
    businessesQuery.where("status", "==", "pending").count().get(),
    businessesQuery.where("status", "==", "suspended").count().get(),
    businessesQuery.where("subscriptionStatus", "==", "trial").count().get(),
    businessesQuery.where("subscriptionStatus", "==", "expired").count().get(),
    db().collection("users").count().get(),
    db().collectionGroup("sales").count().get(),
  ]);

  // Calculate real monthly revenue from completed subscription payments
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const startOfMonthTimestamp = admin.firestore.Timestamp.fromDate(startOfMonth);

  const [monthlySubsSnap, totalSubsSnap] = await Promise.all([
    db().collection("subscriptions")
      .where("transactionStatus", "==", "completed")
      .where("paidAt", ">=", startOfMonthTimestamp)
      .orderBy("paidAt", "desc")
      .get(),
    db().collection("subscriptions")
      .where("transactionStatus", "==", "completed")
      .get(),
  ]);

  const monthlyRevenue = monthlySubsSnap.docs.reduce((sum, doc) => {
    const data = doc.data();
    return sum + (typeof data.amount === "number" ? data.amount : 0);
  }, 0);

  const totalRevenue = totalSubsSnap.docs.reduce((sum, doc) => {
    const data = doc.data();
    return sum + (typeof data.amount === "number" ? data.amount : 0);
  }, 0);

  const totalTransactions = totalSubsSnap.docs.length;

  return {
    totalBusinesses: totalBusinessesSnap.data().count,
    activeBusinesses: activeBusinessesSnap.data().count,
    pendingBusinesses: pendingBusinessesSnap.data().count,
    suspendedBusinesses: suspendedBusinessesSnap.data().count,
    trialAccounts: trialAccountsSnap.data().count,
    expiredSubscriptions: expiredSubscriptionsSnap.data().count,
    totalUsers: totalUsersSnap.data().count,
    totalSales: totalSalesSnap.data().count,
    monthlyRevenue,
    totalRevenue,
    totalTransactions,
  };
});


