import type { BookCategory } from '@novella/api-client';

export type BookBadgeIconKey =
  'ai' | 'edit' | 'hexagon' | 'japanese' | 'original' | 'repost' | 'translate';

export interface BookBadgeDefinition {
  backgroundColor: string;
  borderColor?: string;
  icon: BookBadgeIconKey;
  iconColor: string;
  id: string;
  label: string;
  level?: number;
  meaning: string;
  names: readonly string[];
  shortNames: readonly string[];
}

const RECORDED_BADGE: BookBadgeDefinition = {
  backgroundColor: '#EC1282',
  icon: 'edit',
  iconColor: '#FFFFFF',
  id: 'recorded',
  label: 'Recorded',
  meaning: 'Human-entered content is complete',
  names: ['录入完成'],
  shortNames: ['录入', '录入完成'],
};

const TRANSLATED_BADGE: BookBadgeDefinition = {
  backgroundColor: '#1976D2',
  icon: 'translate',
  iconColor: '#FFFFFF',
  id: 'translated',
  label: 'Translated',
  meaning: 'Human translation is complete',
  names: ['翻译完成'],
  shortNames: ['翻译', '翻译完成'],
};

const REPOST_BADGE: BookBadgeDefinition = {
  backgroundColor: '#F1570E',
  icon: 'repost',
  iconColor: '#FFFFFF',
  id: 'repost',
  label: 'Repost',
  meaning: 'Reposted work',
  names: ['转载'],
  shortNames: ['转载'],
};

const ORIGINAL_BADGE: BookBadgeDefinition = {
  backgroundColor: '#7B1FA2',
  icon: 'original',
  iconColor: '#FFFFFF',
  id: 'original',
  label: 'Original',
  meaning: 'Original work',
  names: ['原创'],
  shortNames: ['原创'],
};

const JAPANESE_BADGE: BookBadgeDefinition = {
  backgroundColor: '#C62828',
  icon: 'japanese',
  iconColor: '#FFFFFF',
  id: 'japanese',
  label: 'Japanese',
  meaning: 'Original Japanese content',
  names: ['日文原版'],
  shortNames: ['日文', '日原', '日文原版'],
};

const AI_BADGE: BookBadgeDefinition = {
  backgroundColor: '#2EAF5D',
  icon: 'ai',
  iconColor: '#FFFFFF',
  id: 'ai',
  label: 'AI',
  meaning: 'Machine-assisted generation or translation',
  names: ['AI翻译'],
  shortNames: ['AI', 'AI翻译'],
};

const RECORDING_BADGE: BookBadgeDefinition = {
  backgroundColor: '#9E9E9E',
  icon: 'edit',
  iconColor: '#FFFFFF',
  id: 'recording',
  label: 'Recording',
  meaning: 'Entry is still in progress',
  names: ['录入中'],
  shortNames: ['录入中'],
};

const TRANSLATING_BADGE: BookBadgeDefinition = {
  backgroundColor: '#9E9E9E',
  icon: 'translate',
  iconColor: '#FFFFFF',
  id: 'translating',
  label: 'Translating',
  meaning: 'Translation is still in progress',
  names: ['翻译中'],
  shortNames: ['翻译中'],
};

const LEVEL_BADGE: BookBadgeDefinition = {
  backgroundColor: '#E0A106',
  icon: 'hexagon',
  iconColor: '#FFFFFF',
  id: 'level',
  label: 'Level',
  level: 6,
  meaning:
    'Permission-controlled content\nThe second icon shows the actual Level',
  names: [],
  shortNames: [],
};

const INTERIOR_LEVEL_BADGE: BookBadgeDefinition = {
  backgroundColor: '#FFFFFF',
  borderColor: '#E0A106',
  icon: 'hexagon',
  iconColor: '#E0A106',
  id: 'interior-level',
  label: 'InteriorLevel',
  level: 6,
  meaning:
    'Group-only permission content\nThe second icon shows the actual InteriorLevel',
  names: [],
  shortNames: [],
};

const CATEGORY_BADGE_DEFINITIONS = [
  RECORDED_BADGE,
  TRANSLATED_BADGE,
  REPOST_BADGE,
  ORIGINAL_BADGE,
  JAPANESE_BADGE,
  AI_BADGE,
  RECORDING_BADGE,
  TRANSLATING_BADGE,
] as const;

export const BOOK_BADGE_LEGEND_DEFINITIONS = [
  ...CATEGORY_BADGE_DEFINITIONS,
  LEVEL_BADGE,
  INTERIOR_LEVEL_BADGE,
] as const;

export function resolveBookCategoryBadge(
  category: BookCategory | null,
): BookBadgeDefinition | null {
  if (!category) return null;
  const name = category.name.trim();
  const shortName = category.shortName.trim();
  return (
    CATEGORY_BADGE_DEFINITIONS.find(
      (definition) =>
        definition.names.includes(name) ||
        definition.shortNames.includes(shortName),
    ) ?? null
  );
}

export function resolveBookLevelBadge({
  interiorLevel,
  level,
}: {
  interiorLevel: number | null;
  level: number | null;
}): BookBadgeDefinition | null {
  const effectiveLevel =
    interiorLevel && interiorLevel > 0 ? interiorLevel : level;
  if (!effectiveLevel || effectiveLevel <= 0) return null;

  const definition =
    interiorLevel && interiorLevel > 0 ? INTERIOR_LEVEL_BADGE : LEVEL_BADGE;
  return {
    ...definition,
    level: clampBookBadgeLevel(effectiveLevel),
  };
}

function clampBookBadgeLevel(level: number): number {
  return Math.min(6, Math.max(1, Math.trunc(level)));
}
