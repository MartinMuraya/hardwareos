// ============================================================
// Customer Functions — Credit customer management
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// createCustomer
// -----------------------------------------------------------
export const createCustomer = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, fullName, phoneNumber, nationalId, creditLimit } = request.data as {
    businessId: string;
    fullName: string;
    phoneNumber: string;
    nationalId?: string;
    creditLimit?: number;
  };

  if (!fullName || !phoneNumber) {
    throw new HttpsError("invalid-argument", "Full name and phone number are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  // Check duplicate phone number within this business
  const existing = await db()
    .collection("customers")
    .where("businessId", "==", businessId)
    .where("phoneNumber", "==", phoneNumber.trim())
    .limit(1)
    .get();

  if (!existing.empty) {
    throw new HttpsError("already-exists", "A customer with this phone number already exists.");
  }

  const ref = db().collection("customers").doc();
  const now = admin.firestore.Timestamp.now();

  await ref.set({
    id: ref.id,
    businessId,
    fullName: fullName.trim(),
    phoneNumber: phoneNumber.trim(),
    nationalId: nationalId?.trim() || "",
    creditLimit: creditLimit ?? 0,
    currentBalance: 0,
    totalDebt: 0,
    createdAt: now,
    updatedAt: now,
  });

  return { success: true, customerId: ref.id };
});

// -----------------------------------------------------------
// getCustomers
// -----------------------------------------------------------
export const getCustomers = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 50, startAfter, search } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
    search?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  try {
    let query: admin.firestore.Query = db()
      .collection("customers")
      .where("businessId", "==", businessId)
      .orderBy("fullName", "asc")
      .limit(Math.min(pageLimit, 100));

    if (startAfter) {
      const cursor = await db().collection("customers").doc(startAfter).get();
      if (cursor.exists) query = query.startAfter(cursor);
    }

    let snap = await query.get();

    const toDate = (val: unknown): string => {
      if (val && typeof (val as admin.firestore.Timestamp).toDate === "function") {
        return (val as admin.firestore.Timestamp).toDate().toISOString();
      }
      return val ? new Date(val as string).toISOString() : new Date().toISOString();
    };

    let docs = snap.docs.map((d) => ({
      ...d.data(),
      createdAt: toDate(d.data().createdAt),
      updatedAt: toDate(d.data().updatedAt),
    }));

    // Client-side search filter (Firestore lacks native full-text)
    if (search && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      docs = docs.filter(
        (c: any) =>
          c.fullName?.toLowerCase().includes(q) || c.phoneNumber?.includes(q)
      );
    }

    return { customers: docs };
  } catch {
    return { customers: [] };
  }
});

// -----------------------------------------------------------
// getCustomer
// -----------------------------------------------------------
export const getCustomer = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, customerId } = request.data as {
    businessId: string;
    customerId: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db().collection("customers").doc(customerId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }

  const data = snap.data()!;
  if (data.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Customer does not belong to your business.");
  }

  return {
    customer: {
      ...data,
      createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      updatedAt: (data.updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
    },
  };
});

// -----------------------------------------------------------
// updateCustomer
// -----------------------------------------------------------
export const updateCustomer = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, customerId, fullName, phoneNumber, nationalId, creditLimit } = request.data as {
    businessId: string;
    customerId: string;
    fullName?: string;
    phoneNumber?: string;
    nationalId?: string;
    creditLimit?: number;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const snap = await db().collection("customers").doc(customerId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }
  if (snap.data()!.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Customer does not belong to your business.");
  }

  const updates: Record<string, any> = { updatedAt: admin.firestore.Timestamp.now() };
  if (fullName !== undefined) updates.fullName = fullName.trim();
  if (phoneNumber !== undefined) updates.phoneNumber = phoneNumber.trim();
  if (nationalId !== undefined) updates.nationalId = nationalId.trim();
  if (creditLimit !== undefined) updates.creditLimit = creditLimit;

  await db().collection("customers").doc(customerId).update(updates);

  return { success: true };
});
