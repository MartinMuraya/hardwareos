import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

// -----------------------------------------------------------
// recordSubscriptionEvent
// Internal helper to log a subscription event
// -----------------------------------------------------------
export async function recordSubscriptionEvent(params: {
  businessId: string;
  businessName: string;
  eventType: string;
  description: string;
  plan: string;
  previousStatus?: string;
  newStatus?: string;
  details?: Record<string, any>;
  performedBy?: string;
}): Promise<string> {
  const ref = db().collection("subscriptionHistory").doc();
  const data = {
    id: ref.id,
    businessId: params.businessId,
    businessName: params.businessName,
    eventType: params.eventType,
    description: params.description,
    plan: params.plan,
    previousStatus: params.previousStatus || null,
    newStatus: params.newStatus || null,
    details: params.details || null,
    performedBy: params.performedBy || "system",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };

  await ref.set(data);
  return ref.id;
}

// -----------------------------------------------------------
// getMySubscriptionHistory
// Returns the authenticated user's business subscription history
// -----------------------------------------------------------
export const getMySubscriptionHistory = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

    const userSnap = await db()
      .collection("users")
      .doc(request.auth.uid)
      .get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const businessId = userSnap.data()!.businessId;
    if (!businessId) {
      throw new HttpsError("failed-precondition", "No business associated with this user.");
    }

    const snap = await db()
      .collection("subscriptionHistory")
      .where("businessId", "==", businessId)
      .orderBy("timestamp", "desc")
      .limit(100)
      .get();

    const events = snap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        eventType: data.eventType,
        description: data.description,
        plan: data.plan,
        previousStatus: data.previousStatus,
        newStatus: data.newStatus,
        details: data.details || {},
        performedBy: data.performedBy,
        timestamp:
          (data.timestamp as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
      };
    });

    return { events };
  }
);

// -----------------------------------------------------------
// adminGetBusinessHistory
// Admin function to view any business's subscription history
// -----------------------------------------------------------
export const adminGetBusinessHistory = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

    const adminSnap = await db()
      .collection("platformAdmins")
      .doc(request.auth.uid)
      .get();
    if (!adminSnap.exists) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { businessId } = request.data as { businessId: string };
    if (!businessId) {
      throw new HttpsError("invalid-argument", "businessId is required");
    }

    const snap = await db()
      .collection("subscriptionHistory")
      .where("businessId", "==", businessId)
      .orderBy("timestamp", "desc")
      .limit(200)
      .get();

    const events = snap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        eventType: data.eventType,
        description: data.description,
        plan: data.plan,
        previousStatus: data.previousStatus,
        newStatus: data.newStatus,
        details: data.details || {},
        performedBy: data.performedBy,
        timestamp:
          (data.timestamp as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
      };
    });

    return { events };
  }
);
