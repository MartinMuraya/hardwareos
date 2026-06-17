import * as admin from "firebase-admin";

const db = () => admin.firestore();

export const DEFAULT_PAGE_SIZE = 100;
export const MAX_PAGE_SIZE = 200;

export interface PaginationParams {
  pageSize?: number;
  lastDocId?: string;
}

export interface PaginationResult {
  lastDocId: string | null;
  hasMore: boolean;
}

export function parsePaginationParams(data: Record<string, unknown>): { pageSize: number; lastDocId?: string } {
  const requested = Number(data.pageSize) || DEFAULT_PAGE_SIZE;
  const ld = data.lastDocId as string | undefined;
  return {
    pageSize: Math.min(requested, MAX_PAGE_SIZE),
    ...(ld ? { lastDocId: ld } : {}),
  };
}

export async function applyCursorPagination<T>(
  query: admin.firestore.Query,
  lastDocId?: string,
  collectionName?: string,
): Promise<admin.firestore.Query> {
  if (!lastDocId) return query;
  const collection = collectionName ? db().collection(collectionName) : null;
  const ref = collection ? collection.doc(lastDocId) : null;
  if (ref) {
    const snap = await ref.get();
    if (snap.exists) {
      return query.startAfter(snap);
    }
  }
  return query;
}

export function buildPaginationResult<T>(
  docs: admin.firestore.DocumentData[],
  pageSize: number,
): PaginationResult {
  return {
    lastDocId: docs.length > 0 ? docs[docs.length - 1].id : null,
    hasMore: docs.length >= pageSize,
  };
}
