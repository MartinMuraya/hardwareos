import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

// -----------------------------------------------------------
// getPublicStorefront
// Resolves a slug to a business and returns basic storefront info
// -----------------------------------------------------------
export const getPublicStorefront = onCall({ cors: true }, async (request) => {
  const { tenantSlug } = request.data as { tenantSlug: string };
  if (!tenantSlug) throw new HttpsError("invalid-argument", "tenantSlug is required.");

  const snap = await db().collection("businesses").where("tenantSlug", "==", tenantSlug).limit(1).get();
  if (snap.empty) throw new HttpsError("not-found", "Storefront not found.");

  const biz = snap.docs[0].data();
  // Don't expose sensitive info like ownerId or subscription details
  return {
    businessId: biz.id,
    name: biz.name,
    tenantSlug: biz.tenantSlug,
    active: biz.active,
  };
});

// -----------------------------------------------------------
// getPublicProducts
// Retrieves products for a business where isPublishedOnline is true
// -----------------------------------------------------------
export const getPublicProducts = onCall({ cors: true }, async (request) => {
  const { businessId, category } = request.data as { businessId: string, category?: string };
  if (!businessId) throw new HttpsError("invalid-argument", "businessId is required.");

  let query = db().collection("products")
    .where("businessId", "==", businessId)
    .where("isPublishedOnline", "==", true)
    .limit(100);

  if (category && category !== "All") {
    query = query.where("category", "==", category);
  }

  const snap = await query.get();
  return { products: snap.docs.map(d => {
    const p = d.data();
    // Expose only public fields
    return {
      id: p.id,
      name: p.name,
      category: p.category,
      sellingPrice: p.sellingPrice,
      images: p.images || [],
      description: p.description || "",
      // Do not expose exact quantity publicly, just in-stock status
      inStock: p.quantity > 0
    };
  })};
});

// -----------------------------------------------------------
// getStorefrontCategories
// Retrieves unique categories for published products
// -----------------------------------------------------------
export const getStorefrontCategories = onCall({ cors: true }, async (request) => {
  const { businessId } = request.data as { businessId: string };
  if (!businessId) throw new HttpsError("invalid-argument", "businessId is required.");

  const snap = await db().collection("products")
    .where("businessId", "==", businessId)
    .where("isPublishedOnline", "==", true)
    .get();

  const categories = new Set<string>();
  snap.docs.forEach(doc => {
    if (doc.data().category) categories.add(doc.data().category);
  });

  return { categories: Array.from(categories) };
});

// -----------------------------------------------------------
// createOnlineOrder
// Submits a shopping cart to create a pending online order.
// Temporarily decrements stock (Hold) until approved by the merchant.
// -----------------------------------------------------------
export const createOnlineOrder = onCall({ cors: true }, async (request) => {
  const { businessId, items, customerName, customerPhone, address, note } = request.data as {
    businessId: string;
    items: Array<{ productId: string; quantity: number }>;
    customerName: string;
    customerPhone: string;
    address: string;
    note?: string;
  };

  if (!businessId || !items || items.length === 0 || !customerName || !customerPhone) {
    throw new HttpsError("invalid-argument", "Missing required order details.");
  }

  const result = await db().runTransaction(async (txn) => {
    const productRefs = items.map(item => db().collection("products").doc(item.productId));
    const productSnaps = await Promise.all(productRefs.map(ref => txn.get(ref)));

    let total = 0;
    const validatedItems = [];

    for (let i = 0; i < items.length; i++) {
      const snap = productSnaps[i];
      const item = items[i];

      if (!snap.exists) throw new HttpsError("not-found", `Product ${item.productId} not found.`);
      const product = snap.data()!;
      
      if (product.businessId !== businessId || !product.isPublishedOnline) {
        throw new HttpsError("permission-denied", "Product is not available for online ordering.");
      }

      if (product.quantity < item.quantity) {
        throw new HttpsError("resource-exhausted", `Insufficient stock for "${product.name}".`);
      }

      const lineTotal = product.sellingPrice * item.quantity;
      total += lineTotal;

      validatedItems.push({
        productId: item.productId,
        name: product.name,
        quantity: item.quantity,
        sellingPrice: product.sellingPrice,
        costPrice: product.costPrice,
      });
    }

    const orderRef = db().collection("online_orders").doc();
    const now = admin.firestore.Timestamp.now();

    txn.set(orderRef, {
      id: orderRef.id,
      businessId,
      items: validatedItems,
      total: Number(total.toFixed(2)),
      customerName,
      customerPhone,
      address,
      note: note || "",
      status: "pending", // pending -> approved -> completed
      createdAt: now,
    });

    // Decrement stock (Hold)
    for (let i = 0; i < validatedItems.length; i++) {
      txn.update(productRefs[i], {
        quantity: admin.firestore.FieldValue.increment(-validatedItems[i].quantity),
        updatedAt: now,
      });

      const movRef = db().collection("stockMovements").doc();
      txn.set(movRef, {
        id: movRef.id,
        businessId,
        productId: validatedItems[i].productId,
        type: "OUT",
        quantity: validatedItems[i].quantity,
        reason: "Online Order Hold",
        referenceId: orderRef.id,
        createdAt: now,
      });
    }

    return { orderId: orderRef.id, total };
  });

  return { success: true, ...result };
});

// -----------------------------------------------------------
// approveOnlineOrder
// Approves an online order, creates a sale document.
// Stock was already decremented during createOnlineOrder (Stock Hold).
// -----------------------------------------------------------
export const approveOnlineOrder = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, orderId } = request.data as { businessId: string; orderId: string };
  if (!businessId || !orderId) throw new HttpsError("invalid-argument", "Missing required arguments.");

  // Should verify business member role (e.g. manager) but simple check for now:
  const userRef = await db().collection("users").doc(request.auth.uid).get();
  if (!userRef.exists || userRef.data()!.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Unauthorized access.");
  }

  await db().runTransaction(async (txn) => {
    const orderRef = db().collection("online_orders").doc(orderId);
    const orderSnap = await txn.get(orderRef);
    if (!orderSnap.exists) throw new HttpsError("not-found", "Order not found.");
    
    const order = orderSnap.data()!;
    if (order.status !== "pending") throw new HttpsError("failed-precondition", "Order is not pending.");

    // Create Sale Document
    const saleRef = db().collection("sales").doc();
    const now = admin.firestore.Timestamp.now();
    
    let totalCost = 0;
    for (const item of order.items) {
      totalCost += (item.costPrice || 0) * item.quantity;
    }
    
    const profit = order.total - totalCost;

    txn.set(saleRef, {
      id: saleRef.id,
      businessId: order.businessId,
      branchId: null,
      items: order.items,
      total: order.total,
      profit: profit,
      paymentMethod: "online",
      soldBy: request.auth?.uid,
      note: `Online Order #${orderId.substring(0,6).toUpperCase()} - ${order.customerName}`,
      createdAt: now,
    });

    // Update order status
    txn.update(orderRef, { status: "approved", saleId: saleRef.id, updatedAt: now });
  });

  return { success: true };
});

// -----------------------------------------------------------
// rejectOnlineOrder
// Rejects an online order and restores the Stock Hold.
// -----------------------------------------------------------
export const rejectOnlineOrder = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, orderId } = request.data as { businessId: string; orderId: string };
  
  const userRef = await db().collection("users").doc(request.auth.uid).get();
  if (!userRef.exists || userRef.data()!.businessId !== businessId) {
    throw new HttpsError("permission-denied", "Unauthorized access.");
  }

  await db().runTransaction(async (txn) => {
    const orderRef = db().collection("online_orders").doc(orderId);
    const orderSnap = await txn.get(orderRef);
    if (!orderSnap.exists) throw new HttpsError("not-found", "Order not found.");
    
    const order = orderSnap.data()!;
    if (order.status !== "pending") throw new HttpsError("failed-precondition", "Order is not pending.");

    const now = admin.firestore.Timestamp.now();

    // Restore stock
    for (const item of order.items) {
      const productRef = db().collection("products").doc(item.productId);
      txn.update(productRef, {
        quantity: admin.firestore.FieldValue.increment(item.quantity),
        updatedAt: now,
      });

      const movRef = db().collection("stockMovements").doc();
      txn.set(movRef, {
        id: movRef.id,
        businessId: order.businessId,
        productId: item.productId,
        type: "IN",
        quantity: item.quantity,
        reason: "Online Order Rejected (Stock Restore)",
        referenceId: orderId,
        createdAt: now,
      });
    }

    // Update order status
    txn.update(orderRef, { status: "rejected", updatedAt: now });
  });

  return { success: true };
});
