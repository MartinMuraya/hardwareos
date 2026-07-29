// ============================================================
// Shared Cloud Function Options
// All callable functions should use these options for security.
// ============================================================

import { HttpsOptions } from "firebase-functions/v2/https";

/** Default production domain whitelist for CORS. */
const ALLOWED_ORIGINS = [
  "https://hardwareos-saas.web.app",
  "https://hardwareos-saas.firebaseapp.com",
  // Add your custom domain here when ready:
  // "https://app.hardwareos.co.ke",
];

/**
 * Secure callable options — enforces App Check and restricts CORS.
 * Use for ALL authenticated callable functions.
 */
export const SECURE_FN_OPTS: HttpsOptions = {
  cors: ALLOWED_ORIGINS,
  enforceAppCheck: true,
};

/**
 * Public callable options — enforces App Check but allows broader CORS.
 * Use for public-facing endpoints like storefront that don't require auth.
 */
export const PUBLIC_FN_OPTS: HttpsOptions = {
  cors: true, // Public storefront needs broad access
  enforceAppCheck: true,
};

/**
 * Webhook options — no App Check (external callers like M-Pesa).
 * These endpoints validate via webhook secret instead.
 */
export const WEBHOOK_FN_OPTS: HttpsOptions = {
  cors: true,
  enforceAppCheck: false,
};
