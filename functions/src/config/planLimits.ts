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
  aiEnabled: boolean;
  whatsappEnabled: boolean;
  maxDailySales: number; // -1 = unlimited
}

export const PLAN_LIMITS: Record<Plan, PlanConfig> = {
  free: {
    maxProducts: 50,
    maxUsers: 1,
    reportsEnabled: true,
    aiEnabled: false,
    whatsappEnabled: false,
    maxDailySales: -1,
  },
  starter: {
    maxProducts: 500,
    maxUsers: 5,
    reportsEnabled: true,
    aiEnabled: false,
    whatsappEnabled: false,
    maxDailySales: -1,
  },
  pro: {
    maxProducts: -1,
    maxUsers: -1,
    reportsEnabled: true,
    aiEnabled: true,
    whatsappEnabled: true,
    maxDailySales: -1,
  },
};

export const TRIAL_DAYS = 14;

export const UPGRADE_MESSAGES: Record<string, string> = {
  maxProducts:
    "You have reached the product limit for your plan. Upgrade to add more products.",
  maxUsers:
    "You have reached the user limit for your plan. Upgrade to add more team members.",
  aiEnabled:
    "AI features are available on the Pro plan. Upgrade to unlock AI insights.",
  whatsappEnabled:
    "WhatsApp integration is available on the Pro plan.",
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
  const bizSnap = await db.collection("businesses").get();

  let totalBusinesses = 0;
  let activeSubscriptions = 0;
  let trialAccounts = 0;
  let expiredSubscriptions = 0;
  let gracePeriodAccounts = 0;
  let starterAccounts = 0;
  let proAccounts = 0;
  let freeAccounts = 0;
  let monthlyRecurringRevenue = 0;

  for (const doc of bizSnap.docs) {
    const data = doc.data();
    totalBusinesses++;

    const status = data.subscriptionStatus || "trial";
    const plan = data.plan || "free";

    if (status === "active") activeSubscriptions++;
    if (status === "trial") trialAccounts++;
    if (status === "expired") expiredSubscriptions++;
    if (status === "grace_period") gracePeriodAccounts++;

    if (plan === "starter") { starterAccounts++; monthlyRecurringRevenue += 2600; }
    if (plan === "pro") { proAccounts++; monthlyRecurringRevenue += 5200; }
    if (plan === "free" || plan === "trial") freeAccounts++;
  }

  // Total revenue from subscriptions collection
  const subSnap = await db
    .collection("subscriptions")
    .where("transactionStatus", "==", "completed")
    .get();

  let totalRevenue = 0;
  for (const doc of subSnap.docs) {
    totalRevenue += (doc.data().amount as number) || 0;
  }

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
