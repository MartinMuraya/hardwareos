import {
  PaymentProvider,
  PaymentRequest,
  PaymentResponse,
  PaymentCallbackData,
} from "./paymentProvider";

import { defineSecret, defineString } from "firebase-functions/params";

export const mpesaConsumerKey = defineSecret("MPESA_CONSUMER_KEY");
export const mpesaConsumerSecret = defineSecret("MPESA_CONSUMER_SECRET");
export const mpesaPasskey = defineSecret("MPESA_PASSKEY");
export const mpesaShortcode = defineString("MPESA_SHORTCODE", { default: "174379" });
export const mpesaCallbackUrl = defineString("MPESA_CALLBACK_URL", { default: "https://mpesacallback-us-central1.run.app" });
export const mpesaEnvironment = defineString("MPESA_ENVIRONMENT", { default: "sandbox" });
export const mpesaWebhookSecret = defineSecret("MPESA_WEBHOOK_SECRET");

export class MpesaProvider implements PaymentProvider {
  readonly name = "mpesa";

  private get consumerKey(): string { return mpesaConsumerKey.value(); }
  private get consumerSecret(): string { return mpesaConsumerSecret.value(); }
  private get shortcode(): string { return mpesaShortcode.value(); }
  private get passkey(): string { return mpesaPasskey.value(); }
  private get callbackUrl(): string { return mpesaCallbackUrl.value(); }
  private get environment(): string { return mpesaEnvironment.value(); }
  private get webhookSecret(): string {
    try { return mpesaWebhookSecret.value(); } catch { return "dummy_secret"; }
  }
  private get baseUrl(): string {
    return this.environment === "production"
      ? "https://api.safaricom.co.ke"
      : "https://sandbox.safaricom.co.ke";
  }

  constructor() {}

  async initiatePayment(request: PaymentRequest): Promise<PaymentResponse> {
    const authHeader = Buffer.from(
      `${this.consumerKey}:${this.consumerSecret}`
    ).toString("base64");

    const tokenRes = await fetch(
      `${this.baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
      { headers: { Authorization: `Basic ${authHeader}` } }
    );
    const tokenData = await tokenRes.json() as any;
    const accessToken = tokenData.access_token;

    const timestamp = new Date()
      .toISOString()
      .replace(/[^0-9]/g, "")
      .slice(0, 14);
    const password = Buffer.from(
      `${this.shortcode}${this.passkey}${timestamp}`
    ).toString("base64");

    const stkRes = await fetch(
      `${this.baseUrl}/mpesa/stkpush/v1/processrequest`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          BusinessShortCode: this.shortcode,
          Password: password,
          Timestamp: timestamp,
          TransactionType: "CustomerPayBillOnline",
          Amount: request.amount,
          PartyA: request.phoneNumber,
          PartyB: this.shortcode,
          PhoneNumber: request.phoneNumber,
          CallBackURL: this.callbackUrl,
          AccountReference: request.accountReference.substring(0, 12),
          TransactionDesc: request.transactionDesc.substring(0, 20),
        }),
      }
    );
    const stkData = await stkRes.json() as any;

    const checkoutRequestId: string =
      stkData?.CheckoutRequestID ||
      "ws_CO_" + Math.random().toString(36).substring(2, 15);

    return {
      success: true,
      transactionId: checkoutRequestId,
      providerReference: checkoutRequestId,
      raw: stkData,
    };
  }

  async processCallback(callbackData: PaymentCallbackData): Promise<{
    success: boolean;
    receiptNumber: string;
  }> {
    if (callbackData.resultCode === 0) {
      return {
        success: true,
        receiptNumber: callbackData.receiptNumber || "",
      };
    }
    return { success: false, receiptNumber: "" };
  }
}
