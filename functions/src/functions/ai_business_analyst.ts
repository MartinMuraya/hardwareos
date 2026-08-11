// ============================================================
// AI Business Analyst — Autonomous Insights & Draft Action Engine
// ============================================================

import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription, assertFeatureEnabled } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

export type AnalystQueryType =
  | "runout_forecast"
  | "profit_variance"
  | "supplier_reorder"
  | "anomaly_detection"
  | "revenue_forecast"
  | "optimal_reorder"
  | "custom";

interface DraftAction {
  id: string;
  actionType: "draft_purchase_order" | "update_reorder_level" | "flag_suspicious_adjustment";
  title: string;
  description: string;
  payload: Record<string, any>;
}

// -----------------------------------------------------------
// Gathers comprehensive analytics context from database
// -----------------------------------------------------------
async function buildAnalystContext(businessId: string) {
  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const sixtyDaysAgo = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);

  const [
    productsSnap,
    recentSalesSnap,
    prevSalesSnap,
    adjustmentsSnap,
    suppliersSnap,
    expensesSnap,
    bizSnap,
  ] = await Promise.all([
    db().collection("products").where("businessId", "==", businessId).get(),
    db().collection("sales")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get(),
    db().collection("sales")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(sixtyDaysAgo))
      .where("createdAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get(),
    db().collection("stockAdjustments")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get(),
    db().collection("suppliers").where("businessId", "==", businessId).get(),
    db().collection("expenses")
      .where("businessId", "==", businessId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get(),
    db().collection("businesses").doc(businessId).get(),
  ]);

  // 1. Calculate Product Sales Velocity & Run-out Estimates
  const productSalesMap: Record<string, number> = {};
  let totalRevenue30d = 0;
  let totalProfit30d = 0;

  recentSalesSnap.docs.forEach((doc) => {
    const sale = doc.data();
    totalRevenue30d += sale.total || 0;
    totalProfit30d += sale.profit || 0;

    const items = (sale.items as Array<any>) || [];
    items.forEach((item) => {
      const pId = item.productId;
      const qty = Number(item.quantity) || 0;
      productSalesMap[pId] = (productSalesMap[pId] || 0) + qty;
    });
  });

  let prevRevenue30d = 0;
  let prevProfit30d = 0;
  prevSalesSnap.docs.forEach((doc) => {
    const sale = doc.data();
    prevRevenue30d += sale.total || 0;
    prevProfit30d += sale.profit || 0;
  });

  let totalExpenses30d = 0;
  expensesSnap.docs.forEach((d) => {
    totalExpenses30d += d.data().amount || 0;
  });

  // 2. Product Run-out & Optimal Reorder Summaries
  const runoutItems: Array<{
    id: string;
    name: string;
    stock: number;
    dailyBurn: number;
    daysRemaining: number;
    reorderLevel: number;
    recommendedQty: number;
    supplierId?: string;
  }> = [];

  productsSnap.docs.forEach((doc) => {
    const p = doc.data();
    const sold30d = productSalesMap[p.id] || 0;
    const dailyBurn = sold30d / 30;
    const stock = Number(p.quantity) || 0;
    const daysRemaining = dailyBurn > 0 ? Math.round(stock / dailyBurn) : 999;
    const reorderLevel = Number(p.reorderLevel) || 5;

    // Recommend optimal quantity based on 30-day supply buffer
    const recommendedQty = Math.max(10, Math.ceil(dailyBurn * 30 - stock));

    if (daysRemaining <= 14 || stock <= reorderLevel) {
      runoutItems.push({
        id: p.id,
        name: p.name,
        stock,
        dailyBurn: Math.round(dailyBurn * 10) / 10,
        daysRemaining,
        reorderLevel,
        recommendedQty,
        supplierId: p.supplierId,
      });
    }
  });

  // 3. Stock Adjustment Anomalies (Shrinkage / Negatives)
  const suspiciousAdjustments: Array<{
    productId: string;
    productName: string;
    qtyChange: number;
    reason: string;
    adjustedBy: string;
    date: string;
  }> = [];

  adjustmentsSnap.docs.forEach((doc) => {
    const adj = doc.data();
    const qtyChange = Number(adj.qtyChange) || Number(adj.quantity) || 0;
    if (qtyChange < 0 || adj.reason?.toLowerCase().contains?.("damage") || adj.reason?.toLowerCase().contains?.("loss") || adj.reason?.toLowerCase().contains?.("stolen")) {
      suspiciousAdjustments.push({
        productId: adj.productId || "",
        productName: adj.productName || "Unknown Item",
        qtyChange,
        reason: adj.reason || "Manual deduction",
        adjustedBy: adj.userName || adj.userId || "Staff",
        date: (adj.createdAt as admin.firestore.Timestamp)?.toDate()?.toISOString().split("T")[0] || "Recent",
      });
    }
  });

  // 4. Supplier Map
  const suppliersMap: Record<string, string> = {};
  suppliersSnap.docs.forEach((doc) => {
    suppliersMap[doc.id] = doc.data().name || "Supplier";
  });

  const bizName = bizSnap.data()?.name || "Hardware Store";

  return {
    bizName,
    metrics: {
      revenue30d: totalRevenue30d,
      profit30d: totalProfit30d,
      expenses30d: totalExpenses30d,
      netMargin30d: totalRevenue30d > 0 ? ((totalProfit30d - totalExpenses30d) / totalRevenue30d) * 100 : 0,
      prevRevenue30d,
      prevProfit30d,
      revenueGrowth: prevRevenue30d > 0 ? ((totalRevenue30d - prevRevenue30d) / prevRevenue30d) * 100 : 0,
      profitGrowth: prevProfit30d > 0 ? ((totalProfit30d - prevProfit30d) / prevProfit30d) * 100 : 0,
    },
    runoutItems: runoutItems.sort((a, b) => a.daysRemaining - b.daysRemaining).slice(0, 10),
    suspiciousAdjustments: suspiciousAdjustments.slice(0, 5),
    suppliersMap,
  };
}

// Generate LLM analyst output using Gemini API
async function callGeminiAnalyst(prompt: string, apiKey: string): Promise<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=${apiKey}`;

  const systemInstruction = `
You are an expert Senior Retail & Supply Chain Business Analyst for HardwareOS.
Your objective is to provide executive, data-backed analytical breakdowns with exact numbers (KES, percentages, days remaining).

At the VERY END of your response, if there are concrete operational recommendations (like reordering stock, adjusting reorder levels, or flagging suspicious inventory losses), you MUST include a raw JSON block wrapped in \`\`\`json_actions ... \`\`\` containing actionable draft proposals.

Format for json_actions:
\`\`\`json_actions
[
  {
    "id": "draft_po_1",
    "actionType": "draft_purchase_order",
    "title": "Draft Purchase Order for Fast-Depleting Cement",
    "description": "Auto-generated purchase order for 50 bags from Supplier Kamau Materials",
    "payload": {
      "supplierName": "Kamau Materials",
      "items": [
        { "productId": "prod_123", "productName": "Portland Cement 50kg", "quantity": 50, "unitCost": 650 }
      ]
    }
  }
]
\`\`\`

Rules for response:
- Provide exhaustive, deeply detailed, numerical analysis (in KES and percentage velocity metrics).
- Highlight risk alerts clearly using standard markdown tags or bullet points.
- Do not make generic recommendations. Rely strictly on the numbers provided in the context.
`.trim();

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      systemInstruction: { parts: [{ text: systemInstruction }] },
      generationConfig: { temperature: 0.2, maxOutputTokens: 3072 },
    }),
  });

  if (!response.ok) {
    console.error("Gemini Business Analyst API Error:", await response.text());
    throw new Error("Failed to communicate with AI Business Analyst.");
  }

  const data = (await response.json()) as any;
  if (data?.candidates?.[0]?.content?.parts?.[0]?.text) {
    return data.candidates[0].content.parts[0].text;
  }
  return "Analyst evaluation complete. No additional anomalies found.";
}

// -----------------------------------------------------------
// runAIBusinessAnalyst
// Main endpoint for executive business queries
// -----------------------------------------------------------
export const runAIBusinessAnalyst = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, queryType, customPrompt } = request.data as {
    businessId: string;
    queryType: AnalystQueryType;
    customPrompt?: string;
  };

  if (!businessId || !queryType) {
    throw new HttpsError("invalid-argument", "businessId and queryType are required.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);
  await assertFeatureEnabled(businessId, "aiAnalystEnabled");

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError("internal", "AI Business Analyst service is not configured.");
  }

  const contextData = await buildAnalystContext(businessId);

  let queryTaskText = "";
  switch (queryType) {
    case "runout_forecast":
      queryTaskText = "Which products will run out next week? Identify exact daily burn rates, days remaining, and priority risk level.";
      break;
    case "profit_variance":
      queryTaskText = "Why did profit change this month compared to last month? Analyze revenue growth, gross margins vs expenses, and root cause drivers.";
      break;
    case "supplier_reorder":
      queryTaskText = "Which suppliers should I reorder from right now? Focus on low-stock items, lead times, and optimal reorder batching.";
      break;
    case "anomaly_detection":
      queryTaskText = "Detect suspicious inventory adjustments, stock losses, or negative manual corrections over the past 30 days. Highlight staff names and reasons.";
      break;
    case "revenue_forecast":
      queryTaskText = "Forecast next month's revenue and gross profit based on current 30-day velocity and month-over-month growth trends.";
      break;
    case "optimal_reorder":
      queryTaskText = "Recommend optimal reorder quantities for all low-stock items using 30-day velocity and buffer stock principles. Propose draft purchase orders.";
      break;
    case "custom":
      queryTaskText = customPrompt || "Analyze business performance and recommend key operational improvements.";
      break;
  }

  const prompt = `
BUSINESS CONTEXT:
Store: ${contextData.bizName}
30-Day Metrics:
- Revenue: KES ${contextData.metrics.revenue30d.toLocaleString()} (Growth: ${contextData.metrics.revenueGrowth.toFixed(1)}%)
- Gross Profit: KES ${contextData.metrics.profit30d.toLocaleString()} (Growth: ${contextData.metrics.profitGrowth.toFixed(1)}%)
- Expenses: KES ${contextData.metrics.expenses30d.toLocaleString()}
- Net Margin: ${contextData.metrics.netMargin30d.toFixed(1)}%

LOW STOCK & RUN-OUT PREDICTIONS:
${JSON.stringify(contextData.runoutItems, null, 2)}

SUSPICIOUS ADJUSTMENTS & SHRINKAGE:
${JSON.stringify(contextData.suspiciousAdjustments, null, 2)}

SUPPLIERS LOOKUP:
${JSON.stringify(contextData.suppliersMap, null, 2)}

ANALYST INSTRUCTION:
${queryTaskText}
`.trim();

  try {
    if (apiKey === "dummy") {
      return {
        analysisText: `🤖 **AI Business Analyst (Simulation Mode)**\n\n### 📊 Run-out & Velocity Analysis for ${contextData.bizName}\n- **Cement 50kg**: Estimated 4 days of stock remaining (Daily burn: 8.5 bags/day).\n- **Copper Wire 2.5mm**: Estimated 6 days remaining.\n\n### 💡 Recommended Actions\nWe recommend drafting a purchase order for **Portland Cement (50 bags)** to prevent stockout.`,
        draftActions: [
          {
            id: "draft_po_sim",
            actionType: "draft_purchase_order",
            title: "Draft PO: Portland Cement Restock",
            description: "Auto-generated purchase order for 50 bags to prevent stockout next week.",
            payload: {
              supplierName: "Kamau Building Materials",
              items: [{ productId: "prod_sim", productName: "Portland Cement 50kg", quantity: 50, unitCost: 680 }],
            },
          },
        ],
      };
    }

    const rawResponse = await callGeminiAnalyst(prompt, apiKey);

    // Extract draft actions if present
    let analysisText = rawResponse;
    let draftActions: DraftAction[] = [];

    if (rawResponse.includes("```json_actions")) {
      const parts = rawResponse.split("```json_actions");
      analysisText = parts[0].trim();
      const jsonStr = parts[1].split("```")[0].trim();
      try {
        draftActions = JSON.parse(jsonStr) as DraftAction[];
      } catch (err) {
        console.error("Failed to parse json_actions from AI Analyst output:", err);
      }
    }

    return { analysisText, draftActions };
  } catch (error) {
    console.error("runAIBusinessAnalyst error:", error);
    throw new HttpsError("internal", "Failed to execute AI Business Analyst query.");
  }
});

// -----------------------------------------------------------
// approveAIDraftedAction
// Human-in-the-loop approval gate for AI-proposed actions
// -----------------------------------------------------------
export const approveAIDraftedAction = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, actionType, payload } = request.data as {
    businessId: string;
    actionType: "draft_purchase_order" | "update_reorder_level";
    payload: Record<string, any>;
  };

  if (!businessId || !actionType || !payload) {
    throw new HttpsError("invalid-argument", "Missing action parameters.");
  }

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  if (actionType === "draft_purchase_order") {
    const poRef = db().collection("purchase_orders").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await poRef.set({
      id: poRef.id,
      businessId,
      supplierName: payload.supplierName || "Recommended Supplier",
      items: payload.items || [],
      status: "pending",
      createdByAI: true,
      approvedBy: request.auth.uid,
      createdAt: now,
      updatedAt: now,
    });

    return { success: true, purchaseOrderId: poRef.id, message: "Purchase Order draft created successfully!" };
  }

  if (actionType === "update_reorder_level") {
    const { productId, newReorderLevel } = payload;
    if (productId && newReorderLevel) {
      await db().collection("products").doc(productId).update({
        reorderLevel: Number(newReorderLevel),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, message: "Reorder level updated successfully!" };
    }
  }

  throw new HttpsError("invalid-argument", "Unsupported action type.");
});
