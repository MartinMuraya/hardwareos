// ============================================================
// Supplier Functions
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription, softDeleteResource } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// createSupplier
// -----------------------------------------------------------
export const createSupplier = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, name, phoneNumber, email, address, contactPerson, paymentTerms } = request.data as {
    businessId: string;
    name: string;
    phoneNumber: string;
    email?: string;
    address?: string;
    contactPerson?: string;
    paymentTerms?: string;
  };

  if (!name || !phoneNumber) {
    throw new HttpsError("invalid-argument", "Name and phone number are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const ref = db().collection("suppliers").doc();
  const now = admin.firestore.Timestamp.now();

  await ref.set({
    id: ref.id,
    businessId,
    name: name.trim(),
    phoneNumber: phoneNumber.trim(),
    email: email?.trim() || "",
    address: address?.trim() || "",
    contactPerson: contactPerson?.trim() || "",
    paymentTerms: paymentTerms?.trim() || "30 days",
    currentBalance: 0,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  });

  return { success: true, supplierId: ref.id };
});

// -----------------------------------------------------------
// getSuppliers
// -----------------------------------------------------------
export const getSuppliers = onCall({ cors: true }, async (request) => {
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
      .collection("suppliers")
      .where("businessId", "==", businessId)
      .where("isActive", "==", true)
      .orderBy("name", "asc")
      .limit(Math.min(pageLimit, 100));

    if (startAfter) {
      const cursor = await db().collection("suppliers").doc(startAfter).get();
      if (cursor.exists) query = query.startAfter(cursor);
    }

    let snap = await query.get();

    let docs = snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      updatedAt: (d.data().updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
    }));

    if (search && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      docs = docs.filter((s: any) =>
        s.name.toLowerCase().includes(q) || s.phoneNumber.includes(q)
      );
    }

    return { suppliers: docs };
  } catch (e) {
    return { suppliers: [] };
  }
});

// -----------------------------------------------------------
// getSupplier
// -----------------------------------------------------------
export const getSupplier = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, supplierId } = request.data as {
    businessId: string;
    supplierId: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db().collection("suppliers").doc(supplierId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Supplier not found.");
  }
  const data = snap.data()!;
  if (data.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Supplier does not belong to your business.");
  }

  return {
    supplier: {
      ...data,
      createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      updatedAt: (data.updatedAt as admin.firestore.Timestamp).toDate().toISOString(),
    },
  };
});

// -----------------------------------------------------------
// updateSupplier
// -----------------------------------------------------------
export const updateSupplier = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, supplierId, name, phoneNumber, email, address, contactPerson, paymentTerms } = request.data as {
    businessId: string;
    supplierId: string;
    name?: string;
    phoneNumber?: string;
    email?: string;
    address?: string;
    contactPerson?: string;
    paymentTerms?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const snap = await db().collection("suppliers").doc(supplierId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Supplier not found.");
  }
  if (snap.data()!.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Supplier does not belong to your business.");
  }

  const updates: Record<string, any> = { updatedAt: admin.firestore.Timestamp.now() };
  if (name !== undefined) updates.name = name.trim();
  if (phoneNumber !== undefined) updates.phoneNumber = phoneNumber.trim();
  if (email !== undefined) updates.email = email.trim();
  if (address !== undefined) updates.address = address.trim();
  if (contactPerson !== undefined) updates.contactPerson = contactPerson.trim();
  if (paymentTerms !== undefined) updates.paymentTerms = paymentTerms.trim();

  await db().collection("suppliers").doc(supplierId).update(updates);

  return { success: true };
});

// -----------------------------------------------------------
// deleteSupplier
// Soft-deletes a supplier by setting isActive to false.
// -----------------------------------------------------------
export const deleteSupplier = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, supplierId } = request.data as {
    businessId: string;
    supplierId: string;
  };

  if (!businessId || !supplierId) {
    throw new HttpsError("invalid-argument", "businessId and supplierId are required.");
  }

  await softDeleteResource({
    businessId,
    resourceId: supplierId,
    collection: "suppliers",
    callerUid: request.auth.uid,
    targetType: "suppliers",
  });

  return { success: true };
});
