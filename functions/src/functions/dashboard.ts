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
