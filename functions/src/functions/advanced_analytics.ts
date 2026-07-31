// ============================================================
// Advanced Analytics Functions — Pro-exclusive reports
// ============================================================

import * as admin from "firebase-admin";
import { SECURE_FN_OPTS, ANALYTICS_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription, assertFeatureEnabled } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// getAdvancedAnalytics
// -----------------------------------------------------------
export const getAdvancedAnalytics = onCall(ANALYTICS_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);
  await assertFeatureEnabled(businessId, "advancedAnalyticsEnabled");

  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const thirtyDaysAgo = new Date(startOfDay.getTime() - 29 * 24 * 60 * 60 * 1000);

  // Parallel fetch
  const [salesSnap, productsSnap] = await Promise.all([
    db().collection("sales").where("businessId", "==", businessId).where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo)).get(),
    db().collection("products").where("businessId", "==", businessId).get()
  ]);

  // 1. Daily Sales Trend
  const dailyTrends: Record<string, number> = {};
  for (let i = 0; i < 30; i++) {
    const d = new Date(thirtyDaysAgo.getTime() + i * 24 * 60 * 60 * 1000);
    dailyTrends[d.toISOString().split('T')[0]] = 0;
  }

  salesSnap.docs.forEach(doc => {
    const data = doc.data();
    const date = (data.createdAt as admin.firestore.Timestamp).toDate().toISOString().split('T')[0];
    if (dailyTrends[date] !== undefined) {
      dailyTrends[date] += data.total || 0;
    }
  });

  const salesTrend = Object.keys(dailyTrends).sort().map(date => ({
    date,
    revenue: dailyTrends[date]
  }));

  // 2. Margin Analysis per Category & Product Velocity
  const categoryMargins: Record<string, { revenue: number; cost: number }> = {};
  const productVelocity: Record<string, { name: string; category: string; unitsSold: number }> = {};

  productsSnap.docs.forEach(doc => {
    const p = doc.data();
    productVelocity[p.id] = { name: p.name, category: p.category || 'Uncategorized', unitsSold: 0 };
    if (!categoryMargins[p.category || 'Uncategorized']) {
      categoryMargins[p.category || 'Uncategorized'] = { revenue: 0, cost: 0 };
    }
  });

  salesSnap.docs.forEach(doc => {
    const data = doc.data();
    const items = data.items || [];
    items.forEach((item: any) => {
      const pId = item.productId;
      if (productVelocity[pId]) {
        productVelocity[pId].unitsSold += (item.quantity || 1);
      }
      
      const cat = productVelocity[pId]?.category || 'Uncategorized';
      if (!categoryMargins[cat]) categoryMargins[cat] = { revenue: 0, cost: 0 };
      
      const rev = item.subtotal || ((item.price || 0) * (item.quantity || 1));
      const cost = (item.costPrice || item.buyingPrice || 0) * (item.quantity || 1);
      
      categoryMargins[cat].revenue += rev;
      categoryMargins[cat].cost += cost;
    });
  });

  const margins = Object.entries(categoryMargins).map(([category, data]) => ({
    category,
    marginPercentage: data.revenue > 0 ? ((data.revenue - data.cost) / data.revenue) * 100 : 0,
    totalRevenue: data.revenue
  })).sort((a, b) => b.totalRevenue - a.totalRevenue);

  const topVelocity = Object.values(productVelocity)
    .sort((a, b) => b.unitsSold - a.unitsSold)
    .slice(0, 20)
    .map(p => ({
      name: p.name,
      unitsPerDay: Number((p.unitsSold / 30).toFixed(2))
    }));

  return {
    salesTrend,
    margins,
    topVelocity
  };
});

// -----------------------------------------------------------
// getDemandForecast
// -----------------------------------------------------------
export const getDemandForecast = onCall(ANALYTICS_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);
  await assertFeatureEnabled(businessId, "advancedAnalyticsEnabled");

  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const sixtyDaysAgo = new Date(startOfDay.getTime() - 60 * 24 * 60 * 60 * 1000);

  const [salesSnap, productsSnap] = await Promise.all([
    db().collection("sales").where("businessId", "==", businessId).where("createdAt", ">=", admin.firestore.Timestamp.fromDate(sixtyDaysAgo)).get(),
    db().collection("products").where("businessId", "==", businessId).get()
  ]);

  const productData: Record<string, { name: string; stock: number; soldLast30: number; soldPrev30: number }> = {};
  productsSnap.docs.forEach(doc => {
    const p = doc.data();
    productData[p.id] = { name: p.name, stock: p.quantity || 0, soldLast30: 0, soldPrev30: 0 };
  });

  const thirtyDaysAgoTime = startOfDay.getTime() - 30 * 24 * 60 * 60 * 1000;

  salesSnap.docs.forEach(doc => {
    const data = doc.data();
    const createdAt = (data.createdAt as admin.firestore.Timestamp).toMillis();
    const isLast30 = createdAt >= thirtyDaysAgoTime;
    
    const items = data.items || [];
    items.forEach((item: any) => {
      const pId = item.productId;
      if (productData[pId]) {
        if (isLast30) productData[pId].soldLast30 += (item.quantity || 1);
        else productData[pId].soldPrev30 += (item.quantity || 1);
      }
    });
  });

  const forecast = Object.values(productData)
    .filter(p => p.soldLast30 > 0 || p.soldPrev30 > 0)
    .map(p => {
      // Simple trend calculation
      const trend = p.soldPrev30 > 0 ? (p.soldLast30 - p.soldPrev30) / p.soldPrev30 : 0.1;
      const predictedNext30Days = Math.max(0, Math.round(p.soldLast30 * (1 + (trend * 0.5)))); // dampen trend
      const daysOfStock = predictedNext30Days > 0 ? Math.round((p.stock / predictedNext30Days) * 30) : 999;
      const suggestedReorder = Math.max(0, predictedNext30Days - p.stock);
      
      return {
        name: p.name,
        currentStock: p.stock,
        predictedDemand30d: predictedNext30Days,
        daysOfStock,
        suggestedReorderQuantity: suggestedReorder > 0 ? suggestedReorder : 0
      };
    })
    .sort((a, b) => b.suggestedReorderQuantity - a.suggestedReorderQuantity)
    .slice(0, 30);

  return { forecast };
});
