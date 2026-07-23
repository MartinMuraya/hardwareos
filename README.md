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

## 🌍 Real-World Application & Problem Solving

Hardware stores in East Africa typically rely on fragmented, legacy workflows: physical paper ledgers, isolated desktop POS systems, manual inventory tracking, and disconnected debt collection. 

**HardwareOS solves these problems by providing:**
- **Centralized Inventory Control:** Preventing stockouts and employee theft through rigorous audit logs, multi-branch tracking, and strict role-based access.
- **Unified Debt Management:** Over 60% of hardware sales in the region are on credit. The system explicitly tracks customer debt, generates statements, and tracks partial repayments over time.
- **Mobility & Offline Resilience:** Staff can process sales on smartphones or tablets, even when internet connectivity drops, preventing business halts during outages.
- **Automated M-Pesa Integration:** Native mobile money payments and automated subscription billing via Safaricom Daraja API.

---

## 📖 Deep System Overview & Analysis

HardwareOS is a robust, cloud-based ERP and POS platform specifically designed for hardware and building-material retailers in East Africa. It is designed to replace fragmented legacy workflows—such as paper ledgers, isolated desktop POS systems, and manual inventory tracking—with a unified omnichannel experience.

The system is built on a **multi-tenant architecture**. Each registered hardware store operates within its own strictly isolated data environment under a tiered subscription plan. Simultaneously, platform owners govern the entire ecosystem through an omnipresent Super Admin control plane.

HardwareOS utilizes a highly secure **"Function-as-a-Service" (FaaS) data mutation pattern**. Client applications (Web, Android, Windows) have *zero* write access directly to the database. All writes are routed through Firebase Cloud Functions (HTTPS Callables), which act as middleware to enforce authentication, business logic, role-based access control (RBAC), and subscription limits.

---

## 🏗️ Architectural Topology

```text
┌─────────────────────────────────────────────────────────┐
│                      Flutter Client                     │
│    (Web / Android / Windows — Material 3 Design)        │
│                                                         │
│  State Management: Provider (Auth, Theme) + Riverpod    │
│  Routing: go_router (Auth guards, ShellRoutes)          │
└────────────────────────┬────────────────────────────────┘
                         │ 1. HTTPS Callable Requests
                         ▼
┌─────────────────────────────────────────────────────────┐
│               Firebase Cloud Functions (Node.js)        │
│                                                         │
│  [Auth] [Inventory] [Sales] [Expenses] [Dashboard]      │
│  [M-Pesa Billing] [Super Admin] [Support] [AI] [Audit]  │
└────────────────────────┬────────────────────────────────┘
                         │ 2. Server-side Validation & Execution
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Cloud Firestore                       │
│  Strict Security Rules (Read-Only for Clients)          │
│                                                         │
│  Users | Businesses | Products | Sales | Expenses       │
│  Subscriptions | Support Tickets | System Logs | ...    │
└─────────────────────────────────────────────────────────┘
```

---

## 🏃 How to Use the System (Quick Overview)

1. **Onboarding:** A hardware store owner registers their business, initiating a 14-day Pro trial. They set up branches and configure basic settings.
2. **Inventory Import:** The owner uploads their existing product catalog via the Bulk Import (CSV/Excel) tool or adds items manually.
3. **Team Setup:** The owner invites Cashiers and Managers via email. RBAC ensures staff can only ring up sales and cannot alter historical records.
4. **Daily Operations:**
   - **Sales/POS:** Cashiers scan items or search the catalog to process cash, M-Pesa, or credit sales. Digital receipts are generated.
   - **Purchases:** Managers create Purchase Orders for suppliers to restock inventory.
   - **Expenses:** Staff log daily operational expenses (transport, utilities) from the cash drawer.
5. **Reporting & AI Insights:** At the end of the day or month, the owner checks the Dashboard and uses the Gemini AI Assistant to analyze sales velocity, profitability, and identify slow-moving stock.

---

## 🚀 Core Modules & Capabilities

The system is divided into over 20 highly specialized modules inside the Flutter application. 

### 1. Point of Sale (POS) & Sales Management
- **Omni-platform POS**: Fast checkout interface supporting barcode scanning and manual search.
- **Offline Resilience**: Sales can be queued offline and synchronized automatically when internet connectivity is restored.
- **Payment Types**: Cash, M-Pesa, and Credit (debt tracking).
- **Receipts**: Generates digital receipts with automatic PDF creation.
- **Sales History**: Search, refund, and review historical transactions.

### 2. Comprehensive Inventory & Supply Chain
- **Product Management**: Full catalog tracking with SKU, categorisation, buying/selling prices, and reorder levels.
- **Purchase Orders (POs)**: Create and track purchase orders sent to suppliers.
- **Suppliers**: Manage supplier directories and their related POs.
- **Stock Adjustments**: Record manual stock corrections (damage, loss, manual counts).
- **Branch Management**: Multi-branch support allowing stock transfers between physical store locations.

### 3. CRM & Debt Management
- **Customer Directory**: Track all customers and their contact information.
- **Credit Ledgers**: Advanced debt tracking. Allows cashiers to sell on credit, track outstanding balances, and record debt repayments over time.
- **Customer Statements**: Generate full account statements for credit buyers.

### 4. Financial Tracking
- **Expenses**: Categorised business expenses (payroll, rent, utilities).
- **Cash Drawer**: Track shifts, opening balances, cash drops, and closing balances for strict employee financial accountability.
- **B2B Quotations & Invoicing:** Instantly convert quotations into formal invoices, track payments against specific documents, and manage custom credit limits for trusted contractors.
- **Double-Entry Accounting Engine:** Fully compliant General Ledger with Chart of Accounts and real-time Trial Balance. All POS transactions and expenses automatically balance Debits and Credits via atomic Firestore transactions.
- **Comprehensive HR & Payroll:** Structured employee management, timesheets, and automated payroll processing with configurable statutory deductions (PAYE, NHIF, NSSF). Directly integrates with the accounting engine to log salary expenses and tax liabilities.
- **Multi-Branch Capability:** Manage several store locations under a single business umbrella. Transfer stock between branches with automated transit tracking and branch-specific profit & loss statements.

### 6. Advanced Analytics & AI
- **Dashboard**: Real-time KPI cards, low stock alerts, pending sync indicators, and recent sales feeds.
- **Interactive Reports**: Powered by `fl_chart`, visualize Profit & Loss, sales by payment methods, and historical trends over Today, This Week, or This Month.
- **Gemini AI Assistant**: Powered by Google's Gemini LLM. Analyzes the last 30 days of the business's sales, expenses, and inventory to generate executive insights, risk warnings, and concrete recommendations.

### 7. Support & Auditing
- **Helpdesk Ticketing**: Tenants can open support tickets directly in the app. Super Admins reply and resolve them centrally.
- **Audit Logs**: Every mutation (sale, edit, delete) is logged. Business owners can review the exact timestamp and user responsible for any action.

### 8. Team & RBAC
- Role-Based Access Control: Owner, Manager, and Staff roles.
- Owners can invite users via email, who then accept the invite to join the tenant's workspace.

### 9. Subscriptions & M-Pesa Billing
- **14-day Free Trial**: Automated onboarding into a Pro trial.
- **Tiered Plans**: Starter (KES 2,600/mo, 3 users) and Pro (KES 5,200/mo, unlimited).
- **M-Pesa STK Push**: Native Safaricom Daraja API integration.
- **Simulation Mode**: By setting the `MPESA_CONSUMER_KEY` to `"dummy"`, developers can fully simulate the STK push and payment success/failure lifecycle without incurring real charges.
- **Guarded Routing**: If a subscription expires, `go_router` forcefully redirects the entire tenant to the billing screen.

### 10. The Super Admin Control Plane
- Exclusive dashboard for the platform owners.
- Platform KPIs (total MRR, active businesses).
- Complete oversight to approve, suspend, or permanently delete tenant businesses.
- Ability to monitor system logs and manage the global Support Helpdesk.
- Manage global subscription plans.

---

## 🔒 Security & Data Integrity

1. **Client Read-Only Firestore Rules**: The `firestore.rules` file enforces that clients can only *read* documents belonging to their `businessId`. All `write`, `update`, and `delete` operations are strictly blocked from the client.
2. **Resilient Authentication**: Built-in fallback routing handles network timeouts and Firebase internal identity errors (such as `invalid-credential` mapping) to prevent infinite routing loops on the client.
3. **Server-Side Validation**: Cloud Functions verify the user's Auth token, confirm their role within the specific business, and execute the database writes securely on the backend.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Frontend UI/UX** | Flutter 3.38, Dart 3.10, Material 3, fl_chart |
| **State & Routing** | Provider, Riverpod, go_router |
| **Backend Logic** | Firebase Cloud Functions v2 (Node.js, TypeScript) |
| **Database** | Cloud Firestore (NoSQL) |
| **Authentication** | Firebase Auth (Email/Password) |
| **Billing Integration** | Safaricom M-Pesa Daraja API |
| **AI Integration** | Google Gemini LLM API |

---

## 🚧 Development Roadmap & Missing Structures

While HardwareOS covers a vast Enterprise ERP feature set, the following areas are identified for future expansion:

- **E-Commerce & Online Storefronts:** Currently, backend APIs (`storefront_stubs.ts`) exist as placeholders. The roadmap includes exposing a B2B/B2C storefront for contractors to order materials online directly from the hardware store.
- **Advanced Tax Integration (KRA TIMS):** Expanding the current Double-Entry Accounting Ledger to automatically transmit and sign electronic tax invoices directly with the revenue authority.
- **Advanced Hardware Integrations:** Integrating with digital weighing scales (for items sold by weight like nails/cement) and specialized barcode label printers.
- **Testing & CI/CD Maturity:** Implementing comprehensive end-to-end integration testing and expanding the GitHub Actions pipeline with staging environments and automated test gates.

---

## ⚙️ Local Setup & Deployment

### Prerequisites
- Flutter SDK 3.0+
- Node.js 18+ (Node 20 recommended)
- Firebase CLI (`npm install -g firebase-tools`)

### Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/MartinMuraya/hardwareos.git
cd hardwareos

# 2. Install Flutter dependencies
flutter pub get

# 3. Install Cloud Functions dependencies
cd functions
npm install
cd ..

# 4. Configure Firebase Secrets (For Deployment)
firebase secrets:set MPESA_CONSUMER_KEY (use "dummy" for simulation)
firebase secrets:set MPESA_CONSUMER_SECRET
firebase secrets:set GEMINI_API_KEY (use "dummy" for simulation)

# 5. Run the Flutter App
flutter run -d chrome --web-header='Cross-Origin-Opener-Policy: same-origin-allow-popups'
```

### Production Deployment

```bash
# Deploy all Firebase Cloud Functions
npm --prefix functions run build
firebase deploy --only functions

# Deploy Firebase Firestore Rules
firebase deploy --only firestore:rules

# Build and deploy Flutter Web App
flutter build web
firebase deploy --only hosting
```

---

## 📝 License
This project is proprietary software belonging to Martin Muraya. All rights reserved.
