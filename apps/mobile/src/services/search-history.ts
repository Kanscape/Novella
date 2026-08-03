import { createExpoStorage } from '@/adapters/expo-runtime';

const SEARCH_HISTORY_KEY = 'novella.search-history.v1';
const MAX_SEARCH_HISTORY_ITEMS = 20;
const storage = createExpoStorage();
let writeQueue = Promise.resolve();

export async function loadSearchHistory(): Promise<string[]> {
  const encoded = await storage.get(SEARCH_HISTORY_KEY);
  if (!encoded) return [];
  try {
    const value: unknown = JSON.parse(encoded);
    if (!Array.isArray(value)) return [];
    return value.filter((item): item is string =>
      typeof item === 'string' && item.trim().length > 0,
    ).slice(0, MAX_SEARCH_HISTORY_ITEMS);
  } catch {
    return [];
  }
}

export function saveSearchHistory(items: readonly string[]): Promise<void> {
  const normalized = [...new Set(items.map((item) => item.trim()).filter(Boolean))]
    .slice(0, MAX_SEARCH_HISTORY_ITEMS);
  const write = writeQueue.then(() =>
    storage.set(SEARCH_HISTORY_KEY, JSON.stringify(normalized)),
  );
  writeQueue = write.catch(() => undefined);
  return write;
}

export async function addSearchHistory(
  items: readonly string[],
  query: string,
): Promise<string[]> {
  const normalized = query.trim();
  if (!normalized) return [...items];
  const next = [normalized, ...items.filter((item) => item !== normalized)]
    .slice(0, MAX_SEARCH_HISTORY_ITEMS);
  await saveSearchHistory(next);
  return next;
}
