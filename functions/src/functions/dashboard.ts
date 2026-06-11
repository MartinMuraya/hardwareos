// ============================================================
// Dashboard Functions — Aggregated KPI stats
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, getBusinessData, getEffectivePlan } from "../middleware/checkPlanLimits";
import { Plan, SubscriptionStatus } from "../config/planLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// getDashboardStats
// Returns today's KPIs + low stock + subscription info.
// -----------------------------------------------------------
export const getDashboardStats = onCall(async (request) => {
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
// Returns aggregated stats for a date range (daily/weekly/monthly).
// -----------------------------------------------------------
export const getReportStats = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, fromDate, toDate } = request.data as {
    businessId: string;
    fromDate: string;
    toDate: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  const from = admin.firestore.Timestamp.fromDate(new Date(fromDate));
  const to = admin.firestore.Timestamp.fromDate(new Date(toDate));

  const [salesSnap, expensesSnap] = await Promise.all([
    db()
      .collection("sales")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", from)
      .where("createdAt", "<=", to)
      .orderBy("createdAt", "asc")
      .get(),
    db()
      .collection("expenses")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", from)
      .where("createdAt", "<=", to)
      .get(),
  ]);

  // Group sales by date
  const salesByDay: Record<string, { revenue: number; profit: number; count: number }> = {};

  salesSnap.docs.forEach((doc) => {
    const data = doc.data();
    const date = (data.createdAt as admin.firestore.Timestamp)
      .toDate()
      .toISOString()
      .substring(0, 10);
    if (!salesByDay[date]) salesByDay[date] = { revenue: 0, profit: 0, count: 0 };
    salesByDay[date].revenue += data.total || 0;
    salesByDay[date].profit += data.profit || 0;
    salesByDay[date].count++;
  });

  let totalRevenue = 0;
  let totalProfit = 0;
  let totalExpenses = 0;

  salesSnap.docs.forEach((d) => {
    totalRevenue += d.data().total || 0;
    totalProfit += d.data().profit || 0;
  });
  expensesSnap.docs.forEach((d) => { totalExpenses += d.data().amount || 0; });

  // Group expenses by category
  const expensesByCategory: Record<string, number> = {};
  expensesSnap.docs.forEach((doc) => {
    const data = doc.data();
    const cat = data.category || "Other";
    expensesByCategory[cat] = (expensesByCategory[cat] || 0) + (data.amount || 0);
  });

  return {
    totals: {
      revenue: Number(totalRevenue.toFixed(2)),
      profit: Number(totalProfit.toFixed(2)),
      expenses: Number(totalExpenses.toFixed(2)),
      netProfit: Number((totalProfit - totalExpenses).toFixed(2)),
      salesCount: salesSnap.size,
    },
    salesByDay,
    expensesByCategory,
  };
});
