import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember } from "../middleware/checkPlanLimits";

export enum MovementType {
  OPENING_BALANCE = "OPENING_BALANCE",
  SALE = "SALE",
  PURCHASE = "PURCHASE",
  RETURN = "RETURN",
  ADJUSTMENT = "ADJUSTMENT",
  TRANSFER_OUT = "TRANSFER_OUT",
  TRANSFER_IN = "TRANSFER_IN",
}

export interface InventoryLedgerEntry {
  id: string;
  businessId: string;
  branchId?: string | null;
  productId: string;
  productName: string;
  movementType: MovementType;
  quantity: number; // positive for incoming, negative for outgoing
  costAtTime: number; // The unit cost at the time of movement
  referenceId: string; // The ID of the Sale, Purchase Order, Return, or Adjustment
  performedBy: string; // UID of the user who performed the action
  reason?: string; // Optional reason (e.g., for adjustments)
  timestamp: admin.firestore.Timestamp | admin.firestore.FieldValue;
}

/**
 * Helper to record an inventory movement in a Firestore Transaction or Batch.
 * Note: This does NOT update the materialized `quantity` on the product document itself.
 * The caller must still update `product.quantity` via `FieldValue.increment` to ensure fast reads.
 */
export function recordInventoryMovement(
  writer: admin.firestore.Transaction | admin.firestore.WriteBatch,
  entry: Omit<InventoryLedgerEntry, "id" | "timestamp">
) {
  const db = admin.firestore();
  const ref = db.collection("inventory_ledger").doc();
  const data = {
    ...entry,
    id: ref.id,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };

  if ("commit" in writer) {
    (writer as admin.firestore.WriteBatch).set(ref, data);
  } else {
    (writer as admin.firestore.Transaction).set(ref, data);
  }
}

// -----------------------------------------------------------
// Migration Script: Convert existing quantity to OPENING_BALANCE
// -----------------------------------------------------------
export const migrateToLedger = onCall({ cors: true, timeoutSeconds: 540 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  
  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);

  const db = admin.firestore();
  
  // 1. Check if migration already ran (prevent duplicate opening balances)
  const existingLedgerSnap = await db.collection("inventory_ledger")
    .where("businessId", "==", businessId)
    .where("movementType", "==", MovementType.OPENING_BALANCE)
    .limit(1)
    .get();

  if (!existingLedgerSnap.empty) {
    return { success: false, message: "Migration already completed for this business." };
  }

  // 2. Fetch all products
  const productsSnap = await db.collection("products")
    .where("businessId", "==", businessId)
    .get();

  let migratedCount = 0;
  
  // We use batching because there might be thousands of products
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of productsSnap.docs) {
    const product = doc.data();
    const qty = Number(product.quantity) || 0;
    
    // Even if qty is 0, it's good to have an opening balance ledger entry
    const ref = db.collection("inventory_ledger").doc();
    batch.set(ref, {
      id: ref.id,
      businessId,
      productId: doc.id,
      productName: product.name || "Unknown",
      movementType: MovementType.OPENING_BALANCE,
      quantity: qty,
      costAtTime: Number(product.costPrice) || 0,
      referenceId: "MIGRATION",
      performedBy: request.auth.uid,
      reason: "System upgrade to Event-Sourced Ledger",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    migratedCount++;
    batchCount++;

    if (batchCount === 450) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return { success: true, migratedProducts: migratedCount };
});
