import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

export type AuditAction =
  | "USER_CREATED" | "USER_DELETED" | "ROLE_CHANGED"
  | "LOGIN_FAILED" | "LOGIN_LOCKED" | "PASSWORD_RESET_REQUESTED"
  | "SUB_PAYMENT_INITIATED" | "SUB_ACTIVATED" | "SUB_EXPIRED"
  | "SUB_RENEWED" | "PLAN_CHANGED"
  | "PRODUCT_DELETED" | "SALE_VOIDED" | "RETURN_CREATED"
  | "STOCK_ADJUSTED" | "CASH_DRAWER_CLOSED"
  | "BRANCH_TRANSFER_CREATED" | "BRANCH_TRANSFER_RECEIVED";

export async function writeAuditLog(params: {
  businessId?: string;
  userId?: string;
  action: AuditAction | string;
  metadata?: Record<string, unknown>;
  targetId?: string;
  targetType?: string;
}): Promise<void> {
  await db().collection("auditLogs").add({
    ...params,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: params.metadata || null,
    targetId: params.targetId || null,
    targetType: params.targetType || null,
  });
}

// ==============================================================
// 1. LOGIN ABUSE PROTECTION
// ==============================================================

const LOCKOUT_5_ATTEMPTS = 15 * 60 * 1000;
const LOCKOUT_10_ATTEMPTS = 60 * 60 * 1000;
const MAX_FAILED_BEFORE_LOCK = 5;
const MAX_FAILED_BEFORE_EXTENDED_LOCK = 10;

export async function checkLoginRateLimit(email: string): Promise<void> {
  const normalizedEmail = email.trim().toLowerCase();
  const docId = Buffer.from(normalizedEmail).toString("base64url");
  const ref = db().collection("loginAttempts").doc(docId);

  const snap = await ref.get();
  if (!snap.exists) return;

  const data = snap.data()!;
  const lockUntil = data.lockUntil?.toDate?.() ?? null;

  if (lockUntil && lockUntil > new Date()) {
    throw new HttpsError("unauthenticated", "Too many failed login attempts. Please try again later.");
  }

  if (lockUntil && lockUntil <= new Date()) {
    const oneHour = 60 * 60 * 1000;
    if (data.attemptCount >= MAX_FAILED_BEFORE_EXTENDED_LOCK) {
      const newLockUntil = new Date(Date.now() + oneHour);
      await ref.update({
        lockUntil: admin.firestore.Timestamp.fromDate(newLockUntil),
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new HttpsError("unauthenticated", "Too many failed login attempts. Please try again later.");
    }
  }
}

export async function recordFailedLogin(email: string): Promise<void> {
  const normalizedEmail = email.trim().toLowerCase();
  const docId = Buffer.from(normalizedEmail).toString("base64url");
  const ref = db().collection("loginAttempts").doc(docId);

  const snap = await ref.get();

  if (!snap.exists) {
    await ref.set({
      email: normalizedEmail,
      attemptCount: 1,
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      lockUntil: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  const data = snap.data()!;
  const newCount = (data.attemptCount || 0) + 1;
  let lockUntil: admin.firestore.Timestamp | null = null;

  if (newCount >= MAX_FAILED_BEFORE_EXTENDED_LOCK) {
    lockUntil = admin.firestore.Timestamp.fromMillis(Date.now() + LOCKOUT_10_ATTEMPTS);
  } else if (newCount >= MAX_FAILED_BEFORE_LOCK) {
    lockUntil = admin.firestore.Timestamp.fromMillis(Date.now() + LOCKOUT_5_ATTEMPTS);
  }

  await ref.update({
    attemptCount: newCount,
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
    lockUntil,
  });
}

export async function clearLoginAttempts(email: string): Promise<void> {
  const normalizedEmail = email.trim().toLowerCase();
  const docId = Buffer.from(normalizedEmail).toString("base64url");
  const ref = db().collection("loginAttempts").doc(docId);
  const snap = await ref.get();
  if (snap.exists) {
    await ref.delete();
  }
}

// ==============================================================
// 2. PASSWORD RESET ABUSE PREVENTION
// ==============================================================

const MAX_RESETS_PER_HOUR = 3;
const MAX_RESETS_PER_DAY = 10;

export async function checkPasswordResetRateLimit(email: string): Promise<void> {
  const normalizedEmail = email.trim().toLowerCase();
  const docId = Buffer.from(normalizedEmail).toString("base64url");
  const ref = db().collection("passwordResetRequests").doc(docId);

  const snap = await ref.get();
  if (!snap.exists) return;

  const data = snap.data()!;
  const now = Date.now();
  const oneHourAgo = now - 60 * 60 * 1000;
  const oneDayAgo = now - 24 * 60 * 60 * 1000;
  const requests = (data.requests as Array<{ timestamp: number }>) || [];

  const recentHour = requests.filter((r) => r.timestamp > oneHourAgo);
  const recentDay = requests.filter((r) => r.timestamp > oneDayAgo);

  if (recentHour.length >= MAX_RESETS_PER_HOUR || recentDay.length >= MAX_RESETS_PER_DAY) {
    return;
  }
}

export async function recordPasswordResetRequest(email: string): Promise<void> {
  const normalizedEmail = email.trim().toLowerCase();
  const docId = Buffer.from(normalizedEmail).toString("base64url");
  const ref = db().collection("passwordResetRequests").doc(docId);

  const snap = await ref.get();

  if (!snap.exists) {
    await ref.set({
      email: normalizedEmail,
      requests: [{ timestamp: Date.now() }],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  const data = snap.data()!;
  const now = Date.now();
  const oneDayAgo = now - 24 * 60 * 60 * 1000;
  const requests = (data.requests as Array<{ timestamp: number }>) || [];
  const recent = requests.filter((r) => r.timestamp > oneDayAgo);

  recent.push({ timestamp: now });

  const oneHourAgo = now - 60 * 60 * 1000;
  const recentHour = recent.filter((r) => r.timestamp > oneHourAgo);

  if (recentHour.length > MAX_RESETS_PER_HOUR || recent.length > MAX_RESETS_PER_DAY) {
    return;
  }

  await ref.update({
    requests: recent,
  });
}

// ==============================================================
// 3. ROLE ESCALATION PROTECTION
// ==============================================================

type UserRole = "owner" | "manager" | "staff";
type TargetRole = UserRole | "admin";

const ROLE_HIERARCHY: Record<UserRole, UserRole[]> = {
  owner: ["owner", "manager", "staff"],
  manager: ["staff"],
  staff: [],
};

const ROLE_ADMIN = "admin";

export async function assertCanManageRole(
  callerUid: string,
  businessId: string,
  targetRole: TargetRole,
): Promise<void> {
  const callerSnap = await db().collection("users").doc(callerUid).get();
  if (!callerSnap.exists) {
    throw new HttpsError("unauthenticated", "User profile not found.");
  }

  const callerData = callerSnap.data()!;
  if (callerData.businessId !== businessId) {
    throw new HttpsError("permission-denied", "You do not belong to this business.");
  }

  const callerRole = callerData.role as UserRole;

  if (targetRole === "owner") {
    throw new HttpsError("permission-denied", "Cannot create or assign the owner role.");
  }

  if (targetRole === ROLE_ADMIN) {
    throw new HttpsError("permission-denied", "Only platform administrators can grant admin access.");
  }

  const allowedRoles = ROLE_HIERARCHY[callerRole] || [];
  if (!allowedRoles.includes(targetRole)) {
    throw new HttpsError(
      "permission-denied",
      `Your role (${callerRole}) cannot manage users with role: ${targetRole}.`,
    );
  }
}

// ==============================================================
// 4. SESSION SECURITY
// ==============================================================

export async function checkUserSession(
  uid: string,
  businessId: string,
): Promise<void> {
  const userSnap = await db().collection("users").doc(uid).get();
  if (!userSnap.exists) {
    await admin.auth().revokeRefreshTokens(uid);
    throw new HttpsError("unauthenticated", "User account has been disabled.");
  }

  const userData = userSnap.data()!;
  if (userData.businessId !== businessId) {
    await admin.auth().revokeRefreshTokens(uid);
    throw new HttpsError("permission-denied", "Access revoked.");
  }

  const bizSnap = await db().collection("businesses").doc(businessId).get();
  if (bizSnap.exists) {
    const bizData = bizSnap.data()!;
    if (bizData.status === "suspended" || bizData.active === false) {
      await admin.auth().revokeRefreshTokens(uid);
      throw new HttpsError("permission-denied", "Business account is suspended.");
    }
    if (bizData.subscriptionStatus === "expired") {
      await admin.auth().revokeRefreshTokens(uid);
      throw new HttpsError("permission-denied", "Subscription permanently terminated.");
    }
  }

  try {
    const authUser = await admin.auth().getUser(uid);
    if (authUser.disabled) {
      await admin.auth().revokeRefreshTokens(uid);
      throw new HttpsError("unauthenticated", "User account has been disabled.");
    }
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("unauthenticated", "User account not found.");
  }
}
