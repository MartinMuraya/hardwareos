// ============================================================
// PLAN LIMITS — Single source of truth for all subscription tiers
// This file drives feature enforcement across all Cloud Functions
// ============================================================

export type Plan = "free" | "starter" | "pro";
export type SubscriptionStatus = "trial" | "active" | "expired" | "grace_period";

export const GRACE_PERIOD_DAYS = 3;

export interface PlanConfig {
  maxProducts: number; // -1 = unlimited
  maxUsers: number;    // -1 = unlimited
  reportsEnabled: boolean;
  aiBasicEnabled: boolean;
  aiAnalystEnabled: boolean;
  whatsappEnabled: boolean;
  maxDailySales: number; // -1 = unlimited
  etimsEnabled: boolean;
  storefrontEnabled: boolean;
  multiLanguageEnabled: boolean;
  receiptPrintingEnabled: boolean;
  advancedAnalyticsEnabled: boolean;
}

export const PLAN_LIMITS: Record<Plan, PlanConfig> = {
  free: {
    maxProducts: 50,
    maxUsers: 1,
    reportsEnabled: true,
    aiBasicEnabled: false,
    aiAnalystEnabled: false,
    whatsappEnabled: false,
    maxDailySales: -1,
    etimsEnabled: false,
    storefrontEnabled: false,
    multiLanguageEnabled: false,
    receiptPrintingEnabled: true,
    advancedAnalyticsEnabled: false,
  },
  starter: {
    maxProducts: 500,
    maxUsers: 5,
    reportsEnabled: true,
    aiBasicEnabled: true,
    aiAnalystEnabled: false,
    whatsappEnabled: false,
    maxDailySales: -1,
    etimsEnabled: true,
    storefrontEnabled: true,
    multiLanguageEnabled: true,
    receiptPrintingEnabled: true,
    advancedAnalyticsEnabled: false,
  },
  pro: {
    maxProducts: -1,
    maxUsers: -1,
    reportsEnabled: true,
    aiBasicEnabled: true,
    aiAnalystEnabled: true,
    whatsappEnabled: true,
    maxDailySales: -1,
    etimsEnabled: true,
    storefrontEnabled: true,
    multiLanguageEnabled: true,
    receiptPrintingEnabled: true,
    advancedAnalyticsEnabled: true,
  },
};

export const TRIAL_DAYS = 14;

export const UPGRADE_MESSAGES: Record<string, string> = {
  maxProducts:
    "You have reached the product limit for your plan. Upgrade to add more products.",
  maxUsers:
    "You have reached the user limit for your plan. Upgrade to add more team members.",
  aiBasicEnabled:
    "AI Chatbot assistant is available on Starter and Pro plans. Upgrade to ask general business questions.",
  aiAnalystEnabled:
    "AI Business Analyst & Autonomous Workflows are available exclusively on the Pro plan. Upgrade to unlock run-out forecasting and draft purchase orders.",
  whatsappEnabled:
    "WhatsApp integration is available on the Pro plan.",
  etimsEnabled:
    "eTIMS integration is available on Starter and Pro plans. Upgrade to automate KRA reporting.",
  storefrontEnabled:
    "B2B/B2C Storefront is available on Starter and Pro plans.",
  multiLanguageEnabled:
    "Multi-Language support (Swahili, Sheng) is available on Starter and Pro plans.",
  advancedAnalyticsEnabled:
    "Advanced Analytics are available exclusively on the Pro plan.",
  expired:
    "Your subscription has expired. Please renew to continue using HardwareOS.",
  gracePeriod:
    "Your subscription is in the grace period. Please renew immediately to avoid service interruption.",
};

/** Returns the effective plan config, treating expired subs as free, grace_period as limited */
export function getEffectivePlan(
  plan: Plan,
  status: SubscriptionStatus,
  trialEndsAt: Date | null
): { config: PlanConfig; isExpired: boolean; isGracePeriod: boolean } {
  const now = new Date();

  // Trial expired
  if (status === "trial" && trialEndsAt && now > trialEndsAt) {
    return { config: PLAN_LIMITS["free"], isExpired: true, isGracePeriod: false };
  }

  // Subscription expired
  if (status === "expired") {
    return { config: PLAN_LIMITS["free"], isExpired: true, isGracePeriod: false };
  }

  // Grace period — keep plan features but flag as expiring
  if (status === "grace_period") {
    return { config: PLAN_LIMITS[plan], isExpired: true, isGracePeriod: true };
  }

  return { config: PLAN_LIMITS[plan], isExpired: false, isGracePeriod: false };
}

/** Count how many businesses are in each subscription category */
export async function computeSubscriptionStats(db: FirebaseFirestore.Firestore): Promise<{
  totalBusinesses: number;
  activeSubscriptions: number;
  trialAccounts: number;
  expiredSubscriptions: number;
  gracePeriodAccounts: number;
  starterAccounts: number;
  proAccounts: number;
  freeAccounts: number;
  monthlyRecurringRevenue: number;
  totalRevenue: number;
}> {
  const bizColl = db.collection("businesses");
  
  const [
    totalBusinessesSnap,
    activeSubscriptionsSnap,
    trialAccountsSnap,
    expiredSubscriptionsSnap,
    gracePeriodAccountsSnap,
    starterAccountsSnap,
    proAccountsSnap,
  ] = await Promise.all([
    bizColl.count().get(),
    bizColl.where("subscriptionStatus", "==", "active").count().get(),
    bizColl.where("subscriptionStatus", "==", "trial").count().get(),
    bizColl.where("subscriptionStatus", "==", "expired").count().get(),
    bizColl.where("subscriptionStatus", "==", "grace_period").count().get(),
    bizColl.where("plan", "==", "starter").count().get(),
    bizColl.where("plan", "==", "pro").count().get(),
  ]);

  const totalBusinesses = totalBusinessesSnap.data().count;
  const activeSubscriptions = activeSubscriptionsSnap.data().count;
  const trialAccounts = trialAccountsSnap.data().count;
  const expiredSubscriptions = expiredSubscriptionsSnap.data().count;
  const gracePeriodAccounts = gracePeriodAccountsSnap.data().count;
  const starterAccounts = starterAccountsSnap.data().count;
  const proAccounts = proAccountsSnap.data().count;
  const freeAccounts = totalBusinesses - starterAccounts - proAccounts;

  const monthlyRecurringRevenue = (starterAccounts * 2600) + (proAccounts * 5200);

  // Using AggregateField for sum (requires firebase-admin v11.10.0+)
  const { AggregateField } = require('firebase-admin/firestore');
  const revenueSnap = await db.collection("subscriptions")
    .where("transactionStatus", "==", "completed")
    .aggregate({ totalRevenue: AggregateField.sum("amount") })
    .get();

  const totalRevenue = (revenueSnap.data().totalRevenue as number) || 0;

  return {
    totalBusinesses,
    activeSubscriptions,
    trialAccounts,
    expiredSubscriptions,
    gracePeriodAccounts,
    starterAccounts,
    proAccounts,
    freeAccounts,
    monthlyRecurringRevenue,
    totalRevenue,
  };
}
