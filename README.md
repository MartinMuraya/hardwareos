<p align="center">
  <img src="assets/images/logo.png" alt="HardwareOS Logo" width="120" height="120" />
</p>

<h1 align="center">HardwareOS</h1>

<p align="center">
  <strong>Multi-Tenant SaaS ERP for Hardware Stores — East Africa</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter" alt="Flutter 3.38" />
  <img src="https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart" alt="Dart 3.10" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase" alt="Firebase" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
</p>

---

## Overview

HardwareOS is a purpose-built ERP platform for hardware and building-material retailers in East Africa. It replaces fragmented workflows (paper ledgers, separate POS systems, manual stock tracking) with a unified, cloud-based solution accessible from any device.

The system is **multi-tenant**: each hardware store gets its own isolated environment under a subscription plan, while a central super-admin panel manages the entire platform.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter Client                      │
│  (Web / Android / Windows — responsive Material 3)   │
│                                                      │
│  ┌─────────┐  ┌──────────┐  ┌────────────────────┐  │
│  │Provider  │  │ Riverpod │  │ go_router          │  │
│  │(auth,    │  │(subscrip-│  │(auth guards,       │  │
│  │ business,│  │ tions)   │  │ ShellRoutes)       │  │
│  │ theme)   │  │          │  │                    │  │
│  └─────────┘  └──────────┘  └────────────────────┘  │
└───────────────────┬─────────────────────────────────┘
                    │ HTTPS Callable Functions
                    ▼
┌─────────────────────────────────────────────────────┐
│              Firebase Cloud Functions                 │
│  (TypeScript — 10 function modules)                  │
│                                                      │
│  auth │ inventory │ sales │ expenses │ dashboard     │
│  reports │ mpesa_billing │ super_admin │ ...         │
└───────────────────┬─────────────────────────────────┘
                    │ Admin SDK
                    ▼
┌─────────────────────────────────────────────────────┐
│                   Cloud Firestore                     │
│  (Strict security — writes only through functions)   │
│                                                      │
│  Users │ Businesses │ Products │ Sales │ Expenses    │
│  Subscriptions │ Plans │ Notifications               │
└─────────────────────────────────────────────────────┘
```

**Key principle:** The client never writes directly to Firestore. Every data mutation goes through an HTTPS Callable Function, enforcing authentication, authorization, plan limits, and data validation server-side.

---

## Features

### Point of Sale
- Product search with real-time filtering
- Cart management with quantity controls
- Payment methods: Cash, M-Pesa, Credit
- Receipt dialog with checkout summary
- Full sales history with search

### Inventory Management
- Full CRUD with fields: name, SKU, category, quantity, cost/selling price, reorder level
- Stock status indicators: Good / Low / Critical
- Filter by category
- Low-stock alerts on dashboard

### Expenses
- Categorised expense tracking
- Infinite-scroll pagination
- Add expense with amount, category, notes

### Reports & Analytics
- Period-based reporting (Today / This Week / This Month)
- Profit & Loss statement
- Sales breakdown by payment method
- Top-selling products
- Expense breakdown by category
- Interactive charts (fl_chart)

### Team Management
- View team members with role badges (Owner / Manager / Staff)
- Invite new members via dialog
- Role-based access control

### Subscriptions & Billing
- **14-day free trial** with full Pro access
- Plans: Starter (KES 2,600/mo, 3 users) and Pro (KES 5,200/mo, unlimited)
- M-Pesa STK Push payment integration
- Auto-detection of expired subscriptions with route guarding
- Payment history with real-time confirmation via Firestore listener
- Simulation mode for testing

### Super Admin Panel
- Platform-wide KPIs: total businesses, active/pending/suspended counts
- Manage all businesses (approve, suspend)
- Oversee subscriptions across tenants
- CRUD subscription plans
- User management (disable, role change, password reset)
- System settings: maintenance mode, broadcast banners, alert levels, backup triggers

### Feature Gating by Plan

| Feature | Trial / Starter | Pro |
|---|---|---|
| Core (POS, Inventory, Expenses, Reports) | ✓ | ✓ |
| Team (3 users) | ✓ | Unlimited |
| AI Assistant | ✗ | ✓ |
| WhatsApp Integration | ✗ | ✓ |
| Advanced Analytics | ✗ | ✓ |
| Demand Forecasting | ✗ | ✓ |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter 3.38 / Dart 3.10 |
| **Backend** | Firebase Cloud Functions (TypeScript) |
| **Database** | Cloud Firestore |
| **Auth** | Firebase Auth (Email/Password + Google Sign-In) |
| **Payments** | Safaricom M-Pesa STK Push |
| **State** | Provider + Riverpod |
| **Routing** | go_router with ShellRoute |
| **UI** | Material Design 3, Google Fonts (Inter), fl_chart |
| **Storage** | Firebase Storage (profile pictures) |
| **Infrastructure** | Firebase Hosting, Firestore Security Rules |

---

## Project Structure

```
hardwareos/
├── lib/
│   ├── core/
│   │   ├── models/            # Data models (business, product, sale, etc.)
│   │   ├── providers/         # State management (auth, business, theme)
│   │   ├── services/          # Functions service, feature access, plan seeder
│   │   ├── router/            # go_router configuration with guards
│   │   ├── theme/             # Colors, light/dark themes
│   │   ├── utils/             # Responsive layout helpers
│   │   └── widgets/           # Shared widgets (scaffold, empty state, overlay)
│   ├── features/
│   │   ├── admin/             # Super admin dashboard & management
│   │   ├── auth/              # Login, register, verification, password reset
│   │   ├── dashboard/         # KPI cards, quick actions, alerts
│   │   ├── expenses/          # Expense tracking
│   │   ├── inventory/         # Product management
│   │   ├── reports/           # Analytics & charts
│   │   ├── sales/             # POS & sales history
│   │   ├── subscription/      # Plan selection & payment
│   │   └── team/              # Staff management
│   └── main.dart
├── functions/
│   └── src/
│       ├── config/            # Plan limits configuration
│       ├── functions/         # Cloud Function modules (10 modules)
│       ├── middleware/        # Function middleware
│       └── index.ts           # Function entry point
├── web/                       # Web-specific files
├── assets/                    # Images and icons
├── firebase.json              # Firebase project config
├── firestore.rules            # Security rules
└── pubspec.yaml
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Node.js 18+
- A Firebase project with billing enabled (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/your-org/hardwareos.git
cd hardwareos

# 2. Install Flutter dependencies
flutter pub get

# 3. Install Cloud Functions dependencies
cd functions
npm install
cd ..

# 4. Configure Firebase
#    - Copy your firebase_options.dart to lib/
#    - Copy google-services.json to android/app/
#    - Update .env or config with your M-Pesa credentials (for production)

# 5. Start Firebase emulators
firebase emulators:start

# 6. Run the app
flutter run
```

### Environment
The project uses Firebase emulators for local development. The emulator suite includes:
- **Auth** (port 9099)
- **Functions** (port 5001)
- **Firestore** (port 8080)
- **Hosting** (port 5000)
- **UI** (port 4000)

---

## Configuration

### Web
Google Sign-In on web requires the `Cross-Origin-Opener-Policy` header:
```json
// firebase.json
{
  "headers": [{
    "source": "**",
    "headers": [
      { "key": "Cross-Origin-Opener-Policy", "value": "same-origin-allow-popups" },
      { "key": "Cross-Origin-Embedder-Policy", "value": "unsafe-none" }
    ]
  }]
}
```

For the Flutter dev server:
```bash
flutter run --web-header='Cross-Origin-Opener-Policy: same-origin-allow-popups'
```

### M-Pesa
Subscription payments use Safaricom's M-Pesa STK Push API. The system includes a simulation mode for testing without real credentials. Configure production credentials in your Cloud Functions environment.

---

## Deployment

```bash
# Build the Flutter web app
flutter build web

# Deploy Firebase resources
firebase deploy --only hosting,functions,firestore

# Deploy a specific function
firebase deploy --only functions:mpesaBilling
```

---

## Development Notes

### State Management
- **Provider** is used for global, app-wide state (auth, business, theme)
- **Riverpod** is used for subscription/plan data that benefits from its auto-dispose and family modifiers

### Routing Guards
The `go_router` redirect logic enforces a strict flow:
1. Not authenticated → `/login`
2. Email not verified → `/verify-email`
3. Business registration incomplete → `/register`
4. Business pending approval → `/pending-approval`
5. Subscription expired (on protected routes) → `/subscription`
6. Super admin always redirected to `/admin/dashboard`

### Responsive Design
Breakpoints: mobile < 700px, tablet 700–1024px, desktop ≥ 1024px.
Layouts adapt via the `Responsive` utility class — bottom navigation bar on mobile, `NavigationRail` on tablet, permanent sidebar on desktop.

### Theming
Full dark/light mode support with preference persisted to `SharedPreferences`. The amber/gold (`#FFB300`) accent color is consistent across both themes.

---

## License

This project is proprietary software. All rights reserved.
