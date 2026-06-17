import * as admin from "firebase-admin";

const db = () => admin.firestore();

export type ActionSource = "admin_panel" | "api" | "system" | "mobile_app" | "cron";

export type AuditAction =
  | "USER_CREATED" | "USER_DELETED" | "ROLE_CHANGED"
  | "LOGIN_FAILED" | "LOGIN_LOCKED" | "PASSWORD_RESET_REQUESTED"
  | "SUB_PAYMENT_INITIATED" | "SUB_ACTIVATED" | "SUB_EXPIRED"
  | "SUB_RENEWED" | "PLAN_CHANGED"
  | "PRODUCT_CREATED" | "PRODUCT_UPDATED" | "PRODUCT_DELETED"
  | "SALE_CREATED" | "SALE_VOIDED"
  | "RETURN_CREATED"
  | "STOCK_ADJUSTED" | "CASH_DRAWER_CLOSED"
  | "BRANCH_TRANSFER_CREATED" | "BRANCH_TRANSFER_RECEIVED"
  | "ADMIN_UPDATE_USER" | "ADMIN_UPDATE_BUSINESS" | "ADMIN_UPDATE_SETTINGS"
  | "BUSINESS_APPROVED" | "BUSINESS_SUSPENDED"
  | "SYNC_FAILED" | "DLQ_RECEIVED";

// ==============================================================
// Enhanced audit log schema:
// - actorId: who performed the action
// - actionSource: admin_panel | api | system | mobile_app | cron
// - timestamp: always serverTimestamp
// - reason: optional human-readable explanation
// - metadata: structured payload with safe-filtered PII
// ==============================================================

export interface AuditLogEntry {
  actorId: string;
  action: AuditAction | string;
  actionSource: ActionSource;
  businessId?: string;
  targetId?: string;
  targetType?: string;
  reason?: string;
  metadata?: Record<string, unknown>;
  previousValues?: Record<string, unknown>;
  newValues?: Record<string, unknown>;
}

export async function writeAuditLog(
  entry: AuditLogEntry,
): Promise<void> {
  const safeMetadata = sanitizeMetadata(entry.metadata);

  await db().collection("auditLogs").add({
    actorId: entry.actorId,
    action: entry.action,
    actionSource: entry.actionSource,
    businessId: entry.businessId || null,
    targetId: entry.targetId || null,
    targetType: entry.targetType || null,
    reason: entry.reason || null,
    metadata: safeMetadata,
    previousValues: entry.previousValues || null,
    newValues: entry.newValues || null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ==============================================================
// Sensitive field redaction for audit metadata
// Prevents passwords, tokens, and PII from reaching audit logs
// ==============================================================
const SENSITIVE_FIELDS = new Set([
  "password", "token", "secret", "authorization", "apiKey",
  "consumerKey", "consumerSecret", "passkey", "mpesaPin",
  "phoneNumber",
]);

function sanitizeMetadata(
  metadata?: Record<string, unknown>,
): Record<string, unknown> | null {
  if (!metadata) return null;
  const safe: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(metadata)) {
    if (SENSITIVE_FIELDS.has(key.toLowerCase())) {
      safe[key] = "[REDACTED]";
    } else if (typeof value === "object" && value !== null) {
      safe[key] = sanitizeMetadata(value as Record<string, unknown>);
    } else {
      safe[key] = value;
    }
  }
  return safe;
}
