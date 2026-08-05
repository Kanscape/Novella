import { createExpoStorage } from '@/adapters/expo-runtime';
import {
  addSearchHistoryItem,
  normalizeSearchHistory,
} from '@/services/search-history-utils';

const SEARCH_HISTORY_KEY = 'novella.search-history.v1';
const storage = createExpoStorage();
let writeQueue = Promise.resolve();

export async function loadSearchHistory(): Promise<string[]> {
  const encoded = await storage.get(SEARCH_HISTORY_KEY);
  if (!encoded) return [];
  try {
    const value: unknown = JSON.parse(encoded);
    if (!Array.isArray(value)) return [];
    return normalizeSearchHistory(value.filter((item): item is string => typeof item === 'string'));
  } catch {
    return [];
  }
}

export { mergeSearchHistory } from '@/services/search-history-utils';

export function saveSearchHistory(items: readonly string[]): Promise<void> {
  const normalized = normalizeSearchHistory(items);
  const write = writeQueue.then(() =>
    storage.set(SEARCH_HISTORY_KEY, JSON.stringify(normalized)),
  );
  writeQueue = write.catch(() => undefined);
  return write;
}

export function addSearchHistory(
  items: readonly string[],
  query: string,
): string[] {
  const next = addSearchHistoryItem(items, query);
  if (next.length === items.length && next.every((item, index) => item === items[index])) {
    return next;
  }
  // History persistence is intentionally fire-and-forget. Search requests are
  // interactive work and must not wait for local storage before entering the
  // loading state or reaching the network.
  void saveSearchHistory(next).catch(() => undefined);
  return next;
}
