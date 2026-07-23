// ============================================================
// Sales Functions — POS processing with stock validation
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";
import { performAutoConversion } from "./bulk_inventory";
import { postJournalEntryHelper, JournalLine } from "./accounting";
import { recordInventoryMovement, MovementType } from "./inventory_ledger";

const db = () => admin.firestore();

export interface SaleItem {
  productId: string;
  name: string;
  quantity: number;
  sellingPrice: number;
  costPrice: number;
  overridePrice?: number;
  note?: string;
  isPriceOverridden?: boolean;
  overriddenBy?: string | null;
}

// -----------------------------------------------------------
// createSale
// Full POS transaction:
//  1. Validate all items have sufficient stock
//  2. Calculate total + profit
//  3. Write sale document
//  4. Decrement stock for each item (transaction)
//  5. Log stock movement per item
// All steps atomic via Firestore transaction.
// -----------------------------------------------------------
export const createSale = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, branchId, items, paymentMethod, note } = request.data as {
    businessId: string;
    branchId?: string;
    items: SaleItem[];
    paymentMethod: "cash" | "mpesa" | "credit";
    note?: string;
  };

  if (!items || items.length === 0) {
    throw new HttpsError("invalid-argument", "Sale must have at least one item.");
  }

  await assertActiveSubscription(businessId);
  const userData = await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);
  const isManager = userData.role === "owner" || userData.role === "manager";

  // Run everything in a Firestore transaction for atomicity
  const result = await db().runTransaction(async (txn) => {
    // 1. Read all products
    const productRefs = items.map((item) =>
      db().collection("products").doc(item.productId)
    );
    const productSnaps = await Promise.all(productRefs.map((ref) => txn.get(ref)));

    let total = 0;
    let totalCost = 0;
    const validatedItems: SaleItem[] = [];

    for (let i = 0; i < items.length; i++) {
      const snap = productSnaps[i];
      const item = items[i];

      if (!snap.exists) {
        throw new HttpsError("not-found", `Product ${item.productId} not found.`);
      }

      const product = snap.data()!;

      if (product.businessId !== businessId) {
        throw new HttpsError("permission-denied", "Product does not belong to your business.");
      }

      if (product.quantity < item.quantity) {
        // Auto-convert from parent if this is a bulk child
        if (product.isBulkChild && product.parentProductId && product.conversionRatio) {
          const convs = await performAutoConversion(txn, businessId, [
            { productId: item.productId, quantity: item.quantity },
          ]);
          if (convs.length > 0) {
            const updatedSnap = await txn.get(productRefs[i]);
            const updated = updatedSnap.data()!;
            product.quantity = updated.quantity;
            product.costPrice = updated.costPrice;
            product.sellingPrice = updated.sellingPrice;
          }
        }
        if (product.quantity < item.quantity) {
          throw new HttpsError(
            "resource-exhausted",
            `Insufficient stock for "${product.name}". Available: ${product.quantity}, Requested: ${item.quantity}.`
          );
        }
      }

      // Check for price overrides
      const hasOverride = item.overridePrice !== undefined && item.overridePrice !== product.sellingPrice;
      if (hasOverride && !isManager) {
        throw new HttpsError("permission-denied", `Only managers can override prices. (Attempted on "${product.name}")`);
      }
      const appliedPrice = hasOverride ? item.overridePrice : product.sellingPrice;

      const lineTotal = appliedPrice * item.quantity;
      const lineCost = product.costPrice * item.quantity;

      total += lineTotal;
      totalCost += lineCost;

      validatedItems.push({
        productId: item.productId,
        name: product.name,
        quantity: item.quantity,
        sellingPrice: appliedPrice,
        costPrice: product.costPrice,
        isPriceOverridden: hasOverride,
        overriddenBy: hasOverride ? request.auth!.uid : null,
        note: item.note || "",
      });
    }

    const profit = total - totalCost;
    const now = admin.firestore.Timestamp.now();

    // 2. Create sale document
    const saleRef = db().collection("sales").doc();
    txn.set(saleRef, {
      id: saleRef.id,
      businessId,
      branchId: branchId || null,
      items: validatedItems,
      total: Number(total.toFixed(2)),
      totalCost: Number(totalCost.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      paymentMethod: paymentMethod || "cash",
      note: note || "",
      createdBy: request.auth!.uid,
      createdAt: now,
    });

    // 3. Decrement stock + log movements
    for (let i = 0; i < validatedItems.length; i++) {
      const item = validatedItems[i];

      // Decrement product quantity
      txn.update(productRefs[i], {
        quantity: admin.firestore.FieldValue.increment(-item.quantity),
        updatedAt: now,
      });

      // Write to Immutable Inventory Ledger
      recordInventoryMovement(txn, {
        businessId,
        branchId: branchId || null,
        productId: item.productId,
        productName: item.name,
        movementType: MovementType.SALE,
        quantity: -item.quantity, // Outgoing
        costAtTime: item.costPrice,
        referenceId: saleRef.id,
        performedBy: request.auth!.uid,
      });
    }

    // 4. Double-Entry Accounting Integration
    const accountsSnap = await txn.get(db().collection("chart_of_accounts").where("businessId", "==", businessId));
    if (!accountsSnap.empty) {
      const accounts = accountsSnap.docs.map(d => d.data());
      const getAcc = (name: string) => accounts.find(a => a.name === name)?.id;
      
      const cashAcc = getAcc("Cash in Hand");
      const mpesaAcc = getAcc("M-Pesa Account");
      const arAcc = getAcc("Accounts Receivable");
      const salesAcc = getAcc("Sales Revenue");
      const cogsAcc = getAcc("Cost of Goods Sold (COGS)");
      const invAcc = getAcc("Inventory");

      if (cashAcc && salesAcc && cogsAcc && invAcc && mpesaAcc && arAcc) {
        let assetAcc = cashAcc;
        if (paymentMethod === "mpesa") assetAcc = mpesaAcc;
        if (paymentMethod === "credit") assetAcc = arAcc;

        const lines: JournalLine[] = [
          { accountId: assetAcc, debit: total, credit: 0 },
          { accountId: salesAcc, debit: 0, credit: total }
        ];

        if (totalCost > 0) {
          lines.push({ accountId: cogsAcc, debit: totalCost, credit: 0 });
          lines.push({ accountId: invAcc, debit: 0, credit: totalCost });
        }

        postJournalEntryHelper(txn, businessId, saleRef.id, `Sale ${paymentMethod}`, lines, now);
      }
    }

    return {
      saleId: saleRef.id,
      total: Number(total.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      itemCount: validatedItems.length,
    };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getSales
// Paginated sales history, ordered by createdAt desc.
// -----------------------------------------------------------
export const getSales = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, limit: pageLimit = 30, startAfter } = request.data as {
    businessId: string;
    limit?: number;
    startAfter?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query: admin.firestore.Query = db()
    .collection("sales")
    .where("businessId", "==", businessId)
    .orderBy("createdAt", "desc")
    .limit(Math.min(pageLimit, 100));

  if (startAfter) {
    const cursor = await db().collection("sales").doc(startAfter).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }

  const snap = await query.get();
  // Wrap in object so Flutter's FunctionsService (Map cast) does not throw.
  return {
    sales: snap.docs.map((d) => ({
      ...d.data(),
      createdAt: (d.data().createdAt as admin.firestore.Timestamp).toDate().toISOString(),
    })),
  };
});
