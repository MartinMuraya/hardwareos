// ============================================================
// M-Pesa Integration — Daraja STK Push & Callbacks
// ============================================================

import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";

const db = () => admin.firestore();

// -----------------------------------------------------------
// Helper: Get Daraja Access Token
// -----------------------------------------------------------
async function getDarajaToken(consumerKey: string, consumerSecret: string): Promise<string> {
  const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
  const response = await fetch("https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials", {
    headers: { Authorization: `Basic ${auth}` },
  });
  if (!response.ok) {
    throw new Error(`Daraja Token Error: ${await response.text()}`);
  }
  const data = await response.json() as { access_token: string };
  return data.access_token;
}

// -----------------------------------------------------------
// initiateStkPush
// Triggered by the POS when a cashier selects M-Pesa.
// -----------------------------------------------------------
export const initiateStkPush = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, phoneNumber, amount, reference, description } = request.data as {
    businessId: string;
    phoneNumber: string; // e.g. 2547...
    amount: number;
    reference: string;
    description?: string;
  };

  // 1. Fetch M-Pesa settings for this business
  const settingsSnap = await db().collection("payment_settings").doc(businessId).get();
  if (!settingsSnap.exists) {
    throw new HttpsError("failed-precondition", "M-Pesa settings not configured for this business.");
  }
  const settings = settingsSnap.data()!;
  if (!settings.mpesaEnabled) {
    throw new HttpsError("failed-precondition", "M-Pesa integration is currently disabled.");
  }

  const { consumerKey, consumerSecret, passkey, shortcode } = settings;

  try {
    const token = await getDarajaToken(consumerKey, consumerSecret);

    // Format phone number to 254...
    let formattedPhone = phoneNumber.replace(/[^0-9]/g, "");
    if (formattedPhone.startsWith("0")) formattedPhone = "254" + formattedPhone.substring(1);
    if (formattedPhone.startsWith("+")) formattedPhone = formattedPhone.substring(1);

    const timestamp = new Date().toISOString().replace(/[^0-9]/g, "").slice(0, 14);
    const password = Buffer.from(`${shortcode}${passkey}${timestamp}`).toString("base64");

    // We will need a callback URL deployed. For now, we will construct it dynamically.
    const callbackUrl = `https://${process.env.GCLOUD_PROJECT}.cloudfunctions.net/posMpesaCallback`;

    const payload = {
      BusinessShortCode: shortcode,
      Password: password,
      Timestamp: timestamp,
      TransactionType: "CustomerPayBillOnline",
      Amount: Math.ceil(amount), // Safaricom accepts integers
      PartyA: formattedPhone,
      PartyB: shortcode,
      PhoneNumber: formattedPhone,
      CallBackURL: callbackUrl,
      AccountReference: reference.substring(0, 12),
      TransactionDesc: description || "POS Payment",
    };

    const response = await fetch("https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const data: any = await response.json();

    if (!response.ok) {
      throw new Error(data.errorMessage || data.errorCode || "Unknown Safaricom Error");
    }

    // Record the STK request in Firestore to track status
    const reqRef = db().collection("mpesa_requests").doc(data.CheckoutRequestID);
    await reqRef.set({
      CheckoutRequestID: data.CheckoutRequestID,
      MerchantRequestID: data.MerchantRequestID,
      businessId,
      amount,
      phoneNumber: formattedPhone,
      reference,
      status: "PENDING",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, checkoutRequestId: data.CheckoutRequestID };

  } catch (error: any) {
    console.error("STK Push Error:", error.message);
    throw new HttpsError("internal", `M-Pesa Error: ${error.message}`);
  }
});

// -----------------------------------------------------------
// mpesaCallback
// Safaricom calls this URL after the user enters their PIN.
// -----------------------------------------------------------
export const posMpesaCallback = onRequest(SECURE_FN_OPTS, async (req, res) => {
  try {
    const callbackData = req.body.Body?.stkCallback;
    if (!callbackData) {
      res.status(400).send("Invalid payload");
      return;
    }

    const checkoutRequestId = callbackData.CheckoutRequestID;
    const resultCode = callbackData.ResultCode; // 0 means success
    const resultDesc = callbackData.ResultDesc;

    const reqRef = db().collection("mpesa_requests").doc(checkoutRequestId);
    const docSnap = await reqRef.get();
    
    if (!docSnap.exists) {
      console.warn("Received callback for unknown STK Push:", checkoutRequestId);
      res.status(200).send("OK");
      return;
    }

    const reqData = docSnap.data()!;

    // M-9: Idempotency check to ignore duplicate callbacks from Safaricom
    if (reqData.status === "COMPLETED" || reqData.status === "FAILED") {
      res.status(200).send("OK");
      return;
    }

    if (resultCode === 0) {
      // Success
      const meta = callbackData.CallbackMetadata?.Item || [];
      const getMeta = (name: string) => meta.find((m: any) => m.Name === name)?.Value;
      
      const receiptNumber = getMeta("MpesaReceiptNumber");
      
      await reqRef.update({
        status: "COMPLETED",
        resultCode,
        resultDesc,
        receiptNumber,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // You can also emit an event or update the `sales` collection directly if `reference` is a saleId.
      if (reqData.reference) {
        // e.g. update Sale status to "Paid" if we kept it as "Pending"
        const saleRef = db().collection("sales").doc(reqData.reference);
        await saleRef.set({
          mpesaReceipt: receiptNumber,
          mpesaStatus: "Paid"
        }, { merge: true });
      }

    } else {
      // Failed / Cancelled
      await reqRef.update({
        status: "FAILED",
        resultCode,
        resultDesc,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.status(200).send("OK");

  } catch (error) {
    console.error("M-Pesa Callback Error:", error);
    res.status(500).send("Internal Server Error");
  }
});
