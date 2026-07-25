// ============================================================
// Accounting Functions — Double Entry Ledger & Trial Balance
// ============================================================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// Standard Chart of Accounts (Hardware Store Template)
export const STANDARD_ACCOUNTS = [
  { code: "1000", name: "Cash in Hand", type: "Asset" },
  { code: "1010", name: "Bank Account", type: "Asset" },
  { code: "1020", name: "M-Pesa Account", type: "Asset" },
  { code: "1200", name: "Accounts Receivable", type: "Asset" },
  { code: "1300", name: "Inventory", type: "Asset" },
  { code: "2000", name: "Accounts Payable", type: "Liability" },
  { code: "2100", name: "VAT Payable", type: "Liability" },
  { code: "3000", name: "Owner's Equity", type: "Equity" },
  { code: "4000", name: "Sales Revenue", type: "Revenue" },
  { code: "5000", name: "Cost of Goods Sold (COGS)", type: "Expense" },
  { code: "6000", name: "Rent Expense", type: "Expense" },
  { code: "6010", name: "Utilities Expense", type: "Expense" },
  { code: "6020", name: "Salaries Expense", type: "Expense" },
  { code: "6030", name: "Transport Expense", type: "Expense" },
  { code: "6900", name: "General Expenses", type: "Expense" },
];

export interface JournalLine {
  accountId: string;
  debit: number;
  credit: number;
}

// -----------------------------------------------------------
// initializeChartOfAccounts
// Seeds the standard chart of accounts for a new/existing business
// -----------------------------------------------------------
export const initializeChartOfAccounts = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);

  const batch = db().batch();
  const accountsRef = db().collection("chart_of_accounts");

  // Check if already initialized
  const existing = await accountsRef.where("businessId", "==", businessId).limit(1).get();
  if (!existing.empty) {
    return { success: true, message: "Already initialized" };
  }

  for (const acc of STANDARD_ACCOUNTS) {
    const docRef = accountsRef.doc();
    batch.set(docRef, {
      id: docRef.id,
      businessId,
      code: acc.code,
      name: acc.name,
      type: acc.type,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  return { success: true };
});

// -----------------------------------------------------------
// Helper: postJournalEntryHelper
// Designed to be called inside existing Firestore Transactions (e.g. Sales, Expenses)
// -----------------------------------------------------------
export function postJournalEntryHelper(
  txn: admin.firestore.Transaction,
  businessId: string,
  referenceId: string,
  description: string,
  lines: JournalLine[],
  date?: admin.firestore.Timestamp
) {
  // Validate accounting equation (Total Debits == Total Credits)
  const totalDebit = lines.reduce((sum, line) => sum + line.debit, 0);
  const totalCredit = lines.reduce((sum, line) => sum + line.credit, 0);

  if (Math.abs(totalDebit - totalCredit) > 0.01) {
    throw new Error(`Journal Entry out of balance. Dr: ${totalDebit}, Cr: ${totalCredit}`);
  }

  const entryRef = db().collection("journal_entries").doc();
  const now = date || admin.firestore.Timestamp.now();

  // We save the header
  txn.set(entryRef, {
    id: entryRef.id,
    businessId,
    referenceId,
    description,
    totalAmount: Number(totalDebit.toFixed(2)),
    createdAt: now,
  });

  // We save individual lines to allow SUM() aggregation queries
  for (const line of lines) {
    const lineRef = db().collection("journal_lines").doc();
    txn.set(lineRef, {
      id: lineRef.id,
      entryId: entryRef.id,
      businessId,
      accountId: line.accountId,
      debit: Number(line.debit.toFixed(2)),
      credit: Number(line.credit.toFixed(2)),
      date: now,
    });
  }
}

// -----------------------------------------------------------
// postManualJournalEntry
// Callable for frontend (Manual Adjustments)
// -----------------------------------------------------------
export const postManualJournalEntry = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId, description, lines } = request.data as {
    businessId: string;
    description: string;
    lines: JournalLine[];
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  await db().runTransaction(async (txn) => {
    postJournalEntryHelper(txn, businessId, "MANUAL", description, lines);
  });

  return { success: true };
});

// -----------------------------------------------------------
// getTrialBalance
// Uses Firestore SUM() aggregation to calculate account balances without pulling documents
// -----------------------------------------------------------
export const getTrialBalance = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  // Fetch all accounts
  const accountsSnap = await db().collection("chart_of_accounts").where("businessId", "==", businessId).orderBy("code").get();
  const accounts = accountsSnap.docs.map(d => d.data());

  const results: any[] = [];
  let totalDebits = 0;
  let totalCredits = 0;

  // Since we might have ~15-30 accounts, we can run aggregate queries in parallel
  const promises = accounts.map(async (acc) => {
    const aggSnap = await db().collection("journal_lines")
      .where("businessId", "==", businessId)
      .where("accountId", "==", acc.id)
      .aggregate({
        totalDebit: admin.firestore.AggregateField.sum('debit'),
        totalCredit: admin.firestore.AggregateField.sum('credit'),
      })
      .get();
    
    const data = aggSnap.data();
    const dr = data.totalDebit || 0;
    const cr = data.totalCredit || 0;
    
    // Calculate Normal Balance based on Account Type
    // Assets & Expenses normally have Debit balances (Dr - Cr)
    // Liabilities, Equity, Revenue normally have Credit balances (Cr - Dr)
    let balance = 0;
    if (acc.type === "Asset" || acc.type === "Expense") {
      balance = dr - cr;
    } else {
      balance = cr - dr;
    }

    if (dr > 0 || cr > 0) {
      totalDebits += dr;
      totalCredits += cr;
      results.push({
        id: acc.id,
        code: acc.code,
        name: acc.name,
        type: acc.type,
        debit: dr,
        credit: cr,
        balance: balance
      });
    }
  });

  await Promise.all(promises);

  // Sort by code again after parallel processing
  results.sort((a, b) => a.code.localeCompare(b.code));

  return { 
    accounts: results, 
    totalDebits: Number(totalDebits.toFixed(2)), 
    totalCredits: Number(totalCredits.toFixed(2)) 
  };
});

// -----------------------------------------------------------
// getChartOfAccounts
// -----------------------------------------------------------
export const getChartOfAccounts = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager", "staff"]);

  const accountsSnap = await db().collection("chart_of_accounts").where("businessId", "==", businessId).orderBy("code").get();
  return { accounts: accountsSnap.docs.map(d => d.data()) };
});

// -----------------------------------------------------------
// migrateHistoricalData
// Reads past sales/expenses and generates missing journal entries.
// -----------------------------------------------------------
export const migrateHistoricalData = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);

  const accountsSnap = await db().collection("chart_of_accounts").where("businessId", "==", businessId).get();
  if (accountsSnap.empty) {
    throw new HttpsError("failed-precondition", "Please initialize Chart of Accounts first.");
  }

  const accounts = accountsSnap.docs.map(d => d.data());
  const getAcc = (name: string) => accounts.find(a => a.name === name)?.id;

  const cashAcc = getAcc("Cash in Hand");
  const mpesaAcc = getAcc("M-Pesa Account");
  const arAcc = getAcc("Accounts Receivable");
  const salesAcc = getAcc("Sales Revenue");
  const cogsAcc = getAcc("Cost of Goods Sold (COGS)");
  const invAcc = getAcc("Inventory");
  const genExpAcc = getAcc("General Expenses");

  if (!cashAcc || !salesAcc || !cogsAcc || !invAcc || !genExpAcc || !mpesaAcc || !arAcc) {
    throw new HttpsError("failed-precondition", "Missing standard accounts. Cannot migrate.");
  }

  // Find all sales
  const salesSnap = await db().collection("sales").where("businessId", "==", businessId).get();
  // Find all expenses
  const expSnap = await db().collection("expenses").where("businessId", "==", businessId).get();

  let migratedSales = 0;
  let migratedExpenses = 0;

  // Use batches for massive writing
  let batch = db().batch();
  let opCount = 0;

  const commitBatch = async () => {
    if (opCount > 0) {
      await batch.commit();
      batch = db().batch();
      opCount = 0;
    }
  };

  // Helper inside migration (bypasses transaction limit, just writes directly to batch)
  const writeMigrationJournal = async (refId: string, desc: string, lines: JournalLine[], date: admin.firestore.Timestamp) => {
    const totalDebit = lines.reduce((sum, line) => sum + line.debit, 0);
    const entryRef = db().collection("journal_entries").doc();
    batch.set(entryRef, {
      id: entryRef.id,
      businessId,
      referenceId: refId,
      description: desc,
      totalAmount: totalDebit,
      createdAt: date,
    });
    opCount++;

    for (const line of lines) {
      const lineRef = db().collection("journal_lines").doc();
      batch.set(lineRef, {
        id: lineRef.id,
        entryId: entryRef.id,
        businessId,
        accountId: line.accountId,
        debit: line.debit,
        credit: line.credit,
        date: date,
      });
      opCount++;
    }

    if (opCount > 400) await commitBatch(); // Firestore limit is 500
  };

  // 1. Process Sales
  for (const doc of salesSnap.docs) {
    const sale = doc.data();
    
    // Check if this sale already has a journal entry
    const existingSnap = await db().collection("journal_entries")
      .where("businessId", "==", businessId)
      .where("referenceId", "==", sale.id)
      .limit(1)
      .get();
      
    if (!existingSnap.empty) continue;

    // Build lines
    const lines: JournalLine[] = [];
    
    // Revenue part
    let assetAcc = cashAcc;
    if (sale.paymentMethod === "mpesa") assetAcc = mpesaAcc;
    if (sale.paymentMethod === "credit") assetAcc = arAcc;

    lines.push({ accountId: assetAcc, debit: sale.total, credit: 0 });
    lines.push({ accountId: salesAcc, debit: 0, credit: sale.total });

    // COGS part
    const cost = sale.total - (sale.profit || 0);
    if (cost > 0) {
      lines.push({ accountId: cogsAcc, debit: cost, credit: 0 });
      lines.push({ accountId: invAcc, debit: 0, credit: cost });
    }

    await writeMigrationJournal(sale.id, `Sale ${sale.paymentMethod}`, lines, sale.createdAt);
    migratedSales++;
  }

  // 2. Process Expenses
  for (const doc of expSnap.docs) {
    const exp = doc.data();
    
    const existingSnap = await db().collection("journal_entries")
      .where("businessId", "==", businessId)
      .where("referenceId", "==", exp.id)
      .limit(1)
      .get();
      
    if (!existingSnap.empty) continue;

    // Map category to account if possible, else General Expenses
    const catAcc = accounts.find(a => a.name === `${exp.category} Expense`)?.id || genExpAcc;

    const lines: JournalLine[] = [
      { accountId: catAcc, debit: exp.amount, credit: 0 },
      { accountId: cashAcc, debit: 0, credit: exp.amount },
    ];

    await writeMigrationJournal(exp.id, `Expense: ${exp.category}`, lines, exp.createdAt);
    migratedExpenses++;
  }

  await commitBatch();

  return { success: true, migratedSales, migratedExpenses };
});

// -----------------------------------------------------------
// createJournalEntry
// Allows manual posting of double-entry journal records
// -----------------------------------------------------------
export const createJournalEntry = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  
  const { businessId, referenceId, description, lines, date } = request.data as {
    businessId: string;
    referenceId: string;
    description: string;
    lines: { accountId: string; debit: number; credit: number }[];
    date?: string; // ISO string
  };

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  if (!lines || lines.length < 2) {
    throw new HttpsError("invalid-argument", "A journal entry must have at least two lines.");
  }

  // Validate balanced entry
  const totalDebit = lines.reduce((sum, line) => sum + line.debit, 0);
  const totalCredit = lines.reduce((sum, line) => sum + line.credit, 0);
  
  // allow small floating point differences, but generally must match exactly
  if (Math.abs(totalDebit - totalCredit) > 0.01) {
    throw new HttpsError("invalid-argument", `Entry is not balanced. Debits: ${totalDebit}, Credits: ${totalCredit}`);
  }

  const entryDate = date ? admin.firestore.Timestamp.fromDate(new Date(date)) : admin.firestore.Timestamp.now();

  await db().runTransaction(async (txn) => {
    postJournalEntryHelper(txn, businessId, referenceId || "MANUAL", description, lines, entryDate);
  });

  return { success: true, total: totalDebit };
});

// -----------------------------------------------------------
// getProfitAndLoss
// Calculates revenue minus expenses over a date range
// -----------------------------------------------------------
export const getProfitAndLoss = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  
  const { businessId, startDate, endDate } = request.data as {
    businessId: string;
    startDate?: string;
    endDate?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query = db().collection("journal_lines").where("businessId", "==", businessId);
  
  if (startDate) {
    query = query.where("date", ">=", admin.firestore.Timestamp.fromDate(new Date(startDate)));
  }
  if (endDate) {
    query = query.where("date", "<=", admin.firestore.Timestamp.fromDate(new Date(endDate)));
  }

  const linesSnap = await query.get();
  
  // We need account types to classify them.
  const accountsSnap = await db().collection("chart_of_accounts").where("businessId", "==", businessId).get();
  const accounts = new Map(accountsSnap.docs.map(d => [d.id, d.data()]));

  const revenueAccounts: any = {};
  const expenseAccounts: any = {};

  let totalRevenue = 0;
  let totalExpense = 0;

  for (const doc of linesSnap.docs) {
    const line = doc.data();
    const acc = accounts.get(line.accountId);
    if (!acc) continue;

    if (acc.type === "Revenue") {
      const net = line.credit - line.debit; // Normal credit balance
      revenueAccounts[acc.name] = (revenueAccounts[acc.name] || 0) + net;
      totalRevenue += net;
    } else if (acc.type === "Expense") {
      const net = line.debit - line.credit; // Normal debit balance
      expenseAccounts[acc.name] = (expenseAccounts[acc.name] || 0) + net;
      totalExpense += net;
    }
  }

  return {
    revenue: Object.keys(revenueAccounts).map(name => ({ name, amount: revenueAccounts[name] })),
    expenses: Object.keys(expenseAccounts).map(name => ({ name, amount: expenseAccounts[name] })),
    totalRevenue,
    totalExpense,
    netProfit: totalRevenue - totalExpense,
  };
});

// -----------------------------------------------------------
// getBalanceSheet
// Calculates Assets, Liabilities, and Equity as of a specific date
// -----------------------------------------------------------
export const getBalanceSheet = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  
  const { businessId, asOfDate } = request.data as {
    businessId: string;
    asOfDate?: string;
  };

  await assertBusinessMember(request.auth.uid, businessId);

  let query = db().collection("journal_lines").where("businessId", "==", businessId);
  
  if (asOfDate) {
    query = query.where("date", "<=", admin.firestore.Timestamp.fromDate(new Date(asOfDate)));
  }

  const linesSnap = await query.get();
  
  const accountsSnap = await db().collection("chart_of_accounts").where("businessId", "==", businessId).get();
  const accounts = new Map(accountsSnap.docs.map(d => [d.id, d.data()]));

  const assets: any = {};
  const liabilities: any = {};
  const equity: any = {};

  let totalAssets = 0;
  let totalLiabilities = 0;
  let totalEquity = 0;
  let retainedEarnings = 0; // Net profit added to equity

  for (const doc of linesSnap.docs) {
    const line = doc.data();
    const acc = accounts.get(line.accountId);
    if (!acc) continue;

    if (acc.type === "Asset") {
      const net = line.debit - line.credit;
      assets[acc.name] = (assets[acc.name] || 0) + net;
      totalAssets += net;
    } else if (acc.type === "Liability") {
      const net = line.credit - line.debit;
      liabilities[acc.name] = (liabilities[acc.name] || 0) + net;
      totalLiabilities += net;
    } else if (acc.type === "Equity") {
      const net = line.credit - line.debit;
      equity[acc.name] = (equity[acc.name] || 0) + net;
      totalEquity += net;
    } else if (acc.type === "Revenue") {
      retainedEarnings += (line.credit - line.debit);
    } else if (acc.type === "Expense") {
      retainedEarnings -= (line.debit - line.credit);
    }
  }
  
  // Add retained earnings to equity
  totalEquity += retainedEarnings;
  if (retainedEarnings !== 0) {
    equity["Retained Earnings"] = (equity["Retained Earnings"] || 0) + retainedEarnings;
  }

  return {
    assets: Object.keys(assets).map(name => ({ name, amount: assets[name] })),
    liabilities: Object.keys(liabilities).map(name => ({ name, amount: liabilities[name] })),
    equity: Object.keys(equity).map(name => ({ name, amount: equity[name] })),
    totalAssets,
    totalLiabilities,
    totalEquity,
    isBalanced: Math.abs(totalAssets - (totalLiabilities + totalEquity)) < 0.01
  };
});
