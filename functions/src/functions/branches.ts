// ============================================================
// Multi-Branch Operations — Branches, transfers, branch inventory
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// createBranch
// Only owner can create branches.
// -----------------------------------------------------------
export const createBranch = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, name, address, phone } = request.data as {
    businessId: string;
    name: string;
    address?: string;
    phone?: string;
  };

  if (!name) throw new HttpsError("invalid-argument", "Branch name is required.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);
  await assertActiveSubscription(businessId);

  const branchRef = db().collection("branches").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db().batch();
  batch.set(branchRef, {
    id: branchRef.id,
    businessId,
    name: name.trim(),
    address: address?.trim() || "",
    managerId: null,
    phone: phone?.trim() || "",
    active: true,
    createdAt: now,
  });

  const userSnap = await db().collection("users").doc(request.auth!.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";
  const auditRef = db().collection("auditLogs").doc();
  batch.set(auditRef, {
    id: auditRef.id,
    businessId, userId: request.auth!.uid, userName,
    module: "Branches", action: "Create Branch",
    entityId: branchRef.id, entityName: name.trim(),
    oldValues: {}, newValues: { name: name.trim(), active: true },
    metadata: {}, createdAt: now,
  });

  await batch.commit();
  return { success: true, branchId: branchRef.id };
});

// -----------------------------------------------------------
// getBranches
// -----------------------------------------------------------
export const getBranches = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db()
    .collection("branches")
    .where("businessId", "==", businessId)
    .orderBy("name")
    .get();

  return {
    branches: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});

// -----------------------------------------------------------
// updateBranch
// Owner can update branch details.
// -----------------------------------------------------------
export const updateBranch = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, branchId, updates } = request.data as {
    businessId: string;
    branchId: string;
    updates: Record<string, unknown>;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);
  await assertActiveSubscription(businessId);

  const safe = { ...updates };
  delete safe["id"];
  delete safe["businessId"];
  safe["updatedAt"] = admin.firestore.FieldValue.serverTimestamp();

  await db().collection("branches").doc(branchId).update(safe);
  return { success: true };
});

// -----------------------------------------------------------
// requestStockTransfer
// Branch staff requests stock from another branch.
// -----------------------------------------------------------
export const requestStockTransfer = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, fromBranchId, toBranchId, productId, quantity, productName } = request.data as {
    businessId: string;
    fromBranchId: string;
    toBranchId: string;
    productId: string;
    quantity: number;
    productName?: string;
  };

  if (!fromBranchId || !toBranchId || !productId || !quantity || quantity <= 0) {
    throw new HttpsError("invalid-argument", "fromBranchId, toBranchId, productId, and positive quantity required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const transferRef = db().collection("stockTransfers").doc();
  const now = admin.firestore.Timestamp.now();

  const userSnap = await db().collection("users").doc(request.auth!.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";

  await db().runTransaction(async (txn) => {
    txn.set(transferRef, {
      id: transferRef.id,
      businessId,
      fromBranchId,
      toBranchId,
      productId,
      productName: productName || "",
      quantity: Math.floor(quantity),
      status: "pending",
      requestedBy: request.auth!.uid,
      requestedByName: userName,
      approvedBy: null,
      approvedByName: null,
      createdAt: now,
      completedAt: null,
    });

    const auditRef = db().collection("auditLogs").doc();
    txn.set(auditRef, {
      id: auditRef.id, businessId,
      userId: request.auth!.uid, userName,
      module: "Branches", action: "Request Stock Transfer",
      entityId: transferRef.id,
      entityName: `${quantity}x ${productName || productId} (${fromBranchId} → ${toBranchId})`,
      oldValues: {}, newValues: { fromBranchId, toBranchId, productId, quantity, status: "pending" },
      metadata: { transferId: transferRef.id },
      createdAt: now,
    });
  });

  return { success: true, transferId: transferRef.id };
});

// -----------------------------------------------------------
// approveStockTransfer
// Manager/owner approves and executes the transfer atomically.
// -----------------------------------------------------------
export const approveStockTransfer = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, transferId } = request.data as {
    businessId: string;
    transferId: string;
  };

  if (!transferId) throw new HttpsError("invalid-argument", "transferId is required.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const userSnap = await db().collection("users").doc(request.auth!.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";

  const result = await db().runTransaction(async (txn) => {
    const transferSnap = await txn.get(db().collection("stockTransfers").doc(transferId));
    if (!transferSnap.exists) throw new HttpsError("not-found", "Transfer not found.");

    const transfer = transferSnap.data()!;
    if (transfer.status !== "pending") {
      throw new HttpsError("failed-precondition", "Transfer is already processed.");
    }

    // Deduct from source branch inventory
    const fromKey = `${transfer.productId}_${transfer.fromBranchId}`;
    const fromSnap = await txn.get(db().collection("branchInventory").doc(fromKey));
    if (!fromSnap.exists || (fromSnap.data()?.quantity || 0) < transfer.quantity) {
      throw new HttpsError("resource-exhausted", "Insufficient stock at source branch.");
    }

    txn.update(db().collection("branchInventory").doc(fromKey), {
      quantity: admin.firestore.FieldValue.increment(-transfer.quantity),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    // Add to destination branch inventory
    const toKey = `${transfer.productId}_${transfer.toBranchId}`;
    const toSnap = await txn.get(db().collection("branchInventory").doc(toKey));
    if (toSnap.exists) {
      txn.update(db().collection("branchInventory").doc(toKey), {
        quantity: admin.firestore.FieldValue.increment(transfer.quantity),
        updatedAt: admin.firestore.Timestamp.now(),
      });
    } else {
      txn.set(db().collection("branchInventory").doc(toKey), {
        id: toKey,
        businessId,
        branchId: transfer.toBranchId,
        productId: transfer.productId,
        quantity: transfer.quantity,
        createdAt: admin.firestore.Timestamp.now(),
      });
    }

    const now = admin.firestore.Timestamp.now();
    txn.update(db().collection("stockTransfers").doc(transferId), {
      status: "completed",
      approvedBy: request.auth!.uid,
      approvedByName: userName,
      completedAt: now,
    });

    // Audit log
    const auditRef = db().collection("auditLogs").doc();
    txn.set(auditRef, {
      id: auditRef.id, businessId,
      userId: request.auth!.uid, userName,
      module: "Branches", action: "Approve Stock Transfer",
      entityId: transferId,
      entityName: `${transfer.quantity}x ${transfer.productName || transfer.productId}`,
      oldValues: { status: "pending" },
      newValues: { status: "completed", approvedBy: userName },
      metadata: { transferId, fromBranchId: transfer.fromBranchId, toBranchId: transfer.toBranchId },
      createdAt: now,
    });

    return {
      fromBranchId: transfer.fromBranchId,
      toBranchId: transfer.toBranchId,
      quantity: transfer.quantity,
    };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getStockTransfers
// -----------------------------------------------------------
export const getStockTransfers = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, status, limit: pageLimit = 50 } = request.data as {
    businessId: string;
    status?: string;
    limit?: number;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("stockTransfers")
    .where("businessId", "==", businessId);

  if (status) query = query.where("status", "==", status);

  query = query.orderBy("createdAt", "desc").limit(Math.min(pageLimit, 100));
  const snap = await query.get();

  return {
    transfers: snap.docs.map((d) => {
      const data = d.data();
      return {
        ...data,
        createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
        completedAt: data.completedAt ? (data.completedAt as admin.firestore.Timestamp).toDate().toISOString() : null,
      };
    }),
  };
});

// -----------------------------------------------------------
// getBranchInventory
// -----------------------------------------------------------
export const getBranchInventory = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, branchId } = request.data as { businessId: string; branchId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db()
    .collection("branchInventory")
    .where("businessId", "==", businessId)
    .where("branchId", "==", branchId)
    .get();

  return {
    inventory: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      updatedAt: (d.data().updatedAt as admin.firestore.Timestamp)?.toDate()?.toISOString() || null,
    })),
  };
});

// -----------------------------------------------------------
// getBranchPerformance — dashboard widget data
// -----------------------------------------------------------
export const getBranchPerformance = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  try {
    // Aggregate sales by branch
    const salesSnap = await db()
      .collection("sales")
      .where("businessId", "==", businessId)
      .orderBy("createdAt", "desc")
      .limit(2000)
      .get();

    const branchMap: Record<string, { sales: number; profit: number; count: number }> = {};

    salesSnap.docs.forEach((d) => {
      const data = d.data();
      const branchId = (data.branchId as string) || "main";
      if (!branchMap[branchId]) branchMap[branchId] = { sales: 0, profit: 0, count: 0 };
      branchMap[branchId].sales += data.total || 0;
      branchMap[branchId].profit += data.profit || 0;
      branchMap[branchId].count++;
    });

    return { branches: branchMap };
  } catch (e) {
    return { branches: {} };
  }
});

// -----------------------------------------------------------
// getPendingTransfers — count for dashboard widget
// -----------------------------------------------------------
export const getPendingTransfers = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  try {
    const snap = await db()
      .collection("stockTransfers")
      .where("businessId", "==", businessId)
      .where("status", "==", "pending")
      .count()
      .get();

    return { pendingCount: snap.data().count };
  } catch (e) {
    return { pendingCount: 0 };
  }
});
