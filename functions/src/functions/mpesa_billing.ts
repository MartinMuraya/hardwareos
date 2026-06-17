import * as admin from "firebase-admin";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { MpesaProvider } from "../services/mpesaProvider";
import { assertBusinessMember } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

const mpesa = new MpesaProvider();

// -----------------------------------------------------------
// Helper: compute next expiry date (always 30 days from now)
// -----------------------------------------------------------
function computeNextExpiry(): admin.firestore.Timestamp {
  const d = new Date();
  d.setDate(d.getDate() + 30);
  return admin.firestore.Timestamp.fromDate(d);
}

// -----------------------------------------------------------
// createSubscriptionPayment
// -----------------------------------------------------------
export const createSubscriptionPayment = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

  const { businessId, planId, phoneNumber } = request.data as {
    businessId: string;
    planId: "starter" | "pro";
    phoneNumber: string;
  };

  if (!businessId || !planId || !phoneNumber) {
    throw new HttpsError("invalid-argument", "businessId, planId, and phoneNumber are required");
  }

  // Tenant isolation: caller must be a member of this business
  await assertBusinessMember(request.auth.uid, businessId);

  // Validate phone format (e.g. 254712345678)
  const phoneRegex = /^254(7|1|3)\d{8}$/;
  if (!phoneRegex.test(phoneNumber)) {
    throw new HttpsError("invalid-argument", "Invalid M-Pesa phone number format. Must start with 254.");
  }

  // Rate limit: prevent duplicate pending payments for the same business
  const existingPending = await db()
    .collection("subscriptions")
    .where("businessId", "==", businessId)
    .where("transactionStatus", "==", "pending")
    .limit(1)
    .get();
  if (!existingPending.empty) {
    throw new HttpsError("aborted", "You already have a pending payment. Please wait or cancel before retrying.");
  }

  // Fetch plan info
  const planDoc = await db().collection("plans").doc(planId).get();
  if (!planDoc.exists) {
    throw new HttpsError("not-found", `Plan ${planId} not found`);
  }
  const planData = planDoc.data()!;
  const amount = planData.price;
  const currency = planData.currency || "KES";

  // Fetch business info
  const bizDoc = await db().collection("businesses").doc(businessId).get();
  if (!bizDoc.exists) {
    throw new HttpsError("not-found", "Business not found");
  }
  const bizData = bizDoc.data()!;

  // Generate checkout request ID
  const checkoutRequestId = "ws_CO_" + Math.random().toString(36).substring(2, 15);

  // Create pending subscription transaction record
  const subscriptionId = db().collection("subscriptions").doc().id;
  const subscriptionPayload = {
    id: subscriptionId,
    businessId,
    businessName: bizData.name,
    ownerUid: request.auth.uid,
    plan: planId,
    amount,
    currency,
    phoneNumber,
    transactionStatus: "pending",
    mpesaReceipt: "",
    checkoutRequestId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    paidAt: null,
    expiresAt: null,
    isRenewal: bizData.subscriptionStatus === "active" || bizData.subscriptionStatus === "grace_period" || bizData.subscriptionStatus === "expired",
  };

  await db().collection("subscriptions").doc(subscriptionId).set(subscriptionPayload);

  // Create audit log for payment initialization
  await db().collection("auditLogs").add({
    action: "subscription_payment_initiated",
    targetId: subscriptionId,
    targetType: "subscription",
    performedBy: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    details: { businessId, planId, amount, phoneNumber, checkoutRequestId, isSimulation: false },
  });

  // -----------------------------------------------------------
  // Trigger Real Daraja STK Push via MpesaProvider
  // -----------------------------------------------------------

  try {
    const stkRes = await mpesa.initiatePayment({
      amount,
      currency,
      phoneNumber,
      accountReference: (bizData.name || "HardwareOS").substring(0, 12),
      transactionDesc: `HardwareOS ${planId}`,
    });

    const resolvedCheckoutId = stkRes.providerReference || checkoutRequestId;

    // Update with real checkout request ID if returned
    await db().collection("subscriptions").doc(subscriptionId).update({
      checkoutRequestId: resolvedCheckoutId,
    });

    return { success: true, checkoutRequestId: resolvedCheckoutId, isSimulation: false };
  } catch (error: any) {
    console.error("Daraja Error:", error.response?.data || error.message);
    throw new HttpsError("internal", `Failed to invoke Safaricom STK Push: ${error.message}`);
  }
});

// -----------------------------------------------------------
// mpesaCallback
// webhook callback called directly by Safaricom
// -----------------------------------------------------------
export const mpesaCallback = onRequest({ cors: true }, async (req, res) => {
  try {
    const callbackData = req.body;
    console.log("M-Pesa Callback received:", JSON.stringify(callbackData));

    const stkCallback = callbackData?.Body?.stkCallback;
    if (!stkCallback) {
      res.status(400).send("Invalid callback payload format");
      return;
    }

    const { CheckoutRequestID, ResultCode, ResultDesc } = stkCallback;

    // Locate subscription record
    const subSnap = await db()
      .collection("subscriptions")
      .where("checkoutRequestId", "==", CheckoutRequestID)
      .limit(1)
      .get();

    if (subSnap.empty) {
      console.error(`Subscription record with checkoutRequestId ${CheckoutRequestID} not found.`);
      res.status(404).send("CheckoutRequestID not found");
      return;
    }

    const subDoc = subSnap.docs[0];
    const subData = subDoc.data();

    // Process via MpesaProvider
    let mpesaReceipt = "";
    if (ResultCode === 0) {
      const metadataItems = stkCallback?.CallbackMetadata?.Item || [];
      for (const item of metadataItems) {
        if (item.Name === "MpesaReceiptNumber") {
          mpesaReceipt = item.Value;
        }
      }
    }

    const callbackResult = await mpesa.processCallback({
      providerReference: CheckoutRequestID,
      resultCode: ResultCode || 1,
      resultDesc: ResultDesc || "",
      receiptNumber: mpesaReceipt,
    });

    if (callbackResult.success) {
      const paidAt = admin.firestore.FieldValue.serverTimestamp();
      const expiresAt = computeNextExpiry();

      const batch = db().batch();

      // 1. Update subscription transaction
      batch.update(subDoc.ref, {
        transactionStatus: "completed",
        mpesaReceipt: callbackResult.receiptNumber,
        paidAt,
        expiresAt,
      });

      // 2. Update business details
      const bizRef = db().collection("businesses").doc(subData.businessId);
      batch.update(bizRef, {
        plan: subData.plan,
        subscriptionStatus: "active",
        subscriptionStartsAt: paidAt,
        subscriptionEndsAt: expiresAt,
        lastPaymentDate: paidAt,
        active: true,
        gracePeriodEndsAt: null,
      });

      // 3. System notification
      const notificationRef = db().collection("systemNotifications").doc();
      batch.set(notificationRef, {
        id: notificationRef.id,
        type: "subscription_paid",
        businessId: subData.businessId,
        businessName: subData.businessName,
        plan: subData.plan,
        amount: subData.amount,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 4. Subscription history event
      const isRenewal = subData.isRenewal === true;
      const histRef = db().collection("subscriptionHistory").doc();
      batch.set(histRef, {
        id: histRef.id,
        businessId: subData.businessId,
        businessName: subData.businessName,
        eventType: isRenewal ? "subscription_renewed" : "subscription_activated",
        description: isRenewal
          ? `Subscription renewed to ${subData.plan} plan. KES ${subData.amount} paid.`
          : `Subscription activated: ${subData.plan} plan. KES ${subData.amount} paid.`,
        plan: subData.plan,
        previousStatus: null,
        newStatus: "active",
        details: { amount: subData.amount, mpesaReceipt: callbackResult.receiptNumber, isRenewal },
        performedBy: subData.ownerUid || "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 5. Audit Log
      const auditRef = db().collection("auditLogs").doc();
      batch.set(auditRef, {
        action: "subscription_paid",
        targetId: subData.businessId,
        targetType: "business",
        performedBy: subData.ownerUid || "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: { plan: subData.plan, amount: subData.amount, mpesaReceipt: callbackResult.receiptNumber },
      });

      await batch.commit();
      console.log(`Successfully activated/renewed subscription for business: ${subData.businessName} (plan: ${subData.plan})`);
    } else {
      // Payment failed
      const batch = db().batch();

      batch.update(subDoc.ref, {
        transactionStatus: "failed",
      });

      // Subscription history event
      const histRef = db().collection("subscriptionHistory").doc();
      batch.set(histRef, {
        id: histRef.id,
        businessId: subData.businessId,
        businessName: subData.businessName,
        eventType: "payment_failed",
        description: `Payment failed for ${subData.plan} plan. ${ResultDesc || ""}`,
        plan: subData.plan,
        previousStatus: null,
        newStatus: "failed",
        details: { amount: subData.amount, errorDesc: ResultDesc },
        performedBy: subData.ownerUid || "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Audit Log
      const auditRef = db().collection("auditLogs").doc();
      batch.set(auditRef, {
        action: "subscription_failed",
        targetId: subData.businessId,
        targetType: "business",
        performedBy: subData.ownerUid || "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: { plan: subData.plan, errorDesc: ResultDesc },
      });

      await batch.commit();
    }

    res.status(200).send("OK");
  } catch (error: any) {
    console.error("Error processing M-Pesa Callback:", error);
    res.status(500).send(error.message || "Internal Server Error");
  }
});

// -----------------------------------------------------------
// simulateMpesaCallback
// Admin-only helper to test end-to-end payment loop instantly
// -----------------------------------------------------------
export const simulateMpesaCallback = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

  // Production safety: only super admins can simulate payments
  const adminSnap = await db()
    .collection("platformAdmins")
    .doc(request.auth.uid)
    .get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Only platform administrators can simulate payments.");
  }

  const { checkoutRequestId, success } = request.data as { checkoutRequestId: string; success: boolean };

  if (!checkoutRequestId) {
    throw new HttpsError("invalid-argument", "checkoutRequestId is required");
  }

  // Find transaction
  const subSnap = await db()
    .collection("subscriptions")
    .where("checkoutRequestId", "==", checkoutRequestId)
    .limit(1)
    .get();

  if (subSnap.empty) {
    throw new HttpsError("not-found", "checkoutRequestId not found");
  }

  const subDoc = subSnap.docs[0];
  const subData = subDoc.data();

  if (success) {
    const mpesaReceipt = "MOCK" + Math.random().toString(36).substring(2, 10).toUpperCase();
    const paidAt = admin.firestore.FieldValue.serverTimestamp();
    const expiresAt = computeNextExpiry();

    const batch = db().batch();

    batch.update(subDoc.ref, {
      transactionStatus: "completed",
      mpesaReceipt,
      paidAt,
      expiresAt,
    });

    const bizRef = db().collection("businesses").doc(subData.businessId);
    batch.update(bizRef, {
      plan: subData.plan,
      subscriptionStatus: "active",
      subscriptionStartsAt: paidAt,
      subscriptionEndsAt: expiresAt,
      lastPaymentDate: paidAt,
      active: true,
      gracePeriodEndsAt: null,
    });

    const notificationRef = db().collection("systemNotifications").doc();
    batch.set(notificationRef, {
      id: notificationRef.id,
      type: "subscription_paid",
      businessId: subData.businessId,
      businessName: subData.businessName,
      plan: subData.plan,
      amount: subData.amount,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const isRenewal = subData.isRenewal === true;
    const histRef = db().collection("subscriptionHistory").doc();
    batch.set(histRef, {
      id: histRef.id,
      businessId: subData.businessId,
      businessName: subData.businessName,
      eventType: isRenewal ? "subscription_renewed" : "subscription_activated",
      description: isRenewal
        ? `Subscription renewed to ${subData.plan} plan. KES ${subData.amount} paid.`
        : `Subscription activated: ${subData.plan} plan. KES ${subData.amount} paid.`,
      plan: subData.plan,
      previousStatus: null,
      newStatus: "active",
      details: { amount: subData.amount, mpesaReceipt, isRenewal, simulated: true },
      performedBy: request.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    const auditRef = db().collection("auditLogs").doc();
    batch.set(auditRef, {
      action: "subscription_paid",
      targetId: subData.businessId,
      targetType: "business",
      performedBy: request.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: { plan: subData.plan, amount: subData.amount, mpesaReceipt, simulated: true },
    });

    await batch.commit();
  } else {
    const batch = db().batch();

    batch.update(subDoc.ref, {
      transactionStatus: "failed",
    });

    const histRef = db().collection("subscriptionHistory").doc();
    batch.set(histRef, {
      id: histRef.id,
      businessId: subData.businessId,
      businessName: subData.businessName,
      eventType: "payment_failed",
      description: `Simulated payment failed for ${subData.plan} plan.`,
      plan: subData.plan,
      previousStatus: null,
      newStatus: "failed",
      details: { amount: subData.amount, simulated: true },
      performedBy: request.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    const auditRef = db().collection("auditLogs").doc();
    batch.set(auditRef, {
      action: "subscription_failed",
      targetId: subData.businessId,
      targetType: "business",
      performedBy: request.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: { plan: subData.plan, simulated: true },
    });

    await batch.commit();
  }

  return { success: true };
});
