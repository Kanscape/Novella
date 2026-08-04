import type { ThemeMode } from '@/services/settings';

export type AppColorScheme = 'light' | 'dark';

export function resolveAppColorScheme(
  theme: ThemeMode,
  systemColorScheme: string | null | undefined,
): AppColorScheme {
  if (theme === 'light' || theme === 'dark') return theme;
  return systemColorScheme === 'dark' ? 'dark' : 'light';
}

export function resolveReaderColors({
  backgroundColor,
  colorScheme,
  oledBlack,
  textColor,
}: {
  backgroundColor: string;
  colorScheme: AppColorScheme;
  oledBlack: boolean;
  textColor: string;
}): { backgroundColor: string; textColor: string } {
  if (colorScheme === 'dark' && oledBlack) {
    return { backgroundColor: '#000000', textColor: '#FFFFFF' };
  }
  return { backgroundColor, textColor };
}
