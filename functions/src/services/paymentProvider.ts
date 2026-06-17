export interface PaymentRequest {
  amount: number;
  currency: string;
  phoneNumber: string;
  accountReference: string;
  transactionDesc: string;
  metadata?: Record<string, string>;
}

export interface PaymentResponse {
  success: boolean;
  transactionId: string;
  providerReference: string;
  raw?: Record<string, any>;
}

export interface PaymentCallbackData {
  providerReference: string;
  resultCode: number;
  resultDesc: string;
  receiptNumber?: string;
  amount?: number;
  phoneNumber?: string;
  transactionDate?: string;
  raw?: Record<string, any>;
}

export interface PaymentProvider {
  readonly name: string;
  initiatePayment(request: PaymentRequest): Promise<PaymentResponse>;
  processCallback(callbackData: PaymentCallbackData): Promise<{
    success: boolean;
    receiptNumber: string;
  }>;
}
