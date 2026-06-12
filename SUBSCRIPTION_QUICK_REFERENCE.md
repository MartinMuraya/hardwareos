# Subscription System - Quick Reference

## 🚀 Quick Start (5 Minutes)

### 1. Seed Plans
```dart
// In your setup screen or onboarding
await PlanSeeder.seedPlans();
// Creates: standard, pro, trial plans
```

### 2. Test Payment
```dart
// In your test widget
final res = await FunctionsService.call('createSubscriptionPayment', {
  'businessId': 'your-business-id',
  'planId': 'pro',
  'phoneNumber': '254712345678',
});

// Simulate payment success
await FunctionsService.call('simulateMpesaCallback', {
  'checkoutRequestId': res['checkoutRequestId'],
  'success': true,
});
```

### 3. Check Feature Access
```dart
bool hasAI = FeatureAccessService.hasFeature('pro', 'ai_assistant');
```

---

## 📚 API Reference

### FeatureAccessService
```dart
// Static methods
FeatureAccessService.hasFeature(planId, feature) → bool
FeatureAccessService.getFeatures(planId) → List<String>
FeatureAccessService.getAvailableFeatures(plan) → List<String>
FeatureAccessService.needsUpgrade(currentPlan, feature) → bool
FeatureAccessService.getProExclusiveFeatures() → List<String>
FeatureAccessService.getAvailablePlans() → List<String>
```

### PlanSeeder
```dart
// Static methods
PlanSeeder.seedPlans() → Future<bool>
PlanSeeder.plansExist() → Future<bool>
PlanSeeder.getPlanCount() → Future<int>
PlanSeeder.deleteAllPlans() → Future<bool>
```

### Business Model
```dart
// Getters
business.isOnTrial → bool
business.isExpired → bool
business.isActive → bool
business.isPro → bool
business.isStandard → bool
business.trialDaysLeft → int?
business.subscriptionDaysLeft → int?
```

### AuthProvider
```dart
// New getters
authProvider.subscriptionStatus → String? // "trial", "active", "expired"
authProvider.subscriptionEndsAt → DateTime?
```

---

## 🗂️ File Locations

| Component | Location |
|-----------|----------|
| Models | `lib/core/models/` |
| Services | `lib/core/services/` |
| Providers | `lib/core/providers/` |
| Screens | `lib/features/subscription/screens/` |
| Widgets | `lib/features/subscription/widgets/` |
| Router | `lib/core/router/app_router.dart` |
| Rules | `firestore.rules` |

---

## 🔑 Key Collections

```
/plans/{planId}
  - standard
  - pro
  - trial

/subscriptions/{subscriptionId}
  - businessId
  - plan
  - transactionStatus (pending, completed, failed)
  - amount
  - phoneNumber
  - createdAt

/businesses/{businessId}
  - plan
  - subscriptionStatus (trial, active, expired)
  - trialEndsAt
  - subscriptionStartsAt
  - subscriptionEndsAt
  - lastPaymentDate

/systemNotifications/{notificationId}
  - type (subscription_paid, trial_expiring, etc.)
  - businessId
  - businessName
  - amount
  - createdAt

/auditLogs/{logId}
  - action
  - targetId
  - targetType
  - performedBy
  - timestamp
  - details
```

---

## 🎯 Common Tasks

### Check if User is on Trial
```dart
business.isOnTrial  // true/false
```

### Check if Subscription Expired
```dart
business.isExpired  // true/false
```

### Get Days Until Expiry
```dart
business.subscriptionDaysLeft  // int or null
business.trialDaysLeft  // int or null
```

### Check Feature Access
```dart
bool canUseAI = FeatureAccessService.hasFeature(
  business.plan,
  'ai_assistant'
);
```

### Get All Standard Plan Features
```dart
List<String> features = FeatureAccessService.getFeatures('standard');
// Returns: ['inventory', 'sales', 'expenses', ...]
```

### Initialize Plans
```dart
// Check if exist
bool exist = await PlanSeeder.plansExist();

// Seed if not exist
if (!exist) {
  await PlanSeeder.seedPlans();
}
```

### Create M-Pesa Payment
```dart
final res = await FunctionsService.call('createSubscriptionPayment', {
  'businessId': business.id,
  'planId': 'pro',  // 'standard' or 'pro'
  'phoneNumber': '254712345678',
});

// Returns: {checkoutRequestId, isSimulation}
```

### Simulate Payment
```dart
await FunctionsService.call('simulateMpesaCallback', {
  'checkoutRequestId': res['checkoutRequestId'],
  'success': true,  // false to simulate failure
});
```

---

## 🎨 UI Components

### SubscriptionScreen
Full subscription management page
```dart
SubscriptionScreen()
```

### PlanCard
Individual plan card
```dart
PlanCard(
  planId: 'pro',
  name: 'Pro',
  price: 'KES 5,200',
  billing: '/month',
  features: features,
  isSelected: true,
  onSelect: () {},
)
```

### PlanSeederDialog
Admin dialog to initialize plans
```dart
showPlanSeederDialog(context);
```

---

## 🔒 Security Rules Summary

| Collection | Read | Write |
|-----------|------|-------|
| plans | Everyone | Cloud Functions only |
| subscriptions | Owner/SuperAdmin | Cloud Functions only |
| systemNotifications | Owner/SuperAdmin | Cloud Functions only |
| auditLogs | SuperAdmin only | Cloud Functions only |

---

## ⚙️ Riverpod Providers

```dart
// Get plans
final plans = await ref.read(plansProvider.future);

// Get subscription history
final history = await ref.read(
  subscriptionHistoryProvider(businessId).future
);

// Create subscription payment
final result = await ref.read(
  createSubscriptionPaymentProvider((
    businessId: id,
    planId: 'pro',
    phoneNumber: '254...'
  )).future
);

// Simulate callback
final result = await ref.read(
  simulateMpesaCallbackProvider((
    checkoutRequestId: id,
    success: true
  )).future
);
```

---

## 🚨 Route Guards

Automatic redirects:
```
If subscriptionStatus == 'expired':
  ❌ /dashboard → /subscription
  ❌ /inventory → /subscription
  ❌ /sales → /subscription
  ❌ /expenses → /subscription
  ❌ /reports → /subscription
  ❌ /team → /subscription
```

---

## 📊 Dashboard Metrics

Super Admin sees these KPIs:
```
- Total Businesses
- Active Businesses
- Pending Approvals
- Trial Accounts
- Expired Subscriptions
- Monthly Revenue
- Annual Revenue
- Platform Users
- Transactions (Sales)
```

---

## 🧪 Testing Tips

### Use Simulation Mode
- No M-Pesa credentials needed
- Set `success: true/false` in simulateMpesaCallback

### Fast Track Trial
- Manually set `trialEndsAt` to yesterday
- App treats as expired

### Test Route Guards
- Set `subscriptionStatus: 'expired'`
- Try accessing protected routes
- Should redirect to /subscription

### Check Audit Trail
- View `/auditLogs` collection
- See all subscription actions
- Verify payment logs

---

## 🔧 Configuration

### Environment Variables (Firebase)
```
MPESA_CONSUMER_KEY=your_key
MPESA_CONSUMER_SECRET=your_secret
MPESA_SHORTCODE=174379
MPESA_PASSKEY=bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919
MPESA_CALLBACK_URL=https://...
```

### If Not Set
- System uses **simulation mode**
- Payments can be tested with `simulateMpesaCallback`
- Perfect for development/staging

---

## 📞 Cloud Functions

| Function | Purpose | Input |
|----------|---------|-------|
| createSubscriptionPayment | Initiate M-Pesa payment | businessId, planId, phoneNumber |
| mpesaCallback | Handle payment confirmation | Callback from Safaricom |
| simulateMpesaCallback | Test without M-Pesa | checkoutRequestId, success |

---

## 🎓 Learning Path

1. **Understand**: Read SUBSCRIPTION_SETUP.md
2. **Explore**: Check models in `lib/core/models/`
3. **Seed**: Use PlanSeeder to create plans
4. **Test**: Call createSubscriptionPayment
5. **Verify**: Check Firestore collections
6. **Extend**: Add custom features using FeatureAccessService

---

## ❓ FAQ

**Q: How do new businesses get assigned a trial?**
A: Automatically via createBusiness Cloud Function (14 days)

**Q: How does payment work without M-Pesa credentials?**
A: Simulation mode creates pending records and simulateMpesaCallback processes them

**Q: Can Super Admin modify subscription dates?**
A: Yes, via /admin/subscriptions screen

**Q: What happens if subscription expires?**
A: User redirected to /subscription automatically, all features blocked

**Q: Can user downgrade from Pro to Standard?**
A: Yes, select different plan and pay - old plan ends, new starts

**Q: Where are payment receipts stored?**
A: In /subscriptions/{id} field "mpesaReceipt"

**Q: Is payment history visible to user?**
A: Yes, in /subscription screen under "Payment History"

**Q: Can trials be extended?**
A: Yes, Super Admin can edit trialEndsAt in /admin/subscriptions

---

**Last Updated**: 2026-06-12
**Status**: ✅ Production Ready

