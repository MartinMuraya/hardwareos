import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";

const db = () => admin.firestore();

// -----------------------------------------------------------
// runSystemMaintenance
// Runs daily at 2 AM to clean up stale data
// Resolves H-8 (idempotency keys) and H-9 (login attempts)
// -----------------------------------------------------------
export const runSystemMaintenance = onSchedule(
  {
    schedule: "0 2 * * *", // 2 AM every day
    timeZone: "Africa/Nairobi",
    timeoutSeconds: 540, // 9 minutes
  },
  async () => {
    const now = Date.now();
    const sevenDaysAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
    const tsSevenDaysAgo = admin.firestore.Timestamp.fromDate(sevenDaysAgo);
    
    // We will collect promises for batched deletions
    const cleanupPromises: Promise<void>[] = [];

    // Helper to delete old docs in a collection
    const cleanupCollection = async (collectionName: string, timeField: string = "createdAt") => {
      const snap = await db()
        .collection(collectionName)
        .where(timeField, "<", tsSevenDaysAgo)
        .limit(500)
        .get();

      if (snap.empty) return;

      const batch = db().batch();
      snap.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      cleanupPromises.push(batch.commit().then(() => {}));
    };

    // H-8: Cleanup idempotency_keys
    await cleanupCollection("idempotency_keys");

    // H-9: Cleanup loginAttempts & passwordResetRequests
    // Assuming loginAttempts stores 'timestamp' instead of 'createdAt'
    const loginSnap = await db()
      .collection("loginAttempts")
      .where("timestamp", "<", tsSevenDaysAgo)
      .limit(500)
      .get();
      
    if (!loginSnap.empty) {
      const batch = db().batch();
      loginSnap.docs.forEach((doc) => batch.delete(doc.ref));
      cleanupPromises.push(batch.commit().then(() => {}));
    }

    const resetSnap = await db()
      .collection("passwordResetRequests")
      .where("timestamp", "<", tsSevenDaysAgo)
      .limit(500)
      .get();
      
    if (!resetSnap.empty) {
      const batch = db().batch();
      resetSnap.docs.forEach((doc) => batch.delete(doc.ref));
      cleanupPromises.push(batch.commit().then(() => {}));
    }

    await Promise.all(cleanupPromises);
    console.log("System maintenance cleanup completed successfully.");
  }
);
