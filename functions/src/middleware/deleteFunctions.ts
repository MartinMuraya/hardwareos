import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "./checkPlanLimits";

const db = () => admin.firestore();

// ==============================================================
// Shared soft-delete implementation
// All delete functions follow the same pattern:
// 1. Validate caller is owner/manager
// 2. Verify resource belongs to business
// 3. Set isActive = false + deletedAt timestamp
// 4. Write enhanced audit log entry
// ==============================================================

export interface SoftDeleteParams {
  businessId: string;
  resourceId: string;
  collection: string;
  callerUid: string;
  targetType?: string;
  reason?: string;
}

export async function softDeleteResource(
  params: SoftDeleteParams,
): Promise<void> {
  const { businessId, resourceId, collection, callerUid, targetType, reason } = params;

  await assertBusinessMember(callerUid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const doc = await db().collection(collection).doc(resourceId).get();
  if (!doc.exists) {
    throw new HttpsError("not-found", `${collection.slice(0, -1)} not found.`);
  }
  if (doc.data()!.businessId !== businessId) {
    throw new HttpsError("permission-denied", `${collection.slice(0, -1)} does not belong to your business.`);
  }

  const resourceType = targetType || collection;

  await db().runTransaction(async (txn) => {
    txn.update(db().collection(collection).doc(resourceId), {
      isActive: false,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Enhanced audit log entry
    const auditRef = db().collection("auditLogs").doc();
    txn.set(auditRef, {
      actorId: callerUid,
      actionSource: "api",
      action: `${resourceType.slice(0, -1).toUpperCase()}_DELETED`,
      businessId,
      targetId: resourceId,
      targetType: resourceType,
      reason: reason || null,
      metadata: {
        resourceName: doc.data()!.name || doc.data()!.fullName || resourceId,
      },
      previousValues: {
        isActive: true,
      },
      newValues: {
        isActive: false,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}
