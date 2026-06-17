// ============================================================
// Broken-Bulk Inventory — Support selling in smaller units
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

interface BulkConfig {
  isBulkParent?: boolean;
  isBulkChild?: boolean;
  parentProductId?: string;
  conversionRatio?: number;
  baseUnit?: string;
  sellingUnit?: string;
}

export interface ConversionResult {
  productId: string;
  name: string;
  parentId: string;
  parentName: string;
  childQtyGained: number;
  parentQtyUsed: number;
}

// -----------------------------------------------------------
// performAutoConversion — shared internal helper
// Called within an existing Firestore transaction.
// -----------------------------------------------------------
export async function performAutoConversion(
  txn: admin.firestore.Transaction,
  businessId: string,
  items: { productId: string; quantity: number }[]
): Promise<ConversionResult[]> {
  const conversions: ConversionResult[] = [];

  for (const item of items) {
    const childSnap = await txn.get(db().collection("products").doc(item.productId));
    if (!childSnap.exists) continue;

    const child = childSnap.data()!;
    if (child.businessId !== businessId) continue;
    if (!child.isBulkChild || !child.parentProductId || !child.conversionRatio) continue;

    if (child.quantity >= item.quantity) continue;

    const deficit = item.quantity - child.quantity;
    const parentQtyNeeded = Math.ceil(deficit / child.conversionRatio);
    const childQtyFromOneParent = child.conversionRatio;

    const parentSnap = await txn.get(db().collection("products").doc(child.parentProductId));
    if (!parentSnap.exists) continue;

    const parent = parentSnap.data()!;
    if (parent.quantity < parentQtyNeeded) continue;

    txn.update(db().collection("products").doc(child.parentProductId), {
      quantity: admin.firestore.FieldValue.increment(-parentQtyNeeded),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    txn.update(db().collection("products").doc(item.productId), {
      quantity: admin.firestore.FieldValue.increment(parentQtyNeeded * childQtyFromOneParent),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    conversions.push({
      productId: item.productId,
      name: child.name,
      parentId: child.parentProductId,
      parentName: parent.name,
      childQtyGained: parentQtyNeeded * childQtyFromOneParent,
      parentQtyUsed: parentQtyNeeded,
    });
  }

  return conversions;
}

// -----------------------------------------------------------
// bulkCreateProduct
// -----------------------------------------------------------
export const bulkCreateProduct = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const {
    businessId, name, sku, category, quantity, costPrice, sellingPrice, reorderLevel,
    isBulkParent, isBulkChild, parentProductId, conversionRatio, baseUnit, sellingUnit,
  } = request.data as Record<string, unknown> & BulkConfig & {
    businessId: string; name: string; sku: string; category: string;
    quantity: number; costPrice: number; sellingPrice: number; reorderLevel: number;
  };

  if (!name || !businessId) throw new HttpsError("invalid-argument", "name and businessId required.");
  if (sellingPrice <= 0 || costPrice < 0) throw new HttpsError("invalid-argument", "Invalid prices.");

  if (isBulkChild && (!parentProductId || !conversionRatio || conversionRatio <= 0)) {
    throw new HttpsError("invalid-argument", "Bulk child requires parentProductId and conversionRatio > 0.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  if (isBulkChild && parentProductId) {
    const parentSnap = await db().collection("products").doc(parentProductId).get();
    if (!parentSnap.exists) {
      throw new HttpsError("not-found", "Parent product not found.");
    }
    if (parentSnap.data()!.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Parent product does not belong to your business.");
    }
  }

  const productRef = db().collection("products").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db().batch();
  batch.set(productRef, {
    id: productRef.id,
    businessId,
    name: name.trim(),
    sku: sku?.trim() || "",
    category: category?.trim() || "General",
    quantity: Math.floor(quantity) || 0,
    costPrice: Number(costPrice),
    sellingPrice: Number(sellingPrice),
    reorderLevel: Math.floor(reorderLevel) || 5,
    isBulkParent: isBulkParent || false,
    isBulkChild: isBulkChild || false,
    parentProductId: parentProductId || null,
    conversionRatio: conversionRatio || null,
    baseUnit: baseUnit?.trim() || null,
    sellingUnit: sellingUnit?.trim() || null,
    createdAt: now,
    updatedAt: now,
  });

  const userSnap = await db().collection("users").doc(request.auth!.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";
  const auditRef = db().collection("auditLogs").doc();
  batch.set(auditRef, {
    id: auditRef.id,
    businessId,
    userId: request.auth!.uid,
    userName,
    module: "Inventory",
    action: "Create Product",
    entityId: productRef.id,
    entityName: name.trim(),
    oldValues: {},
    newValues: { isBulkParent, isBulkChild, conversionRatio },
    metadata: { bulkConfig: { isBulkParent, isBulkChild, parentProductId, conversionRatio } },
    createdAt: now,
  });

  await batch.commit();
  return { success: true, productId: productRef.id };
});

// -----------------------------------------------------------
// autoConvertDuringSale — callable wrapper
// -----------------------------------------------------------
export const autoConvertDuringSale = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, items } = request.data as {
    businessId: string;
    items: { productId: string; quantity: number }[];
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);
  await assertActiveSubscription(businessId);

  const result = await db().runTransaction(async (txn) => {
    const conversions = await performAutoConversion(txn, businessId, items);
    return { conversions };
  });

  return { success: true, conversions: result.conversions };
});

// -----------------------------------------------------------
// validateConversion — check if conversion is possible for an item
// -----------------------------------------------------------
export const validateConversion = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, productId, quantity } = request.data as {
    businessId: string;
    productId: string;
    quantity: number;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);

  const productSnap = await db().collection("products").doc(productId).get();
  if (!productSnap.exists) throw new HttpsError("not-found", "Product not found.");

  const product = productSnap.data()!;
  if (product.businessId !== businessId) throw new HttpsError("permission-denied", "Access denied.");

  if (!product.isBulkChild || !product.parentProductId || !product.conversionRatio) {
    return { canConvert: false, reason: "Product is not a bulk child." };
  }

  const deficit = quantity - (product.quantity || 0);
  if (deficit <= 0) {
    return { canConvert: false, reason: "Sufficient stock already available." };
  }

  const parentQtyNeeded = Math.ceil(deficit / product.conversionRatio);
  const parentSnap = await db().collection("products").doc(product.parentProductId).get();
  if (!parentSnap.exists) {
    return { canConvert: false, reason: "Parent product not found." };
  }

  const parent = parentSnap.data()!;
  if (parent.quantity < parentQtyNeeded) {
    return {
      canConvert: false,
      reason: `Not enough parent stock. Need ${parentQtyNeeded} ${parent.name || "parent"} units, have ${parent.quantity}.`,
    };
  }

  return {
    canConvert: true,
    deficit,
    parentQtyNeeded,
    childQtyGained: parentQtyNeeded * product.conversionRatio,
    parentAvailable: parent.quantity,
    parentName: parent.name,
  };
});

// -----------------------------------------------------------
// convertParentToChild — manual conversion triggered by user
// -----------------------------------------------------------
export const convertParentToChild = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, productId, quantity } = request.data as {
    businessId: string;
    productId: string;
    quantity: number;
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const result = await db().runTransaction(async (txn) => {
    const conversions = await performAutoConversion(txn, businessId, [
      { productId, quantity },
    ]);
    if (conversions.length === 0) {
      throw new HttpsError("failed-precondition", "Conversion not possible. Check stock or product configuration.");
    }
    return { conversion: conversions[0] };
  });

  // Audit log
  const userSnap = await db().collection("users").doc(request.auth!.uid).get();
  const userName = (userSnap.data()?.displayName as string) || (userSnap.data()?.name as string) || "Unknown";
  await db().collection("auditLogs").add({
    businessId,
    userId: request.auth!.uid,
    userName,
    module: "Inventory",
    action: "Bulk Conversion",
    entityId: productId,
    entityName: result.conversion.name,
    oldValues: {},
    newValues: {
      parentProductId: result.conversion.parentId,
      parentQtyUsed: result.conversion.parentQtyUsed,
      childQtyGained: result.conversion.childQtyGained,
    },
    metadata: { conversion: result.conversion },
    createdAt: admin.firestore.Timestamp.now(),
  });

  return { success: true, conversion: result.conversion };
});
