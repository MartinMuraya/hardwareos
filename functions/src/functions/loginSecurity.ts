import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  checkLoginRateLimit,
  recordFailedLogin,
  clearLoginAttempts,
  checkPasswordResetRateLimit,
  recordPasswordResetRequest,
  writeAuditLog,
} from "../middleware/securityMiddleware";
import { rateLimitCheck } from "../middleware/rateLimiter";

export const checkLoginLocked = onCall(SECURE_FN_OPTS, async (request) => {
  const { email } = request.data as { email: string };
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");

  await checkLoginRateLimit(email);
  return { allowed: true };
});

export const reportFailedLogin = onCall(SECURE_FN_OPTS, async (request) => {
  const { email } = request.data as { email: string };
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");
  
  await rateLimitCheck(request.rawRequest?.ip || "unknown", "reportFailedLogin", 10, 60);

  await recordFailedLogin(email);

  await writeAuditLog({
    action: "LOGIN_FAILED",
    metadata: { email },
  });

  // Check if they're now locked
  try {
    await checkLoginRateLimit(email);
  } catch {
    await writeAuditLog({
      action: "LOGIN_LOCKED",
      metadata: { email },
    });
  }

  return { recorded: true };
});

export const reportSuccessfulLogin = onCall(SECURE_FN_OPTS, async (request) => {
  const { email } = request.data as { email: string };
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");
  
  await rateLimitCheck(request.rawRequest?.ip || "unknown", "reportSuccessfulLogin", 20, 60);

  await clearLoginAttempts(email);
  return { recorded: true };
});

export const requestPasswordReset = onCall(SECURE_FN_OPTS, async (request) => {
  const { email } = request.data as { email: string };
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");

  const normalizedEmail = email.trim().toLowerCase();

  // Check rate limit silently (never reveal account existence)
  await checkPasswordResetRateLimit(normalizedEmail);
  await recordPasswordResetRequest(normalizedEmail);

  await writeAuditLog({
    action: "PASSWORD_RESET_REQUESTED",
    metadata: { email: normalizedEmail },
  });

  try {
    const link = await admin.auth().generatePasswordResetLink(normalizedEmail);
    // TODO (SEC-014): Integrate SendGrid or Postmark here to email `link` to the user.
    // For now, we log it for debugging (or SMS it via Twilio if applicable).
    console.log(`Password reset link generated for ${normalizedEmail}: ${link}`);
  } catch (err: any) {
    // If the user doesn't exist, admin.auth() will throw. We silently ignore it
    // to prevent email enumeration attacks.
    if (err.code !== 'auth/user-not-found') {
      console.error("Error generating password reset link:", err);
    }
  }

  // Always return the same message regardless of whether the email exists
  return { message: "If an account exists for this email, a reset link has been sent." };
});
