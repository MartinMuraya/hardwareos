// ============================================================
// AI Assistant Functions — Gemini-powered business insights
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const geminiApiKeySecret = defineSecret("GEMINI_API_KEY");
const db = () => admin.firestore();

// Internal helper to get business context
async function getBusinessContext(businessId: string): Promise<string> {
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const thirtyDaysAgo = new Date(startOfDay.getTime() - 30 * 24 * 60 * 60 * 1000);
  
  const [salesSnap, expensesSnap, productsSnap, bizSnap] = await Promise.all([
    db().collection("sales").where("businessId", "==", businessId).where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo)).get(),
    db().collection("expenses").where("businessId", "==", businessId).where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo)).get(),
    db().collection("products").where("businessId", "==", businessId).get(),
    db().collection("businesses").doc(businessId).get()
  ]);

  let totalRevenue30d = 0;
  let totalSalesCount30d = 0;
  salesSnap.docs.forEach(d => {
    totalRevenue30d += d.data().total || 0;
    totalSalesCount30d++;
  });

  let totalExpenses30d = 0;
  expensesSnap.docs.forEach(d => {
    totalExpenses30d += d.data().amount || 0;
  });

  let lowStockCount = 0;
  let totalInventoryValue = 0;
  productsSnap.docs.forEach(d => {
    const p = d.data();
    if (p.quantity <= p.reorderLevel) lowStockCount++;
    totalInventoryValue += (p.buyingPrice || p.costPrice || 0) * (p.quantity || 0);
  });

  const bizData = bizSnap.data();

  return `
Business Name: ${bizData?.name || 'Hardware Store'}
Past 30 Days Summary:
- Revenue: KES ${totalRevenue30d}
- Total Sales Transactions: ${totalSalesCount30d}
- Expenses: KES ${totalExpenses30d}
- Current Inventory Value: KES ${totalInventoryValue}
- Items Low on Stock: ${lowStockCount}
`;
}

// Generate prompt response using Gemini REST API
async function callGeminiAPI(prompt: string, apiKey: string): Promise<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=${apiKey}`;
  
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      systemInstruction: {
        parts: [{ text: "You are an expert AI business advisor for a hardware store in East Africa. Provide concise, highly actionable, and numerical insights based on the provided data. Do not use generic platitudes. Focus on cash flow, inventory optimization, and sales strategy." }]
      },
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 500,
      }
    })
  });

  if (!response.ok) {
    console.error("Gemini API Error:", await response.text());
    throw new Error("Failed to communicate with AI provider.");
  }

  const data = await response.json() as any;
  if (data?.candidates?.[0]?.content?.parts?.[0]?.text) {
    return data.candidates[0].content.parts[0].text;
  }
  return "Could not generate insights at this time.";
}

// -----------------------------------------------------------
// getAIInsights
// -----------------------------------------------------------
export const getAIInsights = onCall({ cors: true, secrets: [geminiApiKeySecret] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, prompt } = request.data as { businessId: string; prompt?: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);
  
  // Verify plan supports AI (Pro feature)
  const bizSnap = await db().collection("businesses").doc(businessId).get();
  if (bizSnap.data()?.plan !== "pro") {
    throw new HttpsError("permission-denied", "AI Insights are only available on the Pro plan.");
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError("internal", "AI service is currently not configured.");
  }

  const contextStr = await getBusinessContext(businessId);
  
  let finalPrompt = "";
  if (prompt && prompt.trim().length > 0) {
    finalPrompt = `Context:\n${contextStr}\n\nUser Question:\n${prompt}`;
  } else {
    finalPrompt = `Context:\n${contextStr}\n\nPlease provide a 3-bullet executive summary of the business health, highlighting any immediate risks (like high expenses or low stock) and one concrete recommendation.`;
  }

  try {
    if (apiKey === "dummy") {
      return { insights: "🤖 (Simulation Mode)\nYour business is performing well! This is a simulated AI insight because you are using a dummy Gemini API key. Add a real API key to get real insights!" };
    }
    const responseText = await callGeminiAPI(finalPrompt, apiKey);
    return { insights: responseText };
  } catch (error) {
    console.error("getAIInsights error:", error);
    throw new HttpsError("internal", "Failed to generate AI insights.");
  }
});

// -----------------------------------------------------------
// getAIQuickInsights
// -----------------------------------------------------------
export const getAIQuickInsights = onCall({ cors: true, secrets: [geminiApiKeySecret] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, type } = request.data as { businessId: string; type: "inventory_optimization" | "sales_trends" | "profit_analysis" | "reorder_suggestions" };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);
  
  const bizSnap = await db().collection("businesses").doc(businessId).get();
  if (bizSnap.data()?.plan !== "pro") {
    throw new HttpsError("permission-denied", "AI Insights are only available on the Pro plan.");
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError("internal", "AI service is currently not configured.");
  }

  const contextStr = await getBusinessContext(businessId);
  
  let specificQuestion = "";
  switch(type) {
    case "inventory_optimization": specificQuestion = "How can we optimize our inventory holding costs based on this data?"; break;
    case "sales_trends": specificQuestion = "What are the key sales trends in the last 30 days?"; break;
    case "profit_analysis": specificQuestion = "Analyze our profit margin and suggest 2 ways to reduce expenses."; break;
    case "reorder_suggestions": specificQuestion = "What should we prioritize reordering and why?"; break;
    default: specificQuestion = "Give me a quick business insight.";
  }

  const finalPrompt = `Context:\n${contextStr}\n\nTask:\n${specificQuestion}`;

  try {
    if (apiKey === "dummy") {
      return { insights: "🤖 (Simulation Mode)\nThis is a quick simulated AI insight because you are using a dummy Gemini API key. Add a real API key to get real insights!" };
    }
    const responseText = await callGeminiAPI(finalPrompt, apiKey);
    return { insights: responseText };
  } catch (error) {
    console.error("getAIQuickInsights error:", error);
    throw new HttpsError("internal", "Failed to generate AI insights.");
  }
});
