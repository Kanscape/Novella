import { useEffect, useMemo, useRef, useState } from 'react';
import { useColorScheme } from 'react-native';

import { useAppSettings } from '@/services/settings';
import {
  createBookDetailTheme,
  interpolateBookDetailTheme,
  type BookDetailTheme,
} from '@/theme/book-detail-theme';
import { useSystemThemeSeed } from '@/hooks/use-system-theme-seed';

export function useBookDetailTheme(coverUrl: string | null, coverPlaceholder: string | null) {
  const colorScheme = useColorScheme();
  const settings = useAppSettings();
  const systemColorScheme = colorScheme === 'dark' ? 'dark' : 'light';
  const effectiveColorScheme = settings.theme === 'system'
    ? systemColorScheme
    : settings.theme;
  const systemThemeSeed = useSystemThemeSeed(effectiveColorScheme);
  const useSystemThemeSeedValue = settings.useSystemColor && systemThemeSeed !== null;
  const colorProfile = effectiveColorScheme === 'dark'
    ? settings.oledBlack ? 'oledBlack' : 'dark'
    : 'light';

  return useMemo(
    () => createBookDetailTheme({
      colorProfile,
      coverColorExtraction: settings.coverColorExtraction,
      coverPlaceholder,
      coverUrl,
      dynamicSchemeVariant: useSystemThemeSeedValue
        ? 'tonalSpot'
        : settings.dynamicSchemeVariant,
      themeSeedColor: useSystemThemeSeedValue
        ? systemThemeSeed
        : settings.seedColorValue,
    }),
    [
      colorProfile,
      coverPlaceholder,
      coverUrl,
      settings.coverColorExtraction,
      settings.dynamicSchemeVariant,
      settings.seedColorValue,
      systemThemeSeed,
      useSystemThemeSeedValue,
    ],
  );
}

export function useAnimatedBookDetailTheme(
  targetTheme: BookDetailTheme,
  animateChanges: boolean,
): BookDetailTheme {
  const [theme, setTheme] = useState(targetTheme);
  const currentTheme = useRef(targetTheme);

  useEffect(() => {
    if (!animateChanges) {
      currentTheme.current = targetTheme;
      setTheme(targetTheme);
      return;
    }

    const fromTheme = currentTheme.current;
    const startedAt = performance.now();
    let animationFrame = 0;

    const update = (timestamp: number) => {
      const progress = Math.min(1, (timestamp - startedAt) / 600);
      const eased = progress < 0.5
        ? 4 * progress * progress * progress
        : 1 - Math.pow(-2 * progress + 2, 3) / 2;
      const nextTheme = interpolateBookDetailTheme(fromTheme, targetTheme, eased);
      currentTheme.current = nextTheme;
      setTheme(nextTheme);
      if (progress < 1) animationFrame = requestAnimationFrame(update);
    };

    animationFrame = requestAnimationFrame(update);
    return () => cancelAnimationFrame(animationFrame);
  }, [animateChanges, targetTheme]);

  return theme;
}
