// ============================================================
// Dashboard Functions — Aggregated KPI stats
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, getBusinessData } from "../middleware/checkPlanLimits";
import { getEffectivePlan, Plan, SubscriptionStatus } from "../config/planLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// getDashboardStats
// Returns today's KPIs + low stock + subscription info.
// -----------------------------------------------------------
export const getDashboardStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId);

  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfDayTs = admin.firestore.Timestamp.fromDate(startOfDay);

  // Parallel queries for performance
  const [salesSnap, expensesSnap, productsSnap, bizData] = await Promise.all([
    db()
      .collection("sales")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", startOfDayTs)
      .get(),
    db()
      .collection("expenses")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", startOfDayTs)
      .get(),
    db()
      .collection("products")
      .where("businessId", "==", businessId)
      .orderBy("quantity")
      .limit(50)
      .get(),
    getBusinessData(businessId),
  ]);

  // Aggregate sales
  let todayRevenue = 0;
  let todayProfit = 0;
  let todaySalesCount = 0;
  const recentSales: unknown[] = [];

  salesSnap.docs.forEach((doc, idx) => {
    const data = doc.data();
    todayRevenue += data.total || 0;
    todayProfit += data.profit || 0;
    todaySalesCount++;
    if (idx < 5) {
      recentSales.push({
        id: data.id,
        total: data.total,
        profit: data.profit,
        itemCount: (data.items || []).length,
        paymentMethod: data.paymentMethod,
        createdAt: (data.createdAt as admin.firestore.Timestamp).toDate().toISOString(),
      });
    }
  });

  // Aggregate expenses
  let todayExpenses = 0;
  expensesSnap.docs.forEach((doc) => {
    todayExpenses += doc.data().amount || 0;
  });

  // Low stock items
  const lowStock = productsSnap.docs
    .map((d) => d.data())
    .filter((p) => p.quantity <= p.reorderLevel)
    .slice(0, 10)
    .map((p) => ({
      id: p.id,
      name: p.name,
      quantity: p.quantity,
      reorderLevel: p.reorderLevel,
      category: p.category,
    }));

  // Subscription info
  const trialEndsAt = bizData.trialEndsAt ? bizData.trialEndsAt.toDate() : null;
  const { config: planConfig, isExpired } = getEffectivePlan(
    bizData.plan as Plan,
    bizData.subscriptionStatus as SubscriptionStatus,
    trialEndsAt
  );

  let trialDaysLeft: number | null = null;
  if (bizData.subscriptionStatus === "trial" && trialEndsAt) {
    trialDaysLeft = Math.max(
      0,
      Math.ceil((trialEndsAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
    );
  }

  return {
    kpis: {
      todayRevenue: Number(todayRevenue.toFixed(2)),
      todayProfit: Number(todayProfit.toFixed(2)),
      todayExpenses: Number(todayExpenses.toFixed(2)),
      todaySalesCount,
      netProfit: Number((todayProfit - todayExpenses).toFixed(2)),
    },
    lowStock,
    recentSales,
    subscription: {
      plan: bizData.plan,
      status: bizData.subscriptionStatus,
      isExpired,
      trialDaysLeft,
      trialEndsAt: trialEndsAt?.toISOString() || null,
      planConfig,
    },
  };
});

// -----------------------------------------------------------
// getReportStats
// Returns aggregated stats for a period ('today'|'week'|'month').
// -----------------------------------------------------------
export const getReportStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, period } = request.data as {
    businessId: string;
    period: 'today' | 'week' | 'month';
  };

  await assertBusinessMember(request.auth.uid, businessId);

  const now = new Date();
  const fromDate = new Date();
  if (period === 'today') {
    fromDate.setHours(0, 0, 0, 0);
  } else if (period === 'week') {
    fromDate.setDate(now.getDate() - 7);
  } else {
    fromDate.setMonth(now.getMonth() - 1);
  }

  const from = admin.firestore.Timestamp.fromDate(fromDate);

  const [salesSnap, expensesSnap] = await Promise.all([
    db().collection("sales").where("businessId", "==", businessId).where("createdAt", ">=", from).get(),
    db().collection("expenses").where("businessId", "==", businessId).where("createdAt", ">=", from).get(),
  ]);

  let totalRevenue = 0, totalCOGS = 0, totalSales = 0;
  let cashTotal = 0, mpesaTotal = 0, creditTotal = 0;
  const productMap: Record<string, { qty: number; revenue: number }> = {};

  salesSnap.docs.forEach((doc) => {
    const data = doc.data();
    totalRevenue += data.total || 0;
    totalCOGS    += data.totalCost || 0;  // createSale stores COGS as totalCost
    totalSales++;
    if (data.paymentMethod === 'cash')   cashTotal   += data.total || 0;
    else if (data.paymentMethod === 'mpesa')  mpesaTotal  += data.total || 0;
    else if (data.paymentMethod === 'credit') creditTotal += data.total || 0;

    (data.items || []).forEach((item: { name: string; quantity: number; sellingPrice: number }) => {
      if (!productMap[item.name]) productMap[item.name] = { qty: 0, revenue: 0 };
      productMap[item.name].qty     += item.quantity;
      productMap[item.name].revenue += (item.sellingPrice || 0) * item.quantity;
    });
  });

  let totalExpenses = 0;
  const expenseByCategory: Record<string, number> = {};
  expensesSnap.docs.forEach((doc) => {
    const data = doc.data();
    totalExpenses += data.amount || 0;
    const cat = data.category || "Other";
    expenseByCategory[cat] = (expenseByCategory[cat] || 0) + (data.amount || 0);
  });

  return {
    totalRevenue,
    totalCOGS,
    totalExpenses,
    netProfit: totalRevenue - totalCOGS - totalExpenses,
    totalSales,
    cashTotal,
    mpesaTotal,
    creditTotal,
    topProducts: Object.entries(productMap)
      .map(([name, v]) => ({ name, qty: v.qty, revenue: Number(v.revenue.toFixed(2)) }))
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 5),
    expenseByCategory,
  };
});

// -----------------------------------------------------------
// seedDemoData
// Seeds realistic products, sales, and expenses.
// Admin-only function.
// -----------------------------------------------------------

export const seedDemoData = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const adminSnap = await db().collection("platformAdmins").doc(request.auth.uid).get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Only platform administrators can seed demo data.");
  }

  let businessId = (request.data as { businessId?: string }).businessId;
  if (!businessId) {
    const snap = await db().collection("businesses").limit(1).get();
    if (snap.empty) {
      throw new HttpsError("not-found", "No businesses found.");
    }
    businessId = snap.docs[0].id;
  }
    const batchArray: Promise<any>[] = [];
    let currentBatch = db().batch();
    let operationCounter = 0;

    function commitBatchOp() {
      operationCounter++;
      if (operationCounter === 500) {
        batchArray.push(currentBatch.commit());
        currentBatch = db().batch();
        operationCounter = 0;
      }
    }

    const categories = ["Cement", "Pipes & Plumbing", "Paint", "Hardware & Tools", "Steel & Metals", "Timber"];
    const productBases: Record<string, string[]> = {
      "Cement": ["Bamburi Cement 50kg", "Blue Triangle Cement 50kg", "Rhino Cement 50kg", "Simba Cement 50kg"],
      "Pipes & Plumbing": ["PVC Pipe 1 inch", "PVC Pipe 2 inch", "PPR Pipe 3/4 inch", "Gate Valve 1 inch", "Elbow Joint", "Tee Joint"],
      "Paint": ["Crown Silk Vinyl 4L", "Crown Silk Vinyl 20L", "Duracoat Emulsion 4L", "Basco Gloss 1L", "Paint Brush 2 inch", "Paint Roller"],
      "Hardware & Tools": ["Roofing Nails 1kg", "Steel Nails 2kg", "Claw Hammer", "Measuring Tape 5m", "Hacksaw", "Wheelbarrow"],
      "Steel & Metals": ["D10 Steel Bar", "D12 Steel Bar", "Y16 Steel Bar", "Binding Wire 1 roll", "Iron Sheet 3m"],
      "Timber": ["Timber 2x2", "Timber 2x4", "Timber 1x8", "MDF Board", "Plywood"]
    };

    function randomInt(min: number, max: number) {
      return Math.floor(Math.random() * (max - min + 1)) + min;
    }
    function randomElement(arr: any[]) {
      return arr[Math.floor(Math.random() * arr.length)];
    }

    const generatedProducts: any[] = [];
    for (let i = 0; i < 250; i++) {
      const category = randomElement(categories);
      const nameBase = randomElement(productBases[category]);
      const name = `${nameBase} (Variant ${i + 1})`;
      
      const buyingPrice = randomInt(100, 3000);
      const sellingPrice = buyingPrice + randomInt(50, 500);
      const quantity = randomInt(10, 500);
      const docRef = db().collection("products").doc();
      const product = {
        id: docRef.id,
        businessId,
        name,
        category,
        sku: `SKU-${1000 + i}`,
        buyingPrice,
        sellingPrice,
        quantity,
        reorderLevel: randomInt(5, 20),
        supplierId: "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      currentBatch.set(docRef, product);
      generatedProducts.push(product);
      commitBatchOp();
    }

    const paymentMethods = ["cash", "mpesa", "card", "credit"];
    const now = new Date();
    
    for (let i = 0; i < 300; i++) {
      const saleDate = new Date(now.getTime() - randomInt(0, 30) * 24 * 60 * 60 * 1000 - randomInt(0, 24) * 60 * 60 * 1000);
      const itemCount = randomInt(1, 5);
      const items: any[] = [];
      let total = 0;
      let profit = 0;
      
      for (let j = 0; j < itemCount; j++) {
        const prod = randomElement(generatedProducts);
        const qty = randomInt(1, 10);
        items.push({
          productId: prod.id,
          name: prod.name,
          quantity: qty,
          sellingPrice: prod.sellingPrice,
          subtotal: prod.sellingPrice * qty
        });
        total += prod.sellingPrice * qty;
        profit += (prod.sellingPrice - prod.buyingPrice) * qty;
      }

      const docRef = db().collection("sales").doc();
      currentBatch.set(docRef, {
        id: docRef.id,
        businessId,
        receiptNumber: `REC-${10000 + i}`,
        items,
        total,
        profit,
        totalCost: total - profit,
        paymentMethod: randomElement(paymentMethods),
        status: "completed",
        customerId: "",
        soldBy: "Seeding Script",
        createdAt: admin.firestore.Timestamp.fromDate(saleDate)
      });
      commitBatchOp();
    }

    const expenseCategories = ["Transport", "Meals", "Utilities", "Salaries", "Rent", "Maintenance"];
    for (let i = 0; i < 100; i++) {
      const expDate = new Date(now.getTime() - randomInt(0, 30) * 24 * 60 * 60 * 1000);
      const category = randomElement(expenseCategories);
      const docRef = db().collection("expenses").doc();
      currentBatch.set(docRef, {
        id: docRef.id,
        businessId,
        amount: randomInt(500, 15000),
        category,
        description: `Payment for ${category} - Seeded Data`,
        recordedBy: "Seeding Script",
        receiptUrl: null,
        createdAt: admin.firestore.Timestamp.fromDate(expDate)
      });
      commitBatchOp();
    }

    if (operationCounter > 0) {
      batchArray.push(currentBatch.commit());
    }

    await Promise.all(batchArray);
    return { success: true, message: "Seed complete! Inserted ~250 products, ~300 sales, ~100 expenses." };
});
