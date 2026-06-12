# Subscription & M-Pesa Billing System Setup Guide

## Overview
This guide walks you through setting up and testing the HardwareOS subscription system with M-Pesa billing integration.

## System Architecture

### Collections
- **plans**: Subscription plan definitions (Standard, Pro)
- **subscriptions**: Payment transaction records
- **businesses**: Extended with subscription fields
- **systemNotifications**: Subscription event notifications
- **auditLogs**: Activity tracking

### Subscription Lifecycle
1. New business registers → Assigned "trial" plan for 14 days
2. Business owner views subscription page
3. Owner selects plan and enters M-Pesa number
4. STK Push sent → Owner completes payment on phone
5. M-Pesa callback received → Subscription activated automatically
6. Business status updated → Features unlocked

---

## 1. Create Plans Collection

### Standard Plan
```
Collection: plans
Document ID: standard

{
  "id": "standard",
  "name": "Standard",
  "price": 2600,
  "currency": "KES",
  "billingCycle": "monthly",
  "maxUsers": 3,
  "features": [
    "inventory",
    "sales",
    "expenses",
    "reports",
    "customers",
    "suppliers"
  ]
}
```

### Pro Plan
```
Collection: plans
Document ID: pro

{
  "id": "pro",
  "name": "Pro",
  "price": 5200,
  "currency": "KES",
  "billingCycle": "monthly",
  "maxUsers": -1,
  "features": [
    "inventory",
    "sales",
    "expenses",
    "reports",
    "customers",
    "suppliers",
    "ai_assistant",
    "whatsapp_integration",
    "advanced_analytics",
    "forecasting"
  ]
}
```

---

## 2. Environment Variables (Firebase Functions)

Set these in your `.env` file or Firebase Functions configuration:

```
MPESA_CONSUMER_KEY=your_consumer_key
MPESA_CONSUMER_SECRET=your_consumer_secret
MPESA_SHORTCODE=174379
MPESA_PASSKEY=bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919
MPESA_CALLBACK_URL=https://your-deployed-function-url/mpesaCallback
```

### Sandbox Credentials
For testing, use Safaricom Daraja sandbox credentials:
- **Consumer Key**: `dGc5aEE2TkZXMFNpeTJqTjMzSVh` (example)
- **Consumer Secret**: `T2NiZjI2WVhVMkQyNjhGNjAyQnVr` (example)
- **Shortcode**: `174379`
- **Passkey**: `bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919`

### If Credentials Not Set
The system falls back to **simulation mode**:
- M-Pesa prompts are simulated
- Payments can be tested immediately using `simulateMpesaCallback`
- No real M-Pesa payment required for testing

---

## 3. Business Registration (Automatic Trial)

When a new business registers:

```javascript
// Cloud Function: createBusiness
// Automatically sets:
{
  "plan": "trial",
  "subscriptionStatus": "trial",
  "trialEndsAt": NOW + 14 days,
  "subscriptionStartsAt": null,
  "subscriptionEndsAt": null,
  "lastPaymentDate": null,
  "active": true
}
```

---

## 4. Testing the Payment Flow

### Option A: Simulation Mode (Recommended for Testing)

1. **Business owner navigates to /subscription**
2. **Selects a plan** (Standard or Pro)
3. **Enters M-Pesa phone number** (e.g., 254712345678)
4. **Clicks "Pay with M-Pesa STK Push"**
   - In simulation mode, prompt is logged (not actually sent)
   - A checkout request ID is generated
   - Payment record created with status "pending"

5. **Simulate Payment Success** (from console or your test app):
   ```dart
   // In your Flutter app (requires Riverpod setup):
   await FunctionsService.call('simulateMpesaCallback', {
     'checkoutRequestId': 'the-checkout-request-id',
     'success': true, // true = success, false = cancelled
   });
   ```

6. **Verify Updates in Firestore**:
   - `/businesses/{businessId}`:
     - `plan`: "standard" or "pro"
     - `subscriptionStatus`: "active"
     - `subscriptionStartsAt`: timestamp
     - `subscriptionEndsAt`: timestamp + 30 days
     - `lastPaymentDate`: timestamp

   - `/subscriptions/{subscriptionId}`:
     - `transactionStatus`: "completed"
     - `mpesaReceipt`: "MOCK..." or real receipt
     - `paidAt`: timestamp
     - `expiresAt`: timestamp + 30 days

### Option B: Real M-Pesa Payment (Production)

1. Ensure environment variables are set
2. Payment flow proceeds normally
3. Safaricom sends callback to your Cloud Function URL
4. Callback is validated and processed
5. All automatic updates occur as above

---

## 5. Feature Access

The `FeatureAccessService` checks plan permissions:

```dart
// Check if feature available
bool hasAI = FeatureAccessService.hasFeature('pro', 'ai_assistant');

// Get all features for plan
List<String> features = FeatureAccessService.getFeatures('standard');

// Check if upgrade needed
bool needsUpgrade = FeatureAccessService.needsUpgrade('standard', 'ai_assistant');
```

---

## 6. Route Protection

Expired subscriptions automatically redirect to `/subscription`:

```dart
// app_router.dart handles this:
// If subscriptionStatus == 'expired' and user tries to access:
// - /dashboard, /inventory, /sales, /expenses, /reports, /team
// They're redirected to /subscription
```

---

## 7. Subscription Screen UI

### Business Owner View (`/subscription`)

**Current Plan Section**
- Shows: Plan name, status (Trial/Active/Expired), days remaining
- Displays expiry date
- Shows warning if expired

**Available Plans Section**
- Standard: KES 2,600/month
- Pro: KES 5,200/month
- Click to select, shows features

**Payment Section** (appears when plan selected)
- Phone number input field
- "Pay with M-Pesa STK Push" button
- Error messages if any

**Payment History Section**
- Lists all previous transactions
- Shows: Plan, date, amount, status

---

## 8. Super Admin Dashboard

### Subscription Analytics Cards
- **Active Subscriptions**: Count of active subscriptions
- **Trial Accounts**: Count of users in trial
- **Expired Subscriptions**: Count of expired subscriptions
- **Monthly Revenue**: Sum of successful payments this month
- **Annual Revenue**: Sum of successful payments this year

### Subscription Management Screen (`/admin/subscriptions`)
- View all business subscriptions
- Edit subscription status, plan, dates
- Extend subscriptions
- Grant free months
- View payment history

---

## 9. Notifications

### System Notifications Triggered

**subscription_paid**
```javascript
{
  "type": "subscription_paid",
  "businessId": "...",
  "businessName": "...",
  "plan": "pro",
  "amount": 5200,
  "createdAt": timestamp
}
```

**subscription_trial_expiring** (future)
```javascript
{
  "type": "subscription_trial_expiring",
  "businessId": "...",
  "businessName": "...",
  "daysLeft": 3,
  "createdAt": timestamp
}
```

---

## 10. Audit Logs

All subscription events logged:
- `subscription_payment_initiated`
- `subscription_paid`
- `subscription_failed`
- `subscription_upgrade`
- `subscription_renewal`
- `subscription_expired`

View in Firestore: `/auditLogs`

---

## 11. Security Rules

**Public Collections**
- `plans`: All users can read

**Protected Collections**
- `subscriptions`: Only owner or Super Admin can read
- `systemNotifications`: Only owner or Super Admin can read
- `auditLogs`: Only Super Admin can read

**No Direct Writes**
- All writes through Cloud Functions only
- Prevents data tampering

---

## 12. Cloud Functions

### createSubscriptionPayment
**Purpose**: Initiate M-Pesa payment
**Input**:
- businessId
- planId (standard/pro)
- phoneNumber (254712345678)

**Returns**:
- checkoutRequestId
- isSimulation (true if in simulation mode)

**Side Effects**:
- Creates subscription record (pending)
- Logs audit event

### mpesaCallback
**Purpose**: Handle Safaricom payment callback
**Triggered by**: Safaricom Daraja API
**Side Effects**:
- Updates subscription (completed/failed)
- Updates business (plan, dates, status)
- Creates system notification
- Logs audit event

### simulateMpesaCallback
**Purpose**: Test payment flow
**Input**:
- checkoutRequestId
- success (boolean)

**Returns**:
- Success response

**Side Effects**:
- Same as mpesaCallback but with simulated receipt

---

## 13. Testing Checklist

- [ ] Create plans in Firestore (Standard, Pro)
- [ ] Register a new business (auto-assigns trial)
- [ ] Navigate to subscription page
- [ ] View current plan and trial days
- [ ] Select a plan
- [ ] Simulate payment success
- [ ] Verify business doc updated
- [ ] Verify subscription doc created
- [ ] Verify redirect to dashboard
- [ ] Check Super Admin dashboard shows new subscription
- [ ] Test expired subscription redirect to /subscription
- [ ] Verify audit logs recorded
- [ ] Check systemNotifications created

---

## 14. Troubleshooting

### Payment not triggering
1. Check if credentials are set (else uses simulation)
2. Verify phone number format: `254...`
3. Check Cloud Function logs for errors
4. Try simulateMpesaCallback to test end-to-end

### Business not updated after payment
1. Check mpesaCallback function logs
2. Verify Firestore security rules allow write
3. Check subscription record exists and has correct checkoutRequestId
4. Manually trigger simulateMpesaCallback to test

### Can't access subscription page when expired
1. Verify auth_provider exposes subscriptionStatus
2. Check app_router redirect logic
3. Test isExpired getter in Business model
4. Verify business.subscriptionStatus is "expired" in Firestore

### Feature access not working
1. Verify plans have correct feature lists
2. Test FeatureAccessService directly
3. Check plan IDs match (case-sensitive)

---

## Next Steps

1. **Set up plans** in Firestore
2. **Test registration** → verify auto-trial assignment
3. **Test payment flow** → use simulateMpesaCallback
4. **Deploy to production** → add real M-Pesa credentials
5. **Monitor** → check audit logs and notifications

