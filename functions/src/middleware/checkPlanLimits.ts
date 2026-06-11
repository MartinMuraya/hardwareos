// ============================================================
// checkPlanLimits — Reusable middleware for all Cloud Functions
// Every write operation must call this before touching Firestore
// ============================================================

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { getEffectivePlan, Plan, SubscriptionStatus, UPGRADE_MESSAGES } from "../config/planLimits";

const db = () => admin.firestore();

export interface BusinessData {
  plan: Plan;
  subscriptionStatus: SubscriptionStatus;
  trialEndsAt: admin.firestore.Timestamp | null;
  subscriptionEndsAt: admin.firestore.Timestamp | null;
  name: string;
}

/** Fetch business data — throws if not found */
export async function getBusinessData(businessId: string): Promise<BusinessData> {
  const snap = await db().collection("businesses").doc(businessId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", `Business ${businessId} not found.`);
  }
  return snap.data() as BusinessData;
}

/** Enforce: caller belongs to this business with required role */
export async function assertBusinessMember(
  uid: string,
  businessId: string,
  allowedRoles: string[] = ["owner", "manager", "staff"]
): Promise<void> {
  const userSnap = await db().collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("unauthenticated", "User profile not found.");
  }
  const userData = userSnap.data()!;
  if (userData.businessId !== businessId) {
    throw new HttpsError("permission-denied", "You do not belong to this business.");
  }
  if (!allowedRoles.includes(userData.role)) {
    throw new HttpsError(
      "permission-denied",
      `This action requires one of: ${allowedRoles.join(", ")}.`
    );
  }
}

/** Enforce: subscription is valid (not expired) */
export async function assertActiveSubscription(businessId: string): Promise<BusinessData> {
  const biz = await getBusinessData(businessId);
  const trialEndsAt = biz.trialEndsAt ? biz.trialEndsAt.toDate() : null;

  const { isExpired } = getEffectivePlan(biz.plan, biz.subscriptionStatus, trialEndsAt);

  if (isExpired) {
    throw new HttpsError("resource-exhausted", UPGRADE_MESSAGES["expired"]);
  }
  return biz;
}

/** Enforce: product count within plan limit */
export async function assertProductLimit(businessId: string): Promise<void> {
  const biz = await assertActiveSubscription(businessId);
  const trialEndsAt = biz.trialEndsAt ? biz.trialEndsAt.toDate() : null;
  const { config } = getEffectivePlan(biz.plan, biz.subscriptionStatus, trialEndsAt);

  if (config.maxProducts === -1) return; // unlimited

  const snap = await db()
    .collection("products")
    .where("businessId", "==", businessId)
    .count()
    .get();

  if (snap.data().count >= config.maxProducts) {
    throw new HttpsError("resource-exhausted", UPGRADE_MESSAGES["maxProducts"]);
  }
}

/** Enforce: user count within plan limit */
export async function assertUserLimit(businessId: string): Promise<void> {
  const biz = await assertActiveSubscription(businessId);
  const trialEndsAt = biz.trialEndsAt ? biz.trialEndsAt.toDate() : null;
  const { config } = getEffectivePlan(biz.plan, biz.subscriptionStatus, trialEndsAt);

  if (config.maxUsers === -1) return; // unlimited

  const snap = await db()
    .collection("users")
    .where("businessId", "==", businessId)
    .count()
    .get();

  if (snap.data().count >= config.maxUsers) {
    throw new HttpsError("resource-exhausted", UPGRADE_MESSAGES["maxUsers"]);
  }
}

/** Enforce: feature flag check (e.g. aiEnabled, whatsappEnabled) */
export async function assertFeatureEnabled(
  businessId: string,
  feature: "aiEnabled" | "whatsappEnabled"
): Promise<void> {
  const biz = await getBusinessData(businessId);
  const trialEndsAt = biz.trialEndsAt ? biz.trialEndsAt.toDate() : null;
  const { config } = getEffectivePlan(biz.plan, biz.subscriptionStatus, trialEndsAt);

  if (!config[feature]) {
    throw new HttpsError("resource-exhausted", UPGRADE_MESSAGES[feature]);
  }
}
