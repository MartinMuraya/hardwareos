import * as Sentry from "@sentry/node";
import { CallableRequest } from "firebase-functions/v2/https";

// ==============================================================
// Sentry Observability Configuration
// - Attaches userId to all errors
// - Adds request context (endpoint, caller)
// - Sanitizes sensitive fields before sending
// ==============================================================

const SENSITIVE_KEYS = new Set([
  "password", "token", "secret", "authorization", "apiKey",
  "consumerKey", "consumerSecret", "passkey", "mpesaPin",
  "phoneNumber", "creditCard", "cvv",
]);

/**
 * Initialize Sentry with production-safe defaults.
 * Call once at the top of index.ts.
 */
export function initSentry(dsn?: string): void {
  if (!dsn) return;
  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV || "production",
    tracesSampleRate: 0.1,
    beforeSend(event) {
      if (event.request?.data) {
        event.request.data = sanitizeSentryData(event.request.data);
      }
      if (event.extra) {
        event.extra = sanitizeSentryData(event.extra);
      }
      return event;
    },
  });
}

/**
 * Attach user context and request metadata to the current Sentry scope.
 * Call at the start of every callable function after auth check.
 */
export function setSentryUserContext(
  request: CallableRequest,
  extra?: Record<string, unknown>,
): void {
  if (!request.auth) return;

  Sentry.setUser({
    id: request.auth.uid,
    email: request.auth.token.email || undefined,
  });

  Sentry.setTags({
    caller_uid: request.auth.uid,
  });

  if (extra) {
    Sentry.setExtras(sanitizeSentryData(extra));
  }
}

/**
 * Recursively strip sensitive fields from log data.
 */
function sanitizeSentryData(
  data: Record<string, unknown>,
): Record<string, unknown> {
  const safe: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (SENSITIVE_KEYS.has(key.toLowerCase())) {
      safe[key] = "[REDACTED]";
    } else if (typeof value === "object" && value !== null && !Array.isArray(value)) {
      safe[key] = sanitizeSentryData(value as Record<string, unknown>);
    } else if (Array.isArray(value)) {
      safe[key] = value.map((item) =>
        typeof item === "object" && item !== null
          ? sanitizeSentryData(item as Record<string, unknown>)
          : item,
      );
    } else {
      safe[key] = value;
    }
  }
  return safe;
}
