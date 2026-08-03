// ============================================================
// Sales Functions — POS processing with stock validation
// ============================================================

import * as admin from "firebase-admin";
import { rateLimitCheck } from "../middleware/rateLimiter";
import { SECURE_FN_OPTS } from "../config/functionOptions";
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
  serialNumbers?: string[]; // The exact serials being sold
  batchAllocations?: { batchNumber: string; quantity: number }[]; // If manually specified
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
export const createSale = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  await rateLimitCheck(request.rawRequest?.ip || request.auth.uid, "createSale", 60, 1);

  const { businessId, branchId, items, paymentMethod, note, customerId, customerName, pointsRedeemed } = request.data as {
    businessId: string;
    branchId?: string;
    items: SaleItem[];
    paymentMethod: "cash" | "mpesa" | "credit";
    note?: string;
    customerId?: string;
    customerName?: string;
    pointsRedeemed?: number;
    idempotencyKey?: string;
  };

  if (!items || items.length === 0) {
    throw new HttpsError("invalid-argument", "Sale must have at least one item.");
  }

  await assertActiveSubscription(businessId);
  const userData = await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);
  const isManager = userData.role === "owner" || userData.role === "manager";

  // Run everything in a Firestore transaction for atomicity
  const result = await db().runTransaction(async (txn) => {
    // 0. Check idempotency key early
    if (request.data.idempotencyKey) {
      const idempRef = db().collection("idempotency_keys").doc(request.data.idempotencyKey);
      const idempSnap = await txn.get(idempRef);
      if (idempSnap.exists) {
        return idempSnap.data()!.result;
      }
    }

    // Fetch HR Settings for commission basis inside txn
    const hrSettingsRef = db().collection("hr_settings").doc(businessId);
    const hrSettingsSnap = await txn.get(hrSettingsRef);
    const hrSettings = hrSettingsSnap.exists ? hrSettingsSnap.data()! : { commissionBasis: "revenue" };

    // Fetch Tax Settings inside txn
    const taxSettingsRef = db().collection("tax_settings").doc(businessId);
    const taxSettingsSnap = await txn.get(taxSettingsRef);
    const taxSettings = taxSettingsSnap.exists ? taxSettingsSnap.data()! : { eTimsEnabled: false };

    // 1. Read all products
    const productRefs = items.map((item) =>
      db().collection("products").doc(item.productId)
    );
    const productSnaps = await Promise.all(productRefs.map((ref) => txn.get(ref)));

    // Fetch customer if provided
    let customerDoc: FirebaseFirestore.DocumentSnapshot | null = null;
    if (customerId) {
      customerDoc = await txn.get(db().collection("customers").doc(customerId));
      if (!customerDoc.exists) {
        throw new HttpsError("not-found", "Customer not found.");
      }
    }

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
            // BUG-003 FIX: Update local state without reading from txn again to prevent read-after-write errors
            product.quantity += convs[0].childQtyGained;
          }
        }
        if (product.quantity < item.quantity) {
          if (request.data.allowOverride && isManager) {
            // Manager override allowed — proceed with negative stock
          } else {
            const conflictDetail = JSON.stringify({
              conflictType: "stock_exhausted",
              productId: item.productId,
              productName: product.name,
              availableQty: product.quantity,
              requestedQty: item.quantity,
            });
            throw new HttpsError(
              "resource-exhausted",
              `CONFLICT:${conflictDetail}`
            );
          }
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
        serialNumbers: item.serialNumbers,
        batchAllocations: item.batchAllocations,
      });
    }

    const profit = total - totalCost;
    const now = admin.firestore.Timestamp.now();

    let timsCuInvoiceNumber: string | null = null;
    let timsQrCode: string | null = null;

    if (taxSettings.eTimsEnabled) {
      // TODO (BUG-006): Implement actual KRA OSC API integration using vendor credentials.
      throw new HttpsError("unimplemented", "eTIMS integration is not yet implemented. Please disable eTIMS in settings to process sales without KRA compliance, or contact support to configure your middleware provider.");
    }

    // 2. Create sale document
    const saleRef = db().collection("sales").doc();
    const salePayload: any = {
      id: saleRef.id,
      businessId,
      branchId: branchId || null,
      items: validatedItems,
      total: Number(total.toFixed(2)),
      totalCost: Number(totalCost.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      paymentMethod: paymentMethod || "cash",
      note: note || "",
      timsCuInvoiceNumber,
      timsQrCode,
      cashierId: request.auth!.uid,
      cashierName: userData.displayName || "Unknown",
      createdAt: now,
      customerId: customerId || null,
      customerName: customerName || null,
    };

    let pointsEarned = 0;
    if (customerDoc && customerDoc.exists) {
      const custData = customerDoc.data()!;
      if (custData.isFundi) {
        pointsEarned = total / 100;
        const newLoyaltyPoints = (custData.loyaltyPoints || 0) - (pointsRedeemed || 0) + pointsEarned;
        if (newLoyaltyPoints < 0) {
          throw new HttpsError("invalid-argument", "Not enough loyalty points.");
        }
        txn.update(customerDoc.ref, {
          loyaltyPoints: newLoyaltyPoints,
          updatedAt: now,
        });

        Object.assign(salePayload, { pointsEarned, pointsRedeemed: pointsRedeemed || 0 });
      }
    }

    txn.set(saleRef, salePayload);

    // 2.5 Calculate & Accrue Commission
    let commissionEarned = 0;
    if (userData.commissionRate && userData.commissionRate > 0) {
      const basisAmount = hrSettings.commissionBasis === "profit" ? profit : total;
      if (basisAmount > 0) {
        commissionEarned = Number((basisAmount * userData.commissionRate).toFixed(2));
        const userRef = db().collection("users").doc(request.auth!.uid);
        txn.update(userRef, {
          commissionBalance: admin.firestore.FieldValue.increment(commissionEarned),
        });
      }
    }

    // 3. Decrement stock + log movements
    for (let i = 0; i < validatedItems.length; i++) {
      const item = validatedItems[i];

      // Decrement product quantity
      txn.update(productRefs[i], {
        quantity: admin.firestore.FieldValue.increment(-item.quantity),
        updatedAt: now,
      });

      if (item.serialNumbers && item.serialNumbers.length > 0) {
        for (const serial of item.serialNumbers) {
          const serialRef = db().collection("product_serials").doc(`${item.productId}_${serial}`);
          txn.update(serialRef, {
            status: "Sold",
            saleId: saleRef.id,
            updatedAt: now,
          });
        }
      }

      if (item.batchAllocations && item.batchAllocations.length > 0) {
        for (const alloc of item.batchAllocations) {
          const batchRef = db().collection("product_batches").doc(`${item.productId}_${alloc.batchNumber}`);
          txn.update(batchRef, {
            quantityRemaining: admin.firestore.FieldValue.increment(-alloc.quantity),
            updatedAt: now,
          });
          
          // Log movement for this specific batch
          recordInventoryMovement(txn, {
            businessId,
            branchId: branchId || null,
            productId: item.productId,
            productName: item.name,
            movementType: MovementType.SALE,
            quantity: -alloc.quantity,
            costAtTime: item.costPrice,
            referenceId: saleRef.id,
            performedBy: request.auth!.uid,
            batchNumber: alloc.batchNumber,
          });
        }
      } else {
        // Write to Immutable Inventory Ledger (No specific batch)
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
          serialNumbers: item.serialNumbers,
        });
      }
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

    const finalResult = {
      saleId: saleRef.id,
      total: Number(total.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      itemCount: validatedItems.length,
      kraPin: taxSettings.kraPin,
      timsCuInvoiceNumber,
      timsQrCode,
      pointsEarned,
    };

    if (request.data.idempotencyKey) {
      const idempRef = db().collection("idempotency_keys").doc(request.data.idempotencyKey);
      txn.set(idempRef, {
        createdAt: now,
        result: finalResult,
      });
    }

    return finalResult;
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// getSales
// Paginated sales history, ordered by createdAt desc.
// -----------------------------------------------------------
export const getSales = onCall(SECURE_FN_OPTS, async (request) => {
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
