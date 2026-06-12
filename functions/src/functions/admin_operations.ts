import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

// -----------------------------------------------------------
// Middleware: assertSuperAdmin
// -----------------------------------------------------------
async function assertSuperAdmin(uid: string) {
  const snap = await db().collection("platformAdmins").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "You must be a platform administrator.");
  }
}

// ============================================================
// 1. Subscription Management
// ============================================================

/** Get the current user's own subscription payment history */
export const getMySubscriptionPayments = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

  const userSnap = await db().collection("users").doc(request.auth.uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const userData = userSnap.data()!;
  const businessId = userData.businessId;

  const snap = await db()
    .collection("subscriptions")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  const payments = snap.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    createdAt: (doc.data().createdAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
    paidAt: (doc.data().paidAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
    expiresAt: (doc.data().expiresAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
  }));

  return { payments };
});

export const adminGetSubscriptions = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const snap = await db().collection("businesses").orderBy("createdAt", "desc").limit(100).get();

  const subscriptions = snap.docs.map(doc => {
    const data = doc.data();
    return {
      businessId: doc.id,
      businessName: data.name,
      plan: data.plan,
      subscriptionStatus: data.subscriptionStatus,
      trialEndsAt: (data.trialEndsAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
      subscriptionEndsAt: (data.subscriptionEndsAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
      active: data.active || false,
      status: data.status || "pending",
    };
  });

  return { subscriptions };
});

export const adminUpdateSubscription = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { businessId, plan, subscriptionStatus, trialEndsAt, subscriptionEndsAt, active } = request.data as {
    businessId: string;
    plan?: string;
    subscriptionStatus?: string;
    trialEndsAt?: string;
    subscriptionEndsAt?: string;
    active?: boolean;
  };

  if (!businessId) {
    throw new HttpsError("invalid-argument", "businessId is required");
  }

  const updateData: Record<string, any> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (plan !== undefined) updateData.plan = plan;
  if (subscriptionStatus !== undefined) updateData.subscriptionStatus = subscriptionStatus;
  if (trialEndsAt !== undefined) {
    updateData.trialEndsAt = trialEndsAt ? admin.firestore.Timestamp.fromDate(new Date(trialEndsAt)) : null;
  }
  if (subscriptionEndsAt !== undefined) {
    updateData.subscriptionEndsAt = subscriptionEndsAt ? admin.firestore.Timestamp.fromDate(new Date(subscriptionEndsAt)) : null;
  }
  if (active !== undefined) updateData.active = active;

  await db().collection("businesses").doc(businessId).update(updateData);

  // Log the action
  await db().collection("auditLogs").add({
    action: "update_subscription",
    targetId: businessId,
    targetType: "business_subscription",
    performedBy: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    details: { plan, subscriptionStatus, active },
  });

  return { success: true };
});

// ============================================================
// 2. Plan Management (CRUD for plans stored in 'plans' collection)
// ============================================================

export const adminGetPlans = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const snap = await db().collection("plans").orderBy("name", "asc").get();
  
  let plans = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  // Seed plans if none exist
  if (plans.length === 0) {
    const defaultPlans = [
      {
        id: "free",
        name: "Free Plan",
        price: 0,
        maxProducts: 50,
        maxUsers: 1,
        reportsEnabled: true,
        aiEnabled: false,
        whatsappEnabled: false,
        maxDailySales: -1,
        trialDays: 14,
      },
      {
        id: "starter",
        name: "Starter Plan",
        price: 29,
        maxProducts: 500,
        maxUsers: 5,
        reportsEnabled: true,
        aiEnabled: false,
        whatsappEnabled: false,
        maxDailySales: -1,
        trialDays: 14,
      },
      {
        id: "pro",
        name: "Pro Plan",
        price: 79,
        maxProducts: -1,
        maxUsers: -1,
        reportsEnabled: true,
        aiEnabled: true,
        whatsappEnabled: true,
        maxDailySales: -1,
        trialDays: 14,
      }
    ];

    const batch = db().batch();
    for (const p of defaultPlans) {
      const ref = db().collection("plans").doc(p.id);
      batch.set(ref, p);
    }
    await batch.commit();
    plans = defaultPlans;
  }

  return { plans };
});

export const adminCreatePlan = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const planData = request.data as {
    id: string;
    name: string;
    price: number;
    maxProducts: number;
    maxUsers: number;
    reportsEnabled: boolean;
    aiEnabled: boolean;
    whatsappEnabled: boolean;
    maxDailySales: number;
    trialDays: number;
  };

  if (!planData.id || !planData.name) {
    throw new HttpsError("invalid-argument", "Plan ID and Name are required");
  }

  await db().collection("plans").doc(planData.id).set(planData);

  return { success: true };
});

export const adminUpdatePlan = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { id, ...updateFields } = request.data as { id: string; [key: string]: any };

  if (!id) {
    throw new HttpsError("invalid-argument", "Plan ID is required");
  }

  await db().collection("plans").doc(id).update(updateFields);

  return { success: true };
});

export const adminDeletePlan = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { id } = request.data as { id: string };

  if (!id) {
    throw new HttpsError("invalid-argument", "Plan ID is required");
  }

  await db().collection("plans").doc(id).delete();

  return { success: true };
});

// ============================================================
// 3. User Management
// ============================================================

export const adminGetUsers = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const snap = await db().collection("users").limit(100).get();

  const users = await Promise.all(snap.docs.map(async doc => {
    const data = doc.data();
    let authUser: admin.auth.UserRecord | null = null;
    try {
      authUser = await admin.auth().getUser(doc.id);
    } catch (e) {
      // User might not exist in auth anymore, or sandbox environment
    }

    return {
      uid: doc.id,
      displayName: data.displayName || "",
      email: data.email || "",
      role: data.role || "staff",
      businessId: data.businessId || "",
      disabled: authUser?.disabled || false,
      lastSignInTime: authUser?.metadata?.lastSignInTime || null,
      createdAt: (data.createdAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || authUser?.metadata?.creationTime || null,
    };
  }));

  return { users };
});

export const adminUpdateUser = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const { uid, role, disabled, resetPassword } = request.data as {
    uid: string;
    role?: string;
    disabled?: boolean;
    resetPassword?: boolean;
  };

  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required");
  }

  if (role) {
    await db().collection("users").doc(uid).update({ role });
  }

  if (disabled !== undefined) {
    await admin.auth().updateUser(uid, { disabled });
  }

  let resetLink = null;
  if (resetPassword) {
    const user = await admin.auth().getUser(uid);
    if (user.email) {
      resetLink = await admin.auth().generatePasswordResetLink(user.email);
    }
  }

  // Log action
  await db().collection("auditLogs").add({
    action: "admin_update_user",
    targetId: uid,
    targetType: "user",
    performedBy: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    details: { role, disabled, resetPasswordTriggered: !!resetPassword },
  });

  return { success: true, resetLink };
});

// ============================================================
// 4. Platform Settings & Operations
// ============================================================

export const adminGetSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const doc = await db().collection("settings").doc("platform").get();
  
  if (!doc.exists) {
    const defaultSettings = {
      maintenanceMode: false,
      broadcastBanner: "",
      systemAlertLevel: "info", // info, warning, critical
      backupFrequency: "daily",
      lastBackupTimestamp: null,
    };
    await db().collection("settings").doc("platform").set(defaultSettings);
    return defaultSettings;
  }

  return doc.data();
});

export const adminUpdateSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");
  await assertSuperAdmin(request.auth.uid);

  const settings = request.data as {
    maintenanceMode?: boolean;
    broadcastBanner?: string;
    systemAlertLevel?: string;
    backupFrequency?: string;
    triggerBackup?: boolean;
  };

  const updateData: Record<string, any> = {};

  if (settings.maintenanceMode !== undefined) updateData.maintenanceMode = settings.maintenanceMode;
  if (settings.broadcastBanner !== undefined) updateData.broadcastBanner = settings.broadcastBanner;
  if (settings.systemAlertLevel !== undefined) updateData.systemAlertLevel = settings.systemAlertLevel;
  if (settings.backupFrequency !== undefined) updateData.backupFrequency = settings.backupFrequency;
  
  if (settings.triggerBackup) {
    updateData.lastBackupTimestamp = admin.firestore.FieldValue.serverTimestamp();
  }

  await db().collection("settings").doc("platform").update(updateData);

  // Log action
  await db().collection("auditLogs").add({
    action: "admin_update_settings",
    targetId: "platform",
    targetType: "settings",
    performedBy: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    details: settings,
  });

  return { success: true };
});
