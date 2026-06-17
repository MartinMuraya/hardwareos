import axios from "axios";
import {
  PaymentProvider,
  PaymentRequest,
  PaymentResponse,
  PaymentCallbackData,
} from "./paymentProvider";

export class MpesaProvider implements PaymentProvider {
  readonly name = "mpesa";

  private consumerKey: string;
  private consumerSecret: string;
  private shortcode: string;
  private passkey: string;
  private callbackUrl: string;

  private environment: "sandbox" | "production";
  private baseUrl: string;

  constructor() {
    this.consumerKey = process.env.MPESA_CONSUMER_KEY || "";
    this.consumerSecret = process.env.MPESA_CONSUMER_SECRET || "";
    this.shortcode = process.env.MPESA_SHORTCODE || "174379";
    this.passkey =
      process.env.MPESA_PASSKEY ||
      "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919";
    this.callbackUrl =
      process.env.MPESA_CALLBACK_URL ||
      `https://mpesacallback-us-central1.run.app`;
    this.environment =
      (process.env.MPESA_ENVIRONMENT as "sandbox" | "production") || "sandbox";
    this.baseUrl =
      this.environment === "production"
        ? "https://api.safaricom.co.ke"
        : "https://sandbox.safaricom.co.ke";
  }

  async initiatePayment(request: PaymentRequest): Promise<PaymentResponse> {
    const authHeader = Buffer.from(
      `${this.consumerKey}:${this.consumerSecret}`
    ).toString("base64");

    const tokenRes = await axios.get(
      `${this.baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
      { headers: { Authorization: `Basic ${authHeader}` } }
    );
    const accessToken = tokenRes.data.access_token;

    const timestamp = new Date()
      .toISOString()
      .replace(/[^0-9]/g, "")
      .slice(0, 14);
    const password = Buffer.from(
      `${this.shortcode}${this.passkey}${timestamp}`
    ).toString("base64");

    const stkRes = await axios.post(
      `${this.baseUrl}/mpesa/stkpush/v1/processrequest`,
      {
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
      },
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );

    const checkoutRequestId: string =
      stkRes.data?.CheckoutRequestID ||
      "ws_CO_" + Math.random().toString(36).substring(2, 15);

    return {
      success: true,
      transactionId: checkoutRequestId,
      providerReference: checkoutRequestId,
      raw: stkRes.data,
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
