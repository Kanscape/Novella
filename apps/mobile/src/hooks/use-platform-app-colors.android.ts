import { useMaterialColors } from '@expo/ui/jetpack-compose';
import { useMemo } from 'react';

import type { AppColors } from '@/theme/app-colors';
import type { AppColorScheme } from '@/theme/theme-mode';

export function usePlatformAppColors({
  colorScheme,
  seedColor,
  useSystemColor,
  oledBlack,
}: {
  colorScheme: AppColorScheme;
  seedColor: string;
  useSystemColor: boolean;
  oledBlack: boolean;
}): AppColors {
  const material = useMaterialColors({
    colorScheme,
    ...(!useSystemColor ? { seedColor } : {}),
  });

  // OLED dark replaces the neutral surface/typography roles with pure black
  // and near-black grays (mirroring the book-detail OLED palette constants),
  // while the accent/error/container roles keep the Material values. This
  // makes every RN page (shelf, home, search, …) honor OLED black, not just
  // the reader and detail pages.
  const isOledDark = colorScheme === 'dark' && oledBlack;

  return useMemo(() => isOledDark
    ? {
        accent: material.primary,
        background: '#000000',
        card: '#0E1014',
        error: material.error,
        label: '#EFEFEF',
        onPrimaryContainer: material.onPrimaryContainer,
        primaryContainer: material.primaryContainer,
        secondaryLabel: '#C7C7C7',
        separator: '#252525',
        surface: '#000000',
        surfaceContainerHighest: '#1A1A1A',
      }
    : {
        accent: material.primary,
        background: material.background,
        card: material.surfaceContainer,
        error: material.error,
        label: material.onSurface,
        onPrimaryContainer: material.onPrimaryContainer,
        primaryContainer: material.primaryContainer,
        secondaryLabel: material.onSurfaceVariant,
        separator: material.outlineVariant,
        surface: material.surface,
        surfaceContainerHighest: material.surfaceContainerHighest,
      }, [
      isOledDark,
      material.background,
      material.error,
      material.onPrimaryContainer,
      material.onSurface,
      material.onSurfaceVariant,
      material.outlineVariant,
      material.primary,
      material.primaryContainer,
      material.surface,
      material.surfaceContainer,
      material.surfaceContainerHighest,
    ]);
}
