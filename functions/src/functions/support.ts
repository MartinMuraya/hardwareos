import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

// Middleware
async function assertSuperAdmin(uid: string) {
  const snap = await db().collection("platformAdmins").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "You must be a platform administrator.");
  }
}

// -----------------------------------------------------------
// 1. createSupportTicket (For Tenants)
// -----------------------------------------------------------
export const createSupportTicket = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

  const { subject, message, priority } = request.data as { subject: string; message: string; priority?: string };
  if (!subject || !message) {
    throw new HttpsError("invalid-argument", "Subject and message are required.");
  }

  // Get business context
  const userSnap = await db().collection("users").doc(request.auth.uid).get();
  const userData = userSnap.data();
  const businessId = userData?.businessId || "unknown";
  
  const ticketId = db().collection("supportTickets").doc().id;
  const newTicket = {
    id: ticketId,
    businessId,
    createdBy: request.auth.uid,
    subject,
    status: "open",
    priority: priority || "normal",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db().collection("supportTickets").doc(ticketId).set(newTicket);
  
  // Create first message
  await db().collection("supportTickets").doc(ticketId).collection("messages").add({
    senderId: request.auth.uid,
    senderRole: "tenant",
    message,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, ticketId };
});

// -----------------------------------------------------------
// 2. adminGetSupportTickets (For Super Admins)
// -----------------------------------------------------------
export const adminGetSupportTickets = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { status } = request.data as { status?: string };
  let query: admin.firestore.Query = db().collection("supportTickets");
  
  if (status && status !== "all") {
    query = query.where("status", "==", status);
  }
  
  const snap = await query.orderBy("createdAt", "desc").limit(50).get();
  
  const tickets = snap.docs.map(doc => {
    const data = doc.data();
    return {
      ...data,
      createdAt: (data.createdAt as admin.firestore.Timestamp)?.toDate()?.toISOString(),
      updatedAt: (data.updatedAt as admin.firestore.Timestamp)?.toDate()?.toISOString(),
    };
  });

  return { tickets };
});

// -----------------------------------------------------------
// 3. adminRespondToTicket (For Super Admins)
// -----------------------------------------------------------
export const adminRespondToTicket = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { ticketId, message, newStatus } = request.data as { ticketId: string; message: string; newStatus?: string };
  if (!ticketId || !message) {
    throw new HttpsError("invalid-argument", "Ticket ID and message are required.");
  }

  const ticketRef = db().collection("supportTickets").doc(ticketId);
  
  const updates: any = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  if (newStatus) {
    updates.status = newStatus;
  } else {
    updates.status = "answered"; // Automatically mark as answered
  }

  await ticketRef.update(updates);
  
  await ticketRef.collection("messages").add({
    senderId: request.auth.uid,
    senderRole: "admin",
    message,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
