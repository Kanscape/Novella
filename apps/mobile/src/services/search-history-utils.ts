export const SEARCH_HISTORY_LIMIT = 20;

export function mergeSearchHistory(...lists: readonly (readonly string[])[]): string[] {
  return normalizeSearchHistory(lists.flat());
}

export function addSearchHistoryItem(
  items: readonly string[],
  query: string,
): string[] {
  const normalized = query.trim();
  if (!normalized) return normalizeSearchHistory(items);
  return mergeSearchHistory([normalized], items);
}

export function normalizeSearchHistory(items: readonly string[]): string[] {
  return [...new Set(items.map((item) => item.trim()).filter(Boolean))]
    .slice(0, SEARCH_HISTORY_LIMIT);
}
