import { reader } from '@/services/client';
import {
  type CachedReaderPosition,
  markCachedReaderPositionSynced,
  persistLatestCachedReaderPosition,
  stageCachedReaderPosition,
} from '@/services/reader-position-cache';

export interface ReaderProgressUpdate {
  bookId: number;
  chapterId: number;
  position: string;
}

export interface ReaderProgressCheckpoint extends ReaderProgressUpdate {
  cached: CachedReaderPosition;
}

const syncTails = new Map<number, Promise<void>>();

/** Immediately publish local progress before debounce, navigation, or network. */
export function stageReaderProgress(update: ReaderProgressUpdate): ReaderProgressCheckpoint {
  return {
    ...update,
    cached: stageCachedReaderPosition(update.bookId, update),
  };
}

/**
 * Serializes server writes per book across screen instances. The newest staged
 * cache value is durable before network work; an old acknowledgement cannot
 * mark a newer cached position as synchronized.
 */
export function syncReaderProgress(checkpoint: ReaderProgressCheckpoint): Promise<void> {
  const previous = syncTails.get(checkpoint.bookId) ?? Promise.resolve();
  const operation = previous.catch(() => undefined).then(async () => {
    await persistLatestCachedReaderPosition(checkpoint.bookId);
    if (checkpoint.cached.syncState === 'synced') return;
    await reader.savePosition({
      bookId: checkpoint.bookId,
      chapterId: checkpoint.chapterId,
      position: checkpoint.position,
    });
    await markCachedReaderPositionSynced(checkpoint.bookId, checkpoint.cached);
  });
  const settled = operation.then(() => undefined, () => undefined);
  syncTails.set(checkpoint.bookId, settled);
  void settled.finally(() => {
    if (syncTails.get(checkpoint.bookId) === settled) syncTails.delete(checkpoint.bookId);
  });
  return operation;
}
