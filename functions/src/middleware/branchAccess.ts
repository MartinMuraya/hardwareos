// ============================================================
// Branch-Level Access Control (H6)
// ============================================================
// Enforces that users can only access branches assigned to them
// unless they are owner/manager level.
// ============================================================

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

const db = () => admin.firestore();

/**
 * Assert that the caller is allowed to access the given branch.
 * - Owner/manager roles have unrestricted branch access.
 * - Staff are restricted to their assigned branch(es).
 * - Throws permission-denied if access is not allowed.
 */
export async function assertBranchAccess(
  uid: string,
  businessId: string,
  branchId?: string | null,
): Promise<void> {
  if (!branchId) return; // No branch filter = no restriction

  const userSnap = await db().collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("unauthenticated", "User profile not found.");
  }

  const userData = userSnap.data()!;

  // Owner/manager have unrestricted branch access
  if (userData.role === "owner" || userData.role === "manager") {
    return;
  }

  // Staff must have matching branchId or no assigned branch (access all)
  const assignedBranchId = userData.branchId as string | undefined;
  if (assignedBranchId && assignedBranchId !== branchId) {
    throw new HttpsError(
      "permission-denied",
      "You do not have access to this branch.",
    );
  }
}

/**
 * Build a branch-filtered query.
 * - Owner/manager see all branches.
 * - Staff only see their assigned branch (if branchId is set on their profile).
 */
export function applyBranchFilter(
  query: admin.firestore.Query,
  uid: string,
  businessId: string,
): Promise<admin.firestore.Query> {
  return applyBranchFilterWithField(query, uid, businessId, "branchId");
}

export async function applyBranchFilterWithField(
  query: admin.firestore.Query,
  uid: string,
  businessId: string,
  fieldName: string,
): Promise<admin.firestore.Query> {
  const userSnap = await db().collection("users").doc(uid).get();
  if (!userSnap.exists) return query;

  const userData = userSnap.data()!;

  // Owner/manager see all
  if (userData.role === "owner" || userData.role === "manager") {
    return query;
  }

  // Staff scoped to their branch
  const assignedBranchId = userData.branchId as string | undefined;
  if (assignedBranchId) {
    return query.where(fieldName, "==", assignedBranchId);
  }

  return query;
}
