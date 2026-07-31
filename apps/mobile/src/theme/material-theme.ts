import {
  Hct,
  SchemeContent,
  SchemeExpressive,
  SchemeFidelity,
  SchemeFruitSalad,
  SchemeMonochrome,
  SchemeNeutral,
  SchemeRainbow,
  SchemeTonalSpot,
  SchemeVibrant,
  argbFromHex,
  type DynamicScheme,
} from '@material/material-color-utilities';

export const DEFAULT_THEME_SEED = '#B71C1C';

export const MATERIAL_SCHEME_VARIANTS = [
  'tonalSpot',
  'fidelity',
  'content',
  'monochrome',
  'neutral',
  'vibrant',
  'expressive',
  'rainbow',
  'fruitSalad',
] as const;

export type MaterialSchemeVariant = (typeof MATERIAL_SCHEME_VARIANTS)[number];

export function createMaterialScheme({
  isDark,
  seedColor,
  variant,
}: {
  isDark: boolean;
  seedColor: string;
  variant: MaterialSchemeVariant;
}): DynamicScheme {
  const sourceColor = Hct.fromInt(argbFromHex(normalizeThemeSeed(seedColor)));

  switch (variant) {
    case 'fidelity':
      return new SchemeFidelity(sourceColor, isDark, 0);
    case 'content':
      return new SchemeContent(sourceColor, isDark, 0);
    case 'monochrome':
      return new SchemeMonochrome(sourceColor, isDark, 0);
    case 'neutral':
      return new SchemeNeutral(sourceColor, isDark, 0);
    case 'vibrant':
      return new SchemeVibrant(sourceColor, isDark, 0);
    case 'expressive':
      return new SchemeExpressive(sourceColor, isDark, 0);
    case 'rainbow':
      return new SchemeRainbow(sourceColor, isDark, 0);
    case 'fruitSalad':
      return new SchemeFruitSalad(sourceColor, isDark, 0);
    case 'tonalSpot':
      return new SchemeTonalSpot(sourceColor, isDark, 0);
  }
}

export function isMaterialSchemeVariant(value: unknown): value is MaterialSchemeVariant {
  return typeof value === 'string'
    && (MATERIAL_SCHEME_VARIANTS as readonly string[]).includes(value);
}

export function isThemeSeed(value: unknown): value is string {
  return typeof value === 'string' && /^#[0-9A-Fa-f]{6}$/.test(value);
}

export function normalizeThemeSeed(value: string): string {
  return isThemeSeed(value) ? value.toUpperCase() : DEFAULT_THEME_SEED;
}
