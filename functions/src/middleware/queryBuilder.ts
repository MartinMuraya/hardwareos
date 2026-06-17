import * as admin from "firebase-admin";
import { parsePaginationParams, applyCursorPagination, buildPaginationResult, PaginationParams, PaginationResult, MAX_PAGE_SIZE } from "./pagination";

const db = () => admin.firestore();

// ==============================================================
// Soft-Delete Query Builder
// ==============================================================
// Guarantees every list query automatically filters isActive == true
// unless explicitly overridden by passing includeInactive: true.
// ==============================================================

export interface QueryOptions extends PaginationParams {
  includeInactive?: boolean;
}

export interface QueryResult<T> {
  data: T[];
  pagination: PaginationResult;
}

/**
 * Build a Firestore query for soft-deletable collections.
 * Automatically adds `.where("isActive", "==", true)` for tenant-scoped collections.
 */
export function activeQuery(
  collectionPath: string,
  options?: { includeInactive?: boolean },
): admin.firestore.Query {
  let query: admin.firestore.Query = db().collection(collectionPath);
  if (!options?.includeInactive) {
    query = query.where("isActive", "==", true);
  }
  return query;
}

/**
 * Build a tenant-scoped query that filters by businessId AND isActive.
 * This is the standard pattern for 95% of list endpoints.
 */
export function businessQuery(
  collectionPath: string,
  businessId: string,
  options?: { includeInactive?: boolean },
): admin.firestore.Query {
  let query: admin.firestore.Query = db()
    .collection(collectionPath)
    .where("businessId", "==", businessId);
  if (!options?.includeInactive) {
    query = query.where("isActive", "==", true);
  }
  return query;
}

/**
 * Executes a paginated, soft-delete-aware list query.
 * Returns typed data + pagination metadata.
 */
export async function executeListQuery<T>(
  collectionPath: string,
  businessId: string | null,
  options: QueryOptions,
  buildQuery?: (base: admin.firestore.Query) => admin.firestore.Query,
  serialize?: (doc: admin.firestore.DocumentSnapshot) => T,
): Promise<QueryResult<T>> {
  const { pageSize, lastDocId } = parsePaginationParams(options as Record<string, unknown>);
  const includeInactive = options.includeInactive ?? false;

  let query: admin.firestore.Query;
  if (businessId) {
    query = businessQuery(collectionPath, businessId, { includeInactive });
  } else {
    query = activeQuery(collectionPath, { includeInactive });
  }

  if (buildQuery) {
    query = buildQuery(query);
  }

  query = query.limit(pageSize);

  if (lastDocId) {
    const cursor = await db().collection(collectionPath).doc(lastDocId).get();
    if (cursor.exists) {
      query = query.startAfter(cursor);
    }
  }

  const snap = await query.get();

  const serializeFn = serialize || ((doc) => ({ id: doc.id, ...doc.data() } as unknown as T));
  const data = snap.docs.map(serializeFn);

  return {
    data,
    pagination: buildPaginationResult(snap.docs, pageSize),
  };
}

export { parsePaginationParams, applyCursorPagination, buildPaginationResult, MAX_PAGE_SIZE };
export type { PaginationParams, PaginationResult };
