import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBusinessMember } from "../middleware/checkPlanLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// getTaxSettings
// -----------------------------------------------------------
export const getTaxSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  
  const { businessId } = request.data as { businessId: string };
  if (!businessId) throw new HttpsError("invalid-argument", "businessId is required.");

  await assertBusinessMember(request.auth.uid, businessId);

  const snap = await db().collection("tax_settings").doc(businessId).get();
  return snap.exists ? snap.data() : {};
});

// -----------------------------------------------------------
// updateTaxSettings
// -----------------------------------------------------------
export const updateTaxSettings = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  
  const { businessId, eTimsEnabled, kraPin, branchCode } = request.data as {
    businessId: string;
    eTimsEnabled: boolean;
    kraPin?: string;
    branchCode?: string;
  };
  
  if (!businessId) throw new HttpsError("invalid-argument", "businessId is required.");

  await assertBusinessMember(request.auth.uid, businessId, ["owner", "manager"]);

  await db().collection("tax_settings").doc(businessId).set({
    eTimsEnabled: !!eTimsEnabled,
    kraPin: kraPin || "",
    branchCode: branchCode || "",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  }, { merge: true });

  return { success: true };
});
