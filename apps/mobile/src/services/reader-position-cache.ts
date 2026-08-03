import { createExpoStorage } from '@/adapters/expo-runtime';

export interface CachedReaderPosition {
  chapterId: number;
  position: string;
  syncState: 'pending' | 'synced';
  updatedAt: string;
}

export interface ReaderPositionValue {
  chapterId: number;
  position: string;
}

type ReaderPositionListener = (position: CachedReaderPosition) => void;

const storage = createExpoStorage();
const memoryCache = new Map<number, CachedReaderPosition | null>();
const writeTails = new Map<number, Promise<void>>();
const stagedSessionPositions = new Map<number, CachedReaderPosition>();
const listeners = new Map<number, Set<ReaderPositionListener>>();

export async function getCachedReaderPosition(bookId: number): Promise<CachedReaderPosition | null> {
  await writeTails.get(bookId)?.catch(() => undefined);
  if (memoryCache.has(bookId)) return memoryCache.get(bookId) ?? null;
  const value = await readStoredPosition(bookId);
  memoryCache.set(bookId, value);
  return value;
}

/**
 * Publish the visible position synchronously. This closes the navigation-focus
 * race: the detail screen can observe the new chapter before a debounced disk
 * or SignalR write gets its first microtask.
 */
export function stageCachedReaderPosition(
  bookId: number,
  position: ReaderPositionValue,
): CachedReaderPosition {
  const current = memoryCache.get(bookId) ?? null;
  if (current && positionsEqual(current, position)) {
    stagedSessionPositions.set(bookId, current);
    notifyPositionListeners(bookId, current);
    return current;
  }

  const currentTimestamp = current ? Date.parse(current.updatedAt) : 0;
  const updatedAt = new Date(Math.max(Date.now(), currentTimestamp + 1)).toISOString();
  const next: CachedReaderPosition = {
    chapterId: position.chapterId,
    position: position.position,
    syncState: 'pending',
    updatedAt,
  };
  memoryCache.set(bookId, next);
  stagedSessionPositions.set(bookId, next);
  notifyPositionListeners(bookId, next);
  return next;
}

/** Persist the newest staged checkpoint, never an older queued checkpoint. */
export function persistLatestCachedReaderPosition(bookId: number): Promise<void> {
  return enqueueCacheOperation(bookId, async () => {
    const current = memoryCache.has(bookId)
      ? memoryCache.get(bookId) ?? null
      : await readStoredPosition(bookId);
    if (!current) return;
    await writeStoredPosition(bookId, current);
  });
}

export function markCachedReaderPositionSynced(
  bookId: number,
  expected: CachedReaderPosition,
): Promise<void> {
  return enqueueCacheOperation(bookId, async () => {
    const current = memoryCache.has(bookId)
      ? memoryCache.get(bookId) ?? null
      : await readStoredPosition(bookId);
    if (!current || current.updatedAt !== expected.updatedAt) return;
    const synced: CachedReaderPosition = { ...current, syncState: 'synced' };
    memoryCache.set(bookId, synced);
    await writeStoredPosition(bookId, synced);
    notifyPositionListeners(bookId, synced);
  });
}

/**
 * Resolve one cache against one server checkpoint without a time heuristic.
 * Pending/current-session data wins only until the server echoes that exact
 * canonical chapter and position. Matching server data immediately clears the
 * session barrier; after a cold start, acknowledged server data wins directly.
 */
export function shouldUseCachedReaderPosition(
  bookId: number,
  cached: CachedReaderPosition,
  server: ReaderPositionValue | null,
): boolean {
  const serverMatches = server?.chapterId === cached.chapterId &&
    server.position === cached.position;
  const staged = stagedSessionPositions.get(bookId);
  const stagedMatches = staged?.updatedAt === cached.updatedAt;

  if (serverMatches) {
    if (stagedMatches) stagedSessionPositions.delete(bookId);
    return false;
  }
  if (server === null || cached.syncState === 'pending') return true;
  return stagedMatches;
}

export function subscribeCachedReaderPosition(
  bookId: number,
  listener: ReaderPositionListener,
): () => void {
  const bookListeners = listeners.get(bookId) ?? new Set<ReaderPositionListener>();
  bookListeners.add(listener);
  listeners.set(bookId, bookListeners);
  return () => {
    bookListeners.delete(listener);
    if (bookListeners.size === 0) listeners.delete(bookId);
  };
}

async function readStoredPosition(bookId: number): Promise<CachedReaderPosition | null> {
  const encoded = await storage.get(storageKey(bookId));
  if (!encoded) return null;
  try {
    const value = JSON.parse(encoded) as Partial<CachedReaderPosition>;
    if (typeof value.chapterId !== 'number' || typeof value.position !== 'string') return null;
    return {
      chapterId: value.chapterId,
      position: value.position,
      syncState: value.syncState === 'pending' ? 'pending' : 'synced',
      updatedAt: typeof value.updatedAt === 'string' ? value.updatedAt : new Date(0).toISOString(),
    };
  } catch {
    return null;
  }
}

function writeStoredPosition(bookId: number, position: CachedReaderPosition): Promise<void> {
  return storage.set(storageKey(bookId), JSON.stringify(position));
}

function storageKey(bookId: number): string {
  return `novella.reader-position.${bookId}`;
}

function positionsEqual(
  left: CachedReaderPosition,
  right: ReaderPositionValue,
): boolean {
  return left.chapterId === right.chapterId && left.position === right.position;
}

function notifyPositionListeners(bookId: number, position: CachedReaderPosition): void {
  listeners.get(bookId)?.forEach((listener) => listener(position));
}

function enqueueCacheOperation<T>(bookId: number, operation: () => Promise<T>): Promise<T> {
  const previous = writeTails.get(bookId) ?? Promise.resolve();
  const next = previous.catch(() => undefined).then(operation);
  const settled = next.then(() => undefined, () => undefined);
  writeTails.set(bookId, settled);
  void settled.finally(() => {
    if (writeTails.get(bookId) === settled) writeTails.delete(bookId);
  });
  return next;
}
