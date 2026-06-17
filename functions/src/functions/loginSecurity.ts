import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  checkLoginRateLimit,
  recordFailedLogin,
  clearLoginAttempts,
  checkPasswordResetRateLimit,
  recordPasswordResetRequest,
  writeAuditLog,
} from "../middleware/securityMiddleware";

export const checkLoginLocked = onCall({ cors: true }, async (request) => {
  const { email } = request.data as { email: string };
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");

  await checkLoginRateLimit(email);
  return { allowed: true };
});

export const reportFailedLogin = onCall({ cors: true }, async (request) => {
  const { email } = request.data as { email: string };
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");

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

export const reportSuccessfulLogin = onCall({ cors: true }, async (request) => {
  const { email } = request.data as { email: string };
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");

  await clearLoginAttempts(email);
  return { recorded: true };
});

export const requestPasswordReset = onCall({ cors: true }, async (request) => {
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

  // Always return the same message regardless of whether the email exists
  return { message: "If an account exists for this email, a reset link has been sent." };
});
