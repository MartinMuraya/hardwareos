import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

export async function rateLimitCheck(
  ip: string,
  action: string,
  maxRequests: number = 5,
  windowMinutes: number = 15
): Promise<void> {
  const db = admin.firestore();
  
  const identifier = ip || "unknown";
  const ref = db.collection("rateLimits").doc(`${action}_${identifier.replace(/[\.\\:\\/]/g, "_")}`);

  // Use a transaction for atomic read-check-increment to prevent race conditions
  await db.runTransaction(async (txn) => {
    const doc = await txn.get(ref);
    const now = admin.firestore.Timestamp.now();

    if (doc.exists) {
      const data = doc.data()!;
      const windowStart = data.windowStart as admin.firestore.Timestamp;

      // If window expired, reset
      if (now.toMillis() - windowStart.toMillis() > windowMinutes * 60 * 1000) {
        txn.set(ref, { count: 1, windowStart: now });
        return;
      }

      if (data.count >= maxRequests) {
        throw new HttpsError("resource-exhausted", `Too many requests for ${action}. Try again later.`);
      }

      txn.update(ref, { count: admin.firestore.FieldValue.increment(1) });
    } else {
      txn.set(ref, { count: 1, windowStart: now });
    }
  });
}
