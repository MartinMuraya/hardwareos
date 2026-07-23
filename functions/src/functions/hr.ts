import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember, assertActiveSubscription } from "../middleware/checkPlanLimits";
import { postJournalEntryHelper, JournalLine } from "./accounting";

const db = () => admin.firestore();

// -----------------------------------------------------------
// HR Settings (Configurable Statutory Rates)
// -----------------------------------------------------------
export const saveHrSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId, payeRate, nhifRate, nssfRate } = request.data as {
    businessId: string;
    payeRate: number;
    nhifRate: number;
    nssfRate: number;
  };
  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);

  await db().collection("hr_settings").doc(businessId).set({
    payeRate: Number(payeRate) || 0,
    nhifRate: Number(nhifRate) || 0,
    nssfRate: Number(nssfRate) || 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const getHrSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId } = request.data as { businessId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const doc = await db().collection("hr_settings").doc(businessId).get();
  if (!doc.exists) {
    return { payeRate: 30.0, nhifRate: 2.75, nssfRate: 6.0 }; // Default Kenyan simplified rates
  }
  return doc.data();
});

// -----------------------------------------------------------
// Employee Management
// -----------------------------------------------------------
export const createEmployee = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId, fullName, role, kraPin, nhifNumber, nssfNumber, baseSalary, employmentType } = request.data as any;
  
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);
  await assertActiveSubscription(businessId);

  const empRef = db().collection("employees").doc();
  await empRef.set({
    id: empRef.id,
    businessId,
    fullName,
    role,
    kraPin: kraPin || "",
    nhifNumber: nhifNumber || "",
    nssfNumber: nssfNumber || "",
    baseSalary: Number(baseSalary) || 0,
    employmentType: employmentType || "Full-Time",
    status: "Active",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, employeeId: empRef.id };
});

export const updateEmployee = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { employeeId, businessId, ...updates } = request.data as any;
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  const empRef = db().collection("employees").doc(employeeId);
  const snap = await empRef.get();
  if (!snap.exists || snap.data()!.businessId !== businessId) {
    throw new HttpsError("not-found", "Employee not found.");
  }

  await empRef.update({
    ...updates,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// -----------------------------------------------------------
// Timesheets & Leave
// -----------------------------------------------------------
export const submitTimesheet = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId, employeeId, date, hoursWorked, overtimeHours } = request.data as any;
  await assertBusinessMember(request.auth.uid, businessId);

  const tsRef = db().collection("timesheets").doc();
  await tsRef.set({
    id: tsRef.id,
    businessId,
    employeeId,
    date,
    hoursWorked: Number(hoursWorked) || 0,
    overtimeHours: Number(overtimeHours) || 0,
    status: "Pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const processLeave = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId, leaveId, status } = request.data as any; // status: Approved, Rejected
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  await db().collection("leave_requests").doc(leaveId).update({
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true };
});

export function calculatePayslip(gross: number, rates: { payeRate: number, nhifRate: number, nssfRate: number }) {
  const paye = gross * (rates.payeRate / 100);
  const nhif = gross * (rates.nhifRate / 100);
  const nssf = gross * (rates.nssfRate / 100);
  const deds = paye + nhif + nssf;
  const net = gross - deds;
  return { paye, nhif, nssf, deductions: deds, netPay: net };
}

// -----------------------------------------------------------
// Payroll Generation & Processing
// -----------------------------------------------------------
export const generatePayroll = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId, period } = request.data as { businessId: string; period: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  // Fetch settings
  const settingsDoc = await db().collection("hr_settings").doc(businessId).get();
  const settings = settingsDoc.exists ? settingsDoc.data() as any : { payeRate: 30, nhifRate: 2.75, nssfRate: 6 };

  // Fetch active employees
  const empSnap = await db().collection("employees").where("businessId", "==", businessId).where("status", "==", "Active").get();
  if (empSnap.empty) throw new HttpsError("failed-precondition", "No active employees found.");

  const payrollRef = db().collection("payrolls").doc();
  const batch = db().batch();

  let totalGross = 0;
  let totalDeductions = 0;
  let totalNetPay = 0;

  for (const doc of empSnap.docs) {
    const emp = doc.data();
    const gross = emp.baseSalary;
    
    const { paye, nhif, nssf, deductions, netPay } = calculatePayslip(gross, settings);

    totalGross += gross;
    totalDeductions += deductions;
    totalNetPay += netPay;

    const payslipRef = payrollRef.collection("payslips").doc(emp.id);
    batch.set(payslipRef, {
      employeeId: emp.id,
      fullName: emp.fullName,
      grossPay: Number(gross.toFixed(2)),
      paye: Number(paye.toFixed(2)),
      nhif: Number(nhif.toFixed(2)),
      nssf: Number(nssf.toFixed(2)),
      netPay: Number(netPay.toFixed(2)),
    });
  }

  batch.set(payrollRef, {
    id: payrollRef.id,
    businessId,
    period,
    totalGross: Number(totalGross.toFixed(2)),
    totalDeductions: Number(totalDeductions.toFixed(2)),
    totalNetPay: Number(totalNetPay.toFixed(2)),
    status: "Draft",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();
  return { success: true, payrollId: payrollRef.id };
});

export const processPayroll = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { businessId, payrollId } = request.data as { businessId: string; payrollId: string };
  await assertBusinessMember(request.auth.uid, businessId, ["owner"]);

  await db().runTransaction(async (txn) => {
    const prRef = db().collection("payrolls").doc(payrollId);
    const prSnap = await txn.get(prRef);
    if (!prSnap.exists) throw new HttpsError("not-found", "Payroll not found.");
    
    const pr = prSnap.data()!;
    if (pr.status !== "Draft") throw new HttpsError("failed-precondition", "Payroll is not in Draft state.");

    // Double-Entry Accounting Integration
    const accountsSnap = await txn.get(db().collection("chart_of_accounts").where("businessId", "==", businessId));
    if (!accountsSnap.empty) {
      const accounts = accountsSnap.docs.map(d => d.data());
      const getAcc = (name: string) => accounts.find(a => a.name === name)?.id;
      
      const salExpAcc = getAcc("Salaries Expense");
      const cashAcc = getAcc("Bank Account") || getAcc("Cash in Hand");
      const apAcc = getAcc("Accounts Payable");

      if (salExpAcc && cashAcc && apAcc) {
        const lines: JournalLine[] = [
          { accountId: salExpAcc, debit: pr.totalGross, credit: 0 },
          { accountId: cashAcc, debit: 0, credit: pr.totalNetPay },
        ];
        
        if (pr.totalDeductions > 0) {
          lines.push({ accountId: apAcc, debit: 0, credit: pr.totalDeductions });
        }

        postJournalEntryHelper(txn, businessId, payrollId, `Payroll: ${pr.period}`, lines);
      }
    }

    txn.update(prRef, {
      status: "Processed",
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: request.auth!.uid,
    });
  });

  return { success: true };
});
