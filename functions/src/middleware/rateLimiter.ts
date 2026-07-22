import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

export async function rateLimitCheck(
  ip: string,
  action: string,
  maxRequests: number = 5,
  windowMinutes: number = 15
): Promise<void> {
  const db = admin.firestore();
  
  // Use a generic id instead of just the IP, since IP is passed in
  const identifier = ip || "unknown";
  
  const ref = db.collection("rateLimits").doc(`${action}_${identifier.replace(/[\.\:\/]/g, "_")}`);
  const now = admin.firestore.Timestamp.now();
  
  const doc = await ref.get();
  
  if (doc.exists) {
    const data = doc.data()!;
    const windowStart = data.windowStart as admin.firestore.Timestamp;
    
    // If window expired, reset
    if (now.toMillis() - windowStart.toMillis() > windowMinutes * 60 * 1000) {
      await ref.set({ count: 1, windowStart: now });
      return;
    }
    
    if (data.count >= maxRequests) {
      throw new HttpsError("resource-exhausted", `Too many requests for ${action}. Try again later.`);
    }
    
    await ref.update({ count: admin.firestore.FieldValue.increment(1) });
  } else {
    await ref.set({ count: 1, windowStart: now });
  }
}
