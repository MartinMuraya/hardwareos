import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// sendDailyEodReport
// Scheduled function running every day at 20:00 EAT (Africa/Nairobi)
// -----------------------------------------------------------
export const sendDailyEodReport = onSchedule({ schedule: "0 20 * * *", timeZone: "Africa/Nairobi" }, async () => {
  console.log("Starting Daily EOD Summary Report processing...");

  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfDayTs = admin.firestore.Timestamp.fromDate(startOfDay);

  const bizSnap = await db().collection("businesses").where("active", "==", true).get();

  for (const doc of bizSnap.docs) {
    const bizId = doc.id;
    const bizData = doc.data();

    // Check if business has enabled EOD report
    if (!bizData.eodReportEnabled) continue;

    const phone = bizData.eodReportPhone || bizData.phone;
    if (!phone) continue;

    try {
      // Parallel queries for today's data
      const [salesSnap, expensesSnap, productsSnap, custDebtSnap, suppDebtSnap] = await Promise.all([
        db().collection("sales").where("businessId", "==", bizId).where("createdAt", ">=", startOfDayTs).get(),
        db().collection("expenses").where("businessId", "==", bizId).where("createdAt", ">=", startOfDayTs).get(),
        db().collection("products").where("businessId", "==", bizId).get(),
        db().collection("customers").where("businessId", "==", bizId).where("currentBalance", ">", 0).get(),
        db().collection("supplierDebts").where("businessId", "==", bizId).where("status", "in", ["pending", "partial", "overdue"]).get(),
      ]);

      let revenue = 0;
      let profit = 0;
      let mpesaTotal = 0;
      let cashTotal = 0;
      let salesCount = salesSnap.docs.length;

      salesSnap.docs.forEach((d) => {
        const s = d.data();
        revenue += s.total || 0;
        profit += s.profit || 0;
        if (s.paymentMethod === "mpesa") mpesaTotal += s.total || 0;
        if (s.paymentMethod === "cash") cashTotal += s.total || 0;
      });

      let expensesTotal = 0;
      expensesSnap.docs.forEach((d) => {
        expensesTotal += d.data().amount || 0;
      });

      let lowStockItems: string[] = [];
      productsSnap.docs.forEach((d) => {
        const p = d.data();
        if (p.quantity <= (p.reorderLevel || 5)) {
          lowStockItems.push(`${p.name}: ${p.quantity} left`);
        }
      });

      let customerOverdueTotal = 0;
      let customerOverdueCount = custDebtSnap.docs.length;
      custDebtSnap.docs.forEach((d) => {
        customerOverdueTotal += d.data().currentBalance || 0;
      });

      let supplierPayablesTotal = 0;
      suppDebtSnap.docs.forEach((d) => {
        supplierPayablesTotal += d.data().outstanding || 0;
      });

      const reportMsg = `
📊 DAILY EOD SUMMARY — ${now.toISOString().split("T")[0]}
Business: ${bizData.name}

💰 Revenue: KES ${revenue.toLocaleString()}
📦 Profit: KES ${profit.toLocaleString()}
🛒 Sales Count: ${salesCount}
💳 M-Pesa: KES ${mpesaTotal.toLocaleString()}
💵 Cash: KES ${cashTotal.toLocaleString()}

📉 Low Stock (${lowStockItems.length} items):
${lowStockItems.slice(0, 3).map((item) => `  - ${item}`).join("\n") || "  None"}

💸 Expenses Today: KES ${expensesTotal.toLocaleString()}
🔴 Customer Debt Owed: KES ${customerOverdueTotal.toLocaleString()} (${customerOverdueCount} customers)
🏭 Supplier Payables: KES ${supplierPayablesTotal.toLocaleString()}

- HardwareOS POS
`.trim();

      // Save notification record to history
      await db().collection("eodReportsHistory").add({
        businessId: bizId,
        reportText: reportMsg,
        recipientPhone: phone,
        channel: bizData.eodReportChannel || "sms",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`EOD Report logged for ${bizData.name} (${phone})`);
    } catch (err) {
      console.error(`Failed generating EOD report for business ${bizId}:`, err);
    }
  }
});

// -----------------------------------------------------------
// updateEodReportSettings
// Callable endpoint for owners to configure daily report preferences
// -----------------------------------------------------------
export const updateEodReportSettings = onCall(SECURE_FN_OPTS, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { businessId, enabled, phone, channel } = request.data as {
    businessId: string;
    enabled: boolean;
    phone: string;
    channel: "sms" | "whatsapp" | "both";
  };

  if (!businessId) throw new HttpsError("invalid-argument", "businessId required.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);

  await db().collection("businesses").doc(businessId).update({
    eodReportEnabled: !!enabled,
    eodReportPhone: phone || "",
    eodReportChannel: channel || "sms",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
