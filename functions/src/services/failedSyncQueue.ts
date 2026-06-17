// ============================================================
// Enhanced Failed Sync Queue (H5 Upgrade)
// - Exponential backoff + Dead Letter Queue + Retry Scheduler
// ============================================================

import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";

const db = () => admin.firestore();

export const MAX_RETRIES = 5;
export const DLQ_COLLECTION = "failedSyncDLQ";
export const BASE_RETRY_DELAY_MS = 60_000; // 1 minute

export interface FailedSyncEntry {
  id: string;
  businessId: string;
  collection: string;
  documentId: string;
  operation: "create" | "update" | "delete";
  payload: Record<string, unknown>;
  error: string;
  errorCode?: string;
  retryCount: number;
  maxRetries: number;
  dedupKey: string;
  lastAttemptAt: admin.firestore.Timestamp | null;
  nextRetryAt: admin.firestore.Timestamp | null;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  movedToDLQ: boolean;
  dlqMovedAt: admin.firestore.Timestamp | null;
}

// ==============================================================
// 1. Record a failed sync attempt with deduplication
// ==============================================================
export async function recordFailedSync(params: {
  businessId: string;
  collection: string;
  documentId: string;
  operation: "create" | "update" | "delete";
  payload: Record<string, unknown>;
  error: string;
  errorCode?: string;
}): Promise<string> {
  const dedupKey = `${params.collection}:${params.documentId}:${params.operation}`;
  const now = admin.firestore.FieldValue.serverTimestamp();

  // Check for existing entry with same dedup key
  const existing = await db()
    .collection("failedSync")
    .where("dedupKey", "==", dedupKey)
    .where("movedToDLQ", "==", false)
    .limit(1)
    .get();

  if (!existing.empty) {
    // Update retry count and last attempt
    const entry = existing.docs[0];
    const retryCount = (entry.data().retryCount || 0) + 1;
    const nextRetryMs = calculateBackoff(retryCount);

    await entry.ref.update({
      retryCount,
      lastAttemptAt: now,
      nextRetryAt: admin.firestore.Timestamp.fromMillis(Date.now() + nextRetryMs),
      error: params.error,
      errorCode: params.errorCode || null,
      payload: params.payload,
      updatedAt: now,
    });

    // Move to DLQ if max retries exceeded
    if (retryCount >= MAX_RETRIES) {
      await moveToDLQ(entry.id, entry.data());
    }

    return entry.id;
  }

  // New entry
  const nextRetryMs = calculateBackoff(0);
  const ref = db().collection("failedSync").doc();
  await ref.set({
    id: ref.id,
    businessId: params.businessId,
    collection: params.collection,
    documentId: params.documentId,
    operation: params.operation,
    payload: params.payload,
    error: params.error,
    errorCode: params.errorCode || null,
    retryCount: 1,
    maxRetries: MAX_RETRIES,
    dedupKey,
    lastAttemptAt: now,
    nextRetryAt: admin.firestore.Timestamp.fromMillis(Date.now() + nextRetryMs),
    createdAt: now,
    updatedAt: now,
    movedToDLQ: false,
    dlqMovedAt: null,
  });

  return ref.id;
}

// ==============================================================
// 2. Exponential backoff calculation (with jitter)
// ==============================================================
function calculateBackoff(retryCount: number): number {
  if (retryCount <= 0) return BASE_RETRY_DELAY_MS;
  const base = BASE_RETRY_DELAY_MS * Math.pow(2, retryCount - 1);
  const jitter = Math.random() * 0.3 * base; // up to 30% jitter
  return Math.min(base + jitter, 30 * 60_000); // cap at 30 minutes
}

// ==============================================================
// 3. Dead Letter Queue — Escalate permanently failed entries
// ==============================================================
async function moveToDLQ(entryId: string, data: Record<string, unknown>): Promise<void> {
  const now = admin.firestore.FieldValue.serverTimestamp();

  await db().runTransaction(async (txn) => {
    const dlqRef = db().collection(DLQ_COLLECTION).doc();
    txn.set(dlqRef, {
      originalEntryId: entryId,
      businessId: data.businessId,
      collection: data.collection,
      documentId: data.documentId,
      operation: data.operation,
      payload: data.payload,
      error: data.error,
      errorCode: data.errorCode || null,
      retryCount: data.retryCount,
      dedupKey: data.dedupKey,
      movedAt: now,
      createdAt: data.createdAt,
    });

    txn.update(db().collection("failedSync").doc(entryId), {
      movedToDLQ: true,
      dlqMovedAt: now,
      updatedAt: now,
    });
  });
}

// ==============================================================
// 4. Get entries ready for retry
// ==============================================================
export async function getEntriesDueForRetry(maxEntries = 20): Promise<admin.firestore.DocumentSnapshot[]> {
  const now = admin.firestore.Timestamp.now();
  const snap = await db()
    .collection("failedSync")
    .where("movedToDLQ", "==", false)
    .where("nextRetryAt", "<=", now)
    .orderBy("nextRetryAt", "asc")
    .limit(maxEntries)
    .get();

  return snap.docs;
}

// ==============================================================
// 5. Scheduled retry processor — runs every 5 minutes
// ==============================================================
export const processFailedSyncRetries = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Africa/Nairobi" },
  async () => {
    const entries = await getEntriesDueForRetry(20);

    for (const doc of entries) {
      const entry = doc.data() as FailedSyncEntry;

      try {
        // Attempt to replay the operation
        const collection = db().collection(entry.collection);
        const docRef = collection.doc(entry.documentId);

        switch (entry.operation) {
          case "create":
          case "update":
            await docRef.set(entry.payload, { merge: true });
            break;
          case "delete":
            await docRef.delete();
            break;
        }

        // Success — remove from failed sync
        await doc.ref.delete();

        // Log successful recovery
        await db().collection("auditLogs").add({
          actorId: "system:cron",
          actionSource: "cron",
          action: "SYNC_RECOVERED",
          businessId: entry.businessId,
          targetId: entry.documentId,
          targetType: entry.collection,
          metadata: { operation: entry.operation },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        // Update retry state
        const retryCount = entry.retryCount + 1;
        const nextRetryMs = calculateBackoff(retryCount);

        await doc.ref.update({
          retryCount,
          lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
          nextRetryAt: admin.firestore.Timestamp.fromMillis(Date.now() + nextRetryMs),
          error: err instanceof Error ? err.message : String(err),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Move to DLQ if maxed
        if (retryCount >= MAX_RETRIES) {
          const updatedData = (await doc.ref.get()).data()!;
          await moveToDLQ(doc.id, updatedData);
        }
      }
    }
  }
);

// ==============================================================
// 6. Admin: View DLQ entries
// ==============================================================
export function getDLQCollection(): string {
  return DLQ_COLLECTION;
}
