import * as admin from "firebase-admin";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import axios from "axios";

const db = () => admin.firestore();

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

  // Validate phone format (e.g. 254712345678)
  const phoneRegex = /^254(7|1|3)\d{8}$/;
  if (!phoneRegex.test(phoneNumber)) {
    throw new HttpsError("invalid-argument", "Invalid M-Pesa phone number format. Must start with 254.");
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

  // Generate checkout request ID (or simulate one)
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
  // Trigger Real Daraja STK Push
  // -----------------------------------------------------------

  try {
    const consumerKey = process.env.MPESA_CONSUMER_KEY!;
    const consumerSecret = process.env.MPESA_CONSUMER_SECRET!;
    const shortcode = process.env.MPESA_SHORTCODE || "174379";
    const passkey = process.env.MPESA_PASSKEY || "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919";
    const callbackUrl = process.env.MPESA_CALLBACK_URL || `https://mpesacallback-us-central1.run.app`;

    // 1. Get OAuth token
    const authHeader = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
    const tokenRes = await axios.get("https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials", {
      headers: { Authorization: `Basic ${authHeader}` }
    });
    const accessToken = tokenRes.data.access_token;

    // 2. Generate password & timestamp
    const timestamp = new Date().toISOString().replace(/[^0-9]/g, "").slice(0, 14);
    const password = Buffer.from(`${shortcode}${passkey}${timestamp}`).toString("base64");

    // 3. Initiate STK Push
    const stkRes = await axios.post("https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest", {
      BusinessShortCode: shortcode,
      Password: password,
      Timestamp: timestamp,
      TransactionType: "CustomerPayBillOnline",
      Amount: amount,
      PartyA: phoneNumber,
      PartyB: shortcode,
      PhoneNumber: phoneNumber,
      CallBackURL: callbackUrl,
      AccountReference: bizData.name.substring(0, 12),
      TransactionDesc: `HardwareOS ${planId}`
    }, {
      headers: { Authorization: `Bearer ${accessToken}` }
    });

    // Update with real checkout request ID if returned
    if (stkRes.data && stkRes.data.CheckoutRequestID) {
      await db().collection("subscriptions").doc(subscriptionId).update({
        checkoutRequestId: stkRes.data.CheckoutRequestID
      });
    }

    return { success: true, checkoutRequestId: stkRes.data.CheckoutRequestID || checkoutRequestId, isSimulation: false };
  } catch (error: any) {
    // Throw an error so the frontend knows the STK Push failed
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

    if (ResultCode === 0) {
      // Payment Successful
      let mpesaReceipt = "";
      const metadataItems = stkCallback?.CallbackMetadata?.Item || [];
      for (const item of metadataItems) {
        if (item.Name === "MpesaReceiptNumber") {
          mpesaReceipt = item.Value;
        }
      }

      const paidAt = admin.firestore.FieldValue.serverTimestamp();
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 30);

      const batch = db().batch();

      // 1. Update subscription transaction
      batch.update(subDoc.ref, {
        transactionStatus: "completed",
        mpesaReceipt,
        paidAt,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      });

      // 2. Update business details
      const bizRef = db().collection("businesses").doc(subData.businessId);
      batch.update(bizRef, {
        plan: subData.plan,
        subscriptionStatus: "active",
        subscriptionStartsAt: paidAt,
        subscriptionEndsAt: admin.firestore.Timestamp.fromDate(expiresAt),
        lastPaymentDate: paidAt,
        active: true,
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

      // 4. Audit Log
      const auditRef = db().collection("auditLogs").doc();
      batch.set(auditRef, {
        action: "subscription_paid",
        targetId: subData.businessId,
        targetType: "business",
        performedBy: subData.ownerUid || "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: { plan: subData.plan, amount: subData.amount, mpesaReceipt },
      });

      await batch.commit();
      console.log(`Successfully activated subscription for business: ${subData.businessName} (plan: ${subData.plan})`);
    } else {
      // Payment failed
      await db().collection("subscriptions").doc(subDoc.id).update({
        transactionStatus: "failed",
      });

      // Audit Log
      await db().collection("auditLogs").add({
        action: "subscription_failed",
        targetId: subData.businessId,
        targetType: "business",
        performedBy: subData.ownerUid || "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: { plan: subData.plan, errorDesc: ResultDesc },
      });
    }

    res.status(200).send("OK");
  } catch (error: any) {
    console.error("Error processing M-Pesa Callback:", error);
    res.status(500).send(error.message || "Internal Server Error");
  }
});

// -----------------------------------------------------------
// simulateMpesaCallback
// Helper callable to test end-to-end payment loop instantly
// -----------------------------------------------------------
export const simulateMpesaCallback = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

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

  // Create simulated Safaricom callback body
  const mockCallback = {
    Body: {
      stkCallback: {
        MerchantRequestID: "mock_merchant_123",
        CheckoutRequestID: checkoutRequestId,
        ResultCode: success ? 0 : 1032, // 1032 = Cancelled by user
        ResultDesc: success ? "The service request is processed successfully." : "Request cancelled by user.",
        CallbackMetadata: success ? {
          Item: [
            { Name: "Amount", Value: subData.amount },
            { Name: "MpesaReceiptNumber", "Value": "MPESA" + Math.random().toString(36).substring(2, 10).toUpperCase() },
            { Name: "TransactionDate", Value: parseInt(new Date().toISOString().replace(/[^0-9]/g, "").slice(0, 14)) },
            { Name: "PhoneNumber", Value: parseInt(subData.phoneNumber) }
          ]
        } : null
      }
    }
  };

  // Perform internal call processing
  // We write to database directly to ensure completion in simulation
  const ResultCode = mockCallback.Body.stkCallback.ResultCode;
  const ResultDesc = mockCallback.Body.stkCallback.ResultDesc;

  if (ResultCode === 0) {
    let mpesaReceipt = "MOCK" + Math.random().toString(36).substring(2, 10).toUpperCase();
    const paidAt = admin.firestore.FieldValue.serverTimestamp();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    const batch = db().batch();

    batch.update(subDoc.ref, {
      transactionStatus: "completed",
      mpesaReceipt,
      paidAt,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

    const bizRef = db().collection("businesses").doc(subData.businessId);
    batch.update(bizRef, {
      plan: subData.plan,
      subscriptionStatus: "active",
      subscriptionStartsAt: paidAt,
      subscriptionEndsAt: admin.firestore.Timestamp.fromDate(expiresAt),
      lastPaymentDate: paidAt,
      active: true,
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
    await db().collection("subscriptions").doc(subDoc.id).update({
      transactionStatus: "failed",
    });

    await db().collection("auditLogs").add({
      action: "subscription_failed",
      targetId: subData.businessId,
      targetType: "business",
      performedBy: request.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: { plan: subData.plan, errorDesc: ResultDesc, simulated: true },
    });
  }

  return { success: true };
});
