import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";
import { GoogleGenAI } from "@google/genai";
const db = () => admin.firestore();

// -----------------------------------------------------------
// analyzeInventoryHealth
// -----------------------------------------------------------
export const analyzeInventoryHealth = onCall(
  { ...SECURE_FN_OPTS, timeoutSeconds: 300 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

    const { businessId } = request.data as { businessId: string };
    if (!businessId) throw new HttpsError("invalid-argument", "businessId is required.");

    await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
    await assertActiveSubscription(businessId);

    // 1. Gather Data
    // We only fetch the top 100 products and recent sales to avoid massive payloads
    const productsSnap = await db()
      .collection("products")
      .where("businessId", "==", businessId)
      .limit(100)
      .get();
      
    const products = productsSnap.docs.map(d => {
      const data = d.data();
      return {
        name: data.name,
        qty: data.quantity,
        cost: data.costPrice,
        sell: data.sellingPrice,
        margin: data.sellingPrice > 0 ? ((data.sellingPrice - data.costPrice) / data.sellingPrice) * 100 : 0,
        reorderLvl: data.reorderLevel,
      };
    });

    const recentSalesSnap = await db()
      .collection("sales")
      .where("businessId", "==", businessId)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
      
    const sales = recentSalesSnap.docs.map(d => {
      const data = d.data();
      return {
        date: data.createdAt.toDate().toISOString(),
        total: data.total,
        profit: data.profit,
        itemsCount: data.items?.length || 0,
      };
    });

    const payload = JSON.stringify({
      totalProductsSampled: products.length,
      products: products,
      recentSales: sales,
    });

    // 2. Initialize Gemini
    const apiKey = process.env.GEMINI_API_KEY || "";
    const ai = new GoogleGenAI({ apiKey });

    const systemInstruction = `
You are a Senior Supply Chain Analyst for an Enterprise ERP system (HardwareOS).
You are analyzing the inventory health of a hardware and building materials retail business.

Provide a HIGHLY DETAILED, actionable markdown report.
Do not provide half-detailed or incomplete responses. You MUST provide exact mathematical backing for your recommendations based on the JSON payload provided.

Structure your response strictly as follows:

# Executive Summary
(Overall health, gross margins, and immediate red flags)

# Reorder Recommendations
(Explicit list of items currently below their reorder levels. Calculate their current deficit. Advise on order quantities.)

# Dead Stock & Velocity Alerts
(Identify items that have high quantity but low or no representation in the recent sales data. Highlight capital tied up.)

# Margin Anomalies
(Identify any products where the margin is suspiciously low or negative.)
`;

    try {
      const response = await ai.models.generateContent({
        model: "gemini-3.5-flash",
        contents: [
          { role: "user", parts: [{ text: `Analyze the following business data: ${payload}` }] }
        ],
        config: {
          systemInstruction: systemInstruction,
          temperature: 0.2, // Keep it analytical and precise
          maxOutputTokens: 2048,
        }
      });

      return {
        success: true,
        report: response.text,
      };
    } catch (error: any) {
      console.error("Gemini AI Error:", error);
      throw new HttpsError("internal", `AI Analysis Failed: ${error.message}`);
    }
  }
);
