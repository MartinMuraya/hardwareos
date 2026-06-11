// ============================================================
// PLAN LIMITS — Single source of truth for all subscription tiers
// This file drives feature enforcement across all Cloud Functions
// ============================================================

export type Plan = "free" | "starter" | "pro";
export type SubscriptionStatus = "trial" | "active" | "expired";

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
};

/** Returns the effective plan config, treating expired subs as free */
export function getEffectivePlan(
  plan: Plan,
  status: SubscriptionStatus,
  trialEndsAt: Date | null
): { config: PlanConfig; isExpired: boolean } {
  const now = new Date();

  // Trial expired
  if (status === "trial" && trialEndsAt && now > trialEndsAt) {
    return { config: PLAN_LIMITS["free"], isExpired: true };
  }

  // Subscription expired
  if (status === "expired") {
    return { config: PLAN_LIMITS["free"], isExpired: true };
  }

  return { config: PLAN_LIMITS[plan], isExpired: false };
}
