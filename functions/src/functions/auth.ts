// ============================================================
// Auth Functions — Business registration & user management
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { TRIAL_DAYS } from "../config/planLimits";
import { assertBusinessMember, assertUserLimit } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// createBusiness
// Called once when a new owner registers their hardware store.
// Creates the business doc + owner user profile atomically.
// -----------------------------------------------------------
export const createBusiness = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { businessName } = request.data as { businessName: string };

  if (!businessName || businessName.trim().length < 2) {
    throw new HttpsError("invalid-argument", "Business name must be at least 2 characters.");
  }

  const uid = request.auth.uid;

  // Check if user already belongs to a business
  const existingUser = await db().collection("users").doc(uid).get();
  if (existingUser.exists) {
    throw new HttpsError("already-exists", "You are already registered to a business.");
  }

  const trialEndsAt = new Date();
  trialEndsAt.setDate(trialEndsAt.getDate() + TRIAL_DAYS);

  const batch = db().batch();

  // Create business document
  const businessRef = db().collection("businesses").doc();
  batch.set(businessRef, {
    id: businessRef.id,
    name: businessName.trim(),
    plan: "free",
    status: "pending",
    active: false,
    subscriptionStatus: "trial",
    trialEndsAt: admin.firestore.Timestamp.fromDate(trialEndsAt),
    subscriptionEndsAt: null,
    ownerId: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create owner user profile
  const userRef = db().collection("users").doc(uid);
  batch.set(userRef, {
    uid,
    businessId: businessRef.id,
    role: "owner",
    displayName: request.auth.token.name || "",
    email: request.auth.token.email || "",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  return {
    businessId: businessRef.id,
    businessName: businessName.trim(),
    plan: "free",
    status: "pending",
    subscriptionStatus: "trial",
    trialEndsAt: trialEndsAt.toISOString(),
  };
});

// -----------------------------------------------------------
// inviteUser
// Owner/Manager adds a new staff/manager to their business.
// Enforces maxUsers plan limit before creating the profile.
// The invited user must already have a Firebase Auth account.
// -----------------------------------------------------------
export const inviteUser = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { targetUid, role, businessId, displayName } = request.data as {
    targetUid: string;
    role: "manager" | "staff";
    businessId: string;
    displayName: string;
  };

  if (!["manager", "staff"].includes(role)) {
    throw new HttpsError("invalid-argument", "Role must be manager or staff.");
  }

  // Caller must be owner or manager
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  // Enforce plan user limit
  await assertUserLimit(businessId);

  // Check target user doesn't already have a profile
  const targetSnap = await db().collection("users").doc(targetUid).get();
  if (targetSnap.exists) {
    throw new HttpsError("already-exists", "This user is already registered to a business.");
  }

  // Verify Firebase Auth account exists
  try {
    await admin.auth().getUser(targetUid);
  } catch {
    throw new HttpsError("not-found", "No Firebase account found for the given UID.");
  }

  await db().collection("users").doc(targetUid).set({
    uid: targetUid,
    businessId,
    role,
    displayName: displayName || "",
    email: "",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: `User added as ${role}.` };
});

// -----------------------------------------------------------
// getMyProfile
// Returns the calling user's profile + business info + super admin status.
// Called on app startup to restore session context.
// -----------------------------------------------------------
export const getMyProfile = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid = request.auth.uid;
  
  // Check if user is a Super Admin
  const adminSnap = await db().collection("platformAdmins").doc(uid).get();
  const isSuperAdmin = adminSnap.exists;

  const userSnap = await db().collection("users").doc(uid).get();

  if (!userSnap.exists) {
    return { 
      registered: false,
      isSuperAdmin,
    };
  }

  const userData = userSnap.data()!;
  const bizSnap = await db().collection("businesses").doc(userData.businessId).get();

  return {
    registered: true,
    isSuperAdmin,
    user: userData,
    business: bizSnap.data(),
  };
});

// -----------------------------------------------------------
// getUsers
// Retrieves all users associated with the given businessId.
// Caller must be an owner or manager.
// -----------------------------------------------------------
export const getUsers = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { businessId } = request.data as { businessId: string };
  if (!businessId) {
    throw new HttpsError("invalid-argument", "businessId is required.");
  }

  // Caller must be owner or manager to view the team list
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const snap = await db()
    .collection("users")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .get();

  return {
    users: snap.docs.map((doc) => {
      const data = doc.data();
      return {
        ...data,
        createdAt: (data.createdAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
      };
    }),
  };
});
