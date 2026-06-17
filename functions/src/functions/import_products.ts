// ============================================================
// Import Products — Bulk CSV/XLSX Product Import
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertBusinessMember,
  assertActiveSubscription,
} from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

interface ImportRow {
  sku: string;
  name: string;
  category?: string;
  buyPrice?: number;
  sellPrice?: number;
  quantity?: number;
  reorderLevel?: number;
  unit?: string;
}

interface ImportError {
  row: number;
  field: string;
  message: string;
}

export const importProducts = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, products } = request.data as {
    businessId: string;
    products: ImportRow[];
  };

  if (!businessId) throw new HttpsError("invalid-argument", "businessId required.");
  if (!products || !Array.isArray(products) || products.length === 0) {
    throw new HttpsError("invalid-argument", "No products provided.");
  }
  if (products.length > 5000) {
    throw new HttpsError("invalid-argument", "Maximum 5000 products per import.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const errors: ImportError[] = [];
  const valid: ImportRow[] = [];
  const seenSkus = new Set<string>();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (let i = 0; i < products.length; i++) {
    const row = products[i];
    const rowNum = i + 2;

    if (!row.name || row.name.trim().length === 0) {
      errors.push({ row: rowNum, field: "name", message: "Missing Product Name" });
      continue;
    }

    if (row.sellPrice == null || (row.sellPrice as number) <= 0) {
      errors.push({ row: rowNum, field: "sellPrice", message: "Invalid Sell Price" });
      continue;
    }

    if (row.buyPrice != null && (row.buyPrice as number) < 0) {
      errors.push({ row: rowNum, field: "buyPrice", message: "Buy Price cannot be negative" });
      continue;
    }

    if (row.quantity != null && (row.quantity as number) < 0) {
      errors.push({ row: rowNum, field: "quantity", message: "Quantity cannot be negative" });
      continue;
    }

    if (row.sku && row.sku.trim().length > 0) {
      const normalizedSku = row.sku.trim().toUpperCase();
      if (seenSkus.has(normalizedSku)) {
        errors.push({ row: rowNum, field: "sku", message: "Duplicate SKU within upload" });
        continue;
      }
      seenSkus.add(normalizedSku);

      const dupSnap = await db()
        .collection("products")
        .where("businessId", "==", businessId)
        .where("sku", "==", normalizedSku)
        .limit(1)
        .get();
      if (!dupSnap.empty) {
        errors.push({ row: rowNum, field: "sku", message: `SKU "${normalizedSku}" already exists in inventory` });
        continue;
      }
    }

    valid.push(row);
  }

  let imported = 0;
  if (valid.length > 0) {
    const batch = db().batch();
    let opCount = 0;

    for (const row of valid) {
      const productRef = db().collection("products").doc();

      batch.set(productRef, {
        id: productRef.id,
        businessId,
        name: row.name.trim(),
        sku: row.sku?.trim().toUpperCase() || "",
        category: row.category?.trim() || "General",
        quantity: Math.floor(row.quantity || 0),
        costPrice: Number(row.buyPrice || 0),
        sellingPrice: Number(row.sellPrice),
        reorderLevel: Math.floor(row.reorderLevel || 5),
        createdAt: now,
        updatedAt: now,
      });
      imported++;
      opCount++;

      if (row.quantity && row.quantity > 0) {
        const movRef = db().collection("stockMovements").doc();
        batch.set(movRef, {
          id: movRef.id,
          businessId,
          productId: productRef.id,
          type: "IN",
          quantity: Math.floor(row.quantity),
          reason: "Bulk import",
          referenceId: productRef.id,
          createdAt: now,
        });
        opCount++;
      }

      if (opCount >= 450) {
        await batch.commit();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }

    await db().collection("auditLogs").add({
      businessId,
      action: "BULK_IMPORT",
      entityName: `${imported} products`,
      userId: request.auth.uid,
      userName: request.auth.token.name || "Unknown",
      details: {
        totalImported: imported,
        totalErrors: errors.length,
        totalRows: products.length,
      },
      module: "Inventory",
      timestamp: now,
    });
  }

  return {
    success: errors.length === 0,
    imported,
    errors,
    totalRows: products.length,
    validRows: valid.length,
    invalidRows: errors.length,
  };
});
