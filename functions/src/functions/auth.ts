// ============================================================
// Auth Functions — Business registration & user management
// ============================================================

import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as nodemailer from "nodemailer";
import { TRIAL_DAYS } from "../config/planLimits";
import { assertBusinessMember, assertUserLimit } from "../middleware/checkPlanLimits";
import { assertCanManageRole, sanitizeInput } from "../middleware/securityMiddleware";

const db = () => admin.firestore();

async function checkRateLimit(ip: string, action: string, maxAttempts: number, windowMs: number) {
  if (!ip) return; // Fallback if IP is unavailable
  const ref = db().collection("rateLimits").doc(`${action}_${ip}`);
  const snap = await ref.get();
  const now = Date.now();
  if (snap.exists) {
    const data = snap.data()!;
    if (now - data.timestamp < windowMs) {
      if (data.attempts >= maxAttempts) {
        throw new HttpsError("resource-exhausted", "Too many requests. Please try again later.");
      }
      await ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
    } else {
      await ref.set({ attempts: 1, timestamp: now });
    }
  } else {
    await ref.set({ attempts: 1, timestamp: now });
  }
}

// -----------------------------------------------------------
// createBusiness
// Called once when a new owner registers their hardware store.
// Creates the business doc + owner user profile atomically.
// -----------------------------------------------------------
export const createBusiness = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  // Rate limit by IP: Max 3 business creations per IP per hour
  const clientIp = request.rawRequest?.ip || "unknown";
  await checkRateLimit(clientIp, "createBusiness", 3, 60 * 60 * 1000);

  const { businessName } = request.data as { businessName: string };

  if (!businessName || businessName.trim().length < 2) {
    throw new HttpsError("invalid-argument", "Business name must be at least 2 characters.");
  }

  const uid = request.auth.uid;

  const cleanBusinessName = sanitizeInput(businessName);
  if (cleanBusinessName.length < 2) {
    throw new HttpsError("invalid-argument", "Business name must be at least 2 characters.");
  }

  const trialEndsAt = new Date();
  trialEndsAt.setDate(trialEndsAt.getDate() + TRIAL_DAYS);

  const businessRef = db().collection("businesses").doc();
  const baseSlug = cleanBusinessName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
  const tenantSlug = `${baseSlug}-${businessRef.id.substring(0, 6)}`;
  const userRef = db().collection("users").doc(uid);

  await db().runTransaction(async (txn) => {
    const existingUser = await txn.get(userRef);
    if (existingUser.exists) {
      throw new HttpsError("already-exists", "You are already registered to a business.");
    }

    txn.set(businessRef, {
      id: businessRef.id,
      name: cleanBusinessName,
      tenantSlug,
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

    txn.set(userRef, {
      uid,
      businessId: businessRef.id,
      role: "owner",
      displayName: request.auth!.token.name || "",
      email: request.auth!.token.email || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  try {
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || "smtp.gmail.com",
      port: parseInt(process.env.SMTP_PORT || "587"),
      secure: process.env.SMTP_SECURE === "true",
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });

    if (process.env.SMTP_USER && process.env.SMTP_PASS && process.env.SUPER_ADMIN_EMAIL) {
      const mailOptions = {
        from: `"HardwareOS System" <${process.env.SMTP_USER}>`,
        to: process.env.SUPER_ADMIN_EMAIL,
        subject: `[HardwareOS] New Registration: ${businessName.trim()}`,
        text: `A new hardware store has registered on HardwareOS.\n\nBusiness Name: ${businessName.trim()}\nTenant Slug: ${tenantSlug}\nOwner Email: ${request.auth.token.email}\nBusiness ID: ${businessRef.id}\n\nPlease verify this business in the Super Admin Dashboard.`,
      };
      await transporter.sendMail(mailOptions);
    } else {
      console.warn("SMTP credentials or SUPER_ADMIN_EMAIL not configured. Skipping Super Admin registration alert email.");
    }
  } catch (err) {
    console.error("Failed to send Super Admin alert email:", err);
  }

  // --------------------------------------------------------------------------
  // SUPER ADMIN PUSH NOTIFICATIONS (TELEGRAM / SMS / WHATSAPP)
  // --------------------------------------------------------------------------
  const messageBody = `🚨 *New HardwareOS Registration*\n\n*Business:* ${businessName.trim()}\n*Email:* ${request.auth.token.email}\n*Status:* Pending Approval`;

  // 1. Telegram Integration (100% Free Instant Push)
  const telegramBotToken = process.env.TELEGRAM_BOT_TOKEN;
  const telegramChatId = process.env.TELEGRAM_CHAT_ID;

  if (telegramBotToken && telegramChatId) {
    try {
      await fetch(`https://api.telegram.org/bot${telegramBotToken}/sendMessage`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: telegramChatId,
          text: messageBody,
          parse_mode: "Markdown",
        }),
      });
      console.log("Telegram Super Admin alert sent.");
    } catch (err) {
      console.error("Failed to send Telegram alert:", err);
    }
  }

  // 2. Africa's Talking SMS Skeleton
  const atApiKey = process.env.AT_API_KEY;
  const atUsername = process.env.AT_USERNAME;
  const adminPhone = process.env.SUPER_ADMIN_PHONE;
  if (atApiKey && atUsername && adminPhone) {
    console.log("Mocking Africa's Talking SMS to:", adminPhone);
    // TODO: Initialize Africa's Talking SDK and send SMS
    // const credentials = { apiKey: atApiKey, username: atUsername };
    // const AfricasTalking = require('africastalking')(credentials);
    // const sms = AfricasTalking.SMS;
    // await sms.send({ to: [adminPhone], message: messageBody });
  }

  // 3. WhatsApp Business API / Twilio Skeleton
  const twilioSid = process.env.TWILIO_ACCOUNT_SID;
  const twilioAuth = process.env.TWILIO_AUTH_TOKEN;
  if (twilioSid && twilioAuth && adminPhone) {
    console.log("Mocking Twilio WhatsApp message to:", adminPhone);
    // TODO: Initialize Twilio SDK and send WhatsApp
    // const client = require('twilio')(twilioSid, twilioAuth);
    // await client.messages.create({
    //   body: messageBody,
    //   from: 'whatsapp:+14155238886',
    //   to: `whatsapp:${adminPhone}`
    // });
  }

  return {
    businessId: businessRef.id,
    businessName: cleanBusinessName,
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
export const inviteUser = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { targetUid, role, businessId, displayName, commissionRate } = request.data as {
    targetUid: string;
    role: "manager" | "staff";
    businessId: string;
    displayName: string;
    commissionRate?: number;
  };

  if (!["manager", "staff"].includes(role)) {
    throw new HttpsError("invalid-argument", "Role must be manager or staff.");
  }

  // Caller must be owner or manager
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  // Role escalation protection
  await assertCanManageRole(request.auth.uid, businessId, role);

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
    commissionRate: commissionRate ? Number(commissionRate) : 0,
    commissionBalance: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: `User added as ${role}.` };
});

// -----------------------------------------------------------
// updateStaff
// Owner/Manager updates an existing staff member's role or commission.
// -----------------------------------------------------------
export const updateStaff = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const { targetUid, role, businessId, commissionRate } = request.data as {
    targetUid: string;
    role: "manager" | "staff";
    businessId: string;
    commissionRate?: number;
  };

  if (!["manager", "staff"].includes(role)) {
    throw new HttpsError("invalid-argument", "Role must be manager or staff.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertCanManageRole(request.auth.uid, businessId, role);

  const targetSnap = await db().collection("users").doc(targetUid).get();
  if (!targetSnap.exists || targetSnap.data()?.businessId !== businessId) {
    throw new HttpsError("not-found", "User not found in your business.");
  }

  await db().collection("users").doc(targetUid).update({
    role,
    commissionRate: commissionRate !== undefined ? Number(commissionRate) : targetSnap.data()?.commissionRate || 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: "Staff updated successfully." };
});

// -----------------------------------------------------------
// getMyProfile
// Returns the calling user's profile + business info + super admin status.
// Called on app startup to restore session context.
// -----------------------------------------------------------
export const getMyProfile = onCall(SECURE_FN_OPTS, async (request) => {
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
export const getUsers = onCall(SECURE_FN_OPTS, async (request) => {
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
