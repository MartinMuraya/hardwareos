import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore;

export const exportAdminReport = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

  // Verify Admin Access
  const adminSnap = await db()
    .collection("platformAdmins")
    .doc(request.auth.uid)
    .get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const reportType = request.data.type || "users"; // users, businesses, signups

  let csvContent = "";

  if (reportType === "businesses") {
    csvContent = "BusinessID,Name,OwnerEmail,Status,Plan,CreatedAt\n";
    const snap = await db().collection("businesses").orderBy("createdAt", "desc").get();
    for (const doc of snap.docs) {
      const data = doc.data();
      const date = data.createdAt ? data.createdAt.toDate().toISOString() : "";
      csvContent += `${doc.id},"${data.name || ""}","${data.ownerEmail || ""}",${data.status || ""},${data.plan || ""},${date}\n`;
    }
  } else if (reportType === "users") {
    csvContent = "UserID,Email,Role,BusinessID\n";
    // We could iterate over all businesses, then users, or just use the users collection
    const snap = await db().collectionGroup("users").get();
    for (const doc of snap.docs) {
      const data = doc.data();
      csvContent += `${doc.id},"${data.email || ""}",${data.role || ""},${data.businessId || ""}\n`;
    }
  } else if (reportType === "signups") {
    // Generate daily signup counts for the past 30 days
    csvContent = "Date,Signups\n";
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const snap = await db().collection("businesses").where("createdAt", ">=", thirtyDaysAgo).get();
    
    const counts: Record<string, number> = {};
    for (const doc of snap.docs) {
      const data = doc.data();
      if (data.createdAt) {
        const dateStr = data.createdAt.toDate().toISOString().split("T")[0];
        counts[dateStr] = (counts[dateStr] || 0) + 1;
      }
    }
    const sortedDates = Object.keys(counts).sort();
    for (const d of sortedDates) {
      csvContent += `${d},${counts[d]}\n`;
    }
  } else {
    throw new HttpsError("invalid-argument", "Invalid report type requested.");
  }

  return { csvData: csvContent };
});
