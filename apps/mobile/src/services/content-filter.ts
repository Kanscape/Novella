import type { BookCategory, BookListItem } from '@novella/api-client';

const JAPANESE_CATEGORY_NAMES = new Set(['日文原版']);
const JAPANESE_CATEGORY_SHORT_NAMES = new Set(['日文', '日原', '日文原版']);
const AI_CATEGORY_NAMES = new Set(['AI翻译']);
const AI_CATEGORY_SHORT_NAMES = new Set(['AI', 'AI翻译']);

export interface ContentFilterOptions {
  ignoreAI: boolean;
  ignoreJapanese: boolean;
  ignoreLevel6: boolean;
}

/** Content-settings filter shared by discovery, ranking, catalog, and search.
 * Mirrors Flutter's filterBooksByContentSettings. The backend accepts the
 * Japanese/AI flags for some requests, but Level 6 has no request flag and
 * every filtered list still applies the same client-side rules. */
export function filterBooksByContentSettings(
  items: BookListItem[],
  options: ContentFilterOptions,
): BookListItem[] {
  if (!options.ignoreJapanese && !options.ignoreAI && !options.ignoreLevel6) {
    return items;
  }

  return items.filter((item) => {
    if (options.ignoreLevel6 && item.level === 6) {
      return false;
    }

    const category = item.category;
    if (category === null) {
      return true;
    }

    if (options.ignoreJapanese && matchesCategory(category, {
      names: JAPANESE_CATEGORY_NAMES,
      shortNames: JAPANESE_CATEGORY_SHORT_NAMES,
    })) {
      return false;
    }

    if (options.ignoreAI && matchesCategory(category, {
      names: AI_CATEGORY_NAMES,
      shortNames: AI_CATEGORY_SHORT_NAMES,
    })) {
      return false;
    }

    return true;
  });
}

function matchesCategory(
  category: BookCategory,
  targets: { names: Set<string>; shortNames: Set<string> },
): boolean {
  const name = category.name.trim();
  const shortName = category.shortName.trim();
  return targets.names.has(name) || targets.shortNames.has(shortName);
}
