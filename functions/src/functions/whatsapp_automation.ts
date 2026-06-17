// ============================================================
// WhatsApp Automation — Notification queue, message templates,
// provider abstraction for Africa's Talking & Meta WhatsApp
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const atApiKeySecret = defineSecret("AT_API_KEY");
const atUsernameSecret = defineSecret("AT_USERNAME");
const atSenderIdSecret = defineSecret("AT_SENDER_ID");
const metaWaTokenSecret = defineSecret("META_WA_TOKEN");
const metaWaPhoneNumberIdSecret = defineSecret("META_WA_PHONE_NUMBER_ID");

const db = () => admin.firestore();

// -----------------------------------------------------------
// Message Templates — Reusable engine with placeholders
// -----------------------------------------------------------
const TEMPLATES: Record<string, string> = {
  debt_reminder: "Dear {{customerName}}, your outstanding balance of KES {{balance}} is due. Please pay at your earliest convenience. - HardwareOS",
  payment_received: "Dear {{customerName}}, we have received your payment of KES {{amount}}. Thank you! - HardwareOS",
  quotation_ready: "Dear {{customerName}}, your quotation {{quotationNumber}} is ready for review. Total: KES {{amount}}. - HardwareOS",
  po_received: "Dear {{supplierName}}, Purchase Order {{poNumber}} has been received. Amount: KES {{amount}}. - HardwareOS",
  low_stock: "Alert: {{product}} is low on stock ({{quantity}} remaining). Please reorder. - HardwareOS",
  transfer_approved: "Stock transfer of {{product}} ({{quantity}} units) has been approved. - HardwareOS",
  subscription_expiry: "Your HardwareOS subscription is expiring soon. Please renew to continue using all features. - HardwareOS",
};

function fillTemplate(template: string, vars: Record<string, string>): string {
  let msg = template;
  for (const [key, val] of Object.entries(vars)) {
    msg = msg.replace(new RegExp(`{{${key}}}`, "g"), val);
  }
  return msg;
}

// -----------------------------------------------------------
// enqueueNotification
// Called by other Cloud Functions to queue a message.
// -----------------------------------------------------------
export const enqueueNotification = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, type, recipient, variables } = request.data as {
    businessId: string;
    type: string;
    recipient: string;
    variables: Record<string, string>;
  };

  if (!type || !recipient) {
    throw new HttpsError("invalid-argument", "type and recipient are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId);
  await assertActiveSubscription(businessId);

  const template = TEMPLATES[type];
  if (!template) {
    throw new HttpsError("invalid-argument", `Unknown notification type: ${type}`);
  }

  const message = fillTemplate(template, variables);
  const notifRef = db().collection("notificationQueue").doc();
  const now = admin.firestore.Timestamp.now();

  await notifRef.set({
    id: notifRef.id,
    businessId,
    type,
    recipient,
    message,
    status: "pending",
    createdAt: now,
    sentAt: null,
    error: null,
  });

  return { success: true, notificationId: notifRef.id };
});

// -----------------------------------------------------------
// getNotificationSettings — Read business notification prefs
// -----------------------------------------------------------
export const getNotificationSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db().collection("businessSettings").doc(businessId).get();
  const settings = snap.data()?.notifications || {
    debtReminders: true,
    lowStockAlerts: true,
    paymentNotifications: true,
    quotationNotifications: true,
    provider: "meta_whatsapp",
  };

  return { settings };
});

// -----------------------------------------------------------
// updateNotificationSettings
// -----------------------------------------------------------
export const updateNotificationSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, settings } = request.data as {
    businessId: string;
    settings: Record<string, unknown>;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  await db().collection("businessSettings").doc(businessId).set(
    { notifications: settings },
    { merge: true }
  );

  return { success: true };
});

// -----------------------------------------------------------
// getNotifications — Notification delivery history
// -----------------------------------------------------------
export const getNotifications = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, status, limit: pageLimit = 50 } = request.data as {
    businessId: string;
    status?: string;
    limit?: number;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("notificationQueue")
    .where("businessId", "==", businessId);

  if (status) query = query.where("status", "==", status);

  query = query.orderBy("createdAt", "desc").limit(Math.min(pageLimit, 100));
  const snap = await query.get();

  return {
    notifications: snap.docs.map((d) => {
      const data = d.data();
      return {
        ...data,
        createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
        sentAt: data.sentAt ? (data.sentAt as admin.firestore.Timestamp).toDate().toISOString() : null,
      };
    }),
  };
});

// -----------------------------------------------------------
// getNotificationStats — Dashboard widget
// -----------------------------------------------------------
export const getNotificationStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  try {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfDayTs = admin.firestore.Timestamp.fromDate(startOfDay);

    const snap = await db()
      .collection("notificationQueue")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", startOfDayTs)
      .get();

    let sent = 0;
    let pending = 0;
    let failed = 0;

    snap.docs.forEach((d) => {
      const s = d.data().status;
      if (s === "sent") sent++;
      else if (s === "pending") pending++;
      else if (s === "failed") failed++;
    });

    return { sentToday: sent, pendingToday: pending, failedToday: failed };
  } catch (e) {
    return { sentToday: 0, pendingToday: 0, failedToday: 0 };
  }
});

// -----------------------------------------------------------
// processNotificationQueue — Firestore-triggered function
// Processes pending notifications using configured provider.
// -----------------------------------------------------------
export const processNotificationQueue = onDocumentWritten(
  {
    document: "notificationQueue/{notifId}",
    secrets: [atApiKeySecret, atUsernameSecret, atSenderIdSecret, metaWaTokenSecret, metaWaPhoneNumberIdSecret],
  },
  async (event) => {
    const snap = event.data?.after;
    if (!snap?.exists) return;

    const data = snap.data();
    if (!data || data.status !== "pending") return;

    const businessId = data.businessId as string;

    // Read business notification settings
    const settingsSnap = await db().collection("businessSettings").doc(businessId).get();
    const settings = settingsSnap.data()?.notifications || {};
    const provider = (settings.provider as string) || "meta_whatsapp";

    // Check if this notification type is enabled
    const type = data.type as string;
    const typeKey = type === "debt_reminder" ? "debtReminders"
      : type === "low_stock" ? "lowStockAlerts"
      : type === "payment_received" ? "paymentNotifications"
      : type === "quotation_ready" ? "quotationNotifications"
      : null;

    if (typeKey && settings[typeKey] === false) {
      // Type disabled — mark as skipped
      await snap.ref.update({ status: "skipped", sentAt: admin.firestore.Timestamp.now() });
      return;
    }

    try {
      let success = false;

      if (provider === "africas_talking") {
        // Africa's Talking integration
        const apiKey = process.env.AT_API_KEY;
        const username = process.env.AT_USERNAME || "sandbox";

        if (apiKey) {
          const response = await fetch(
            `https://api.africastalking.com/version1/messaging`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                "apiKey": apiKey,
                "Accept": "application/json",
              },
              body: new URLSearchParams({
                username,
                to: data.recipient as string,
                message: data.message as string,
                from: process.env.AT_SENDER_ID || "",
              }).toString(),
            }
          );

          const result = await response.json() as { SMSMessageData?: { Message?: string; Recipients?: Array<{ statusCode?: number }> } };
          success = result?.SMSMessageData?.Recipients?.some(
            (r: { statusCode?: number }) => r.statusCode === 101
          ) ?? false;
        }
      } else if (provider === "meta_whatsapp") {
        // Meta WhatsApp Business API
        const token = process.env.META_WA_TOKEN;
        const phoneNumberId = process.env.META_WA_PHONE_NUMBER_ID;

        if (token && phoneNumberId) {
          const response = await fetch(
            `https://graph.facebook.com/v18.0/${phoneNumberId}/messages`,
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${token}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                messaging_product: "whatsapp",
                to: data.recipient,
                type: "text",
                text: { body: data.message },
              }),
            }
          );
          success = response.ok;
        }
      }

      await snap.ref.update({
        status: success ? "sent" : "failed",
        sentAt: admin.firestore.Timestamp.now(),
        error: success ? null : "Provider returned non-success",
      });
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : "Unknown error";
      await snap.ref.update({
        status: "failed",
        sentAt: admin.firestore.Timestamp.now(),
        error: errMsg,
      });
    }
  }
);
