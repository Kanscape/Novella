import { useMemo } from 'react';

import type { AppColors } from '@/theme/app-colors';
import type { AppColorScheme } from '@/theme/theme-mode';

export function usePlatformAppColors({ colorScheme, oledBlack }: {
  colorScheme: AppColorScheme;
  seedColor: string;
  useSystemColor: boolean;
  oledBlack: boolean;
}): AppColors {
  return useMemo(() => colorScheme === 'dark'
    ? {
        accent: '#FF8A9A',
        background: '#111318',
        card: '#1D2026',
        error: '#FFB4AB',
        label: '#E2E2E9',
        onPrimaryContainer: '#FFD9DF',
        primaryContainer: '#8C1D36',
        secondaryLabel: '#C5C6CF',
        separator: '#45464F',
        surface: '#111318',
        surfaceContainerHighest: '#33343B',
      }
    : {
        accent: '#B71C1C',
        background: '#F7F8FA',
        card: '#FFFFFF',
        error: '#BA1A1A',
        label: '#20242A',
        onPrimaryContainer: '#63001E',
        primaryContainer: '#FFD9DF',
        secondaryLabel: '#656B74',
        separator: '#D9DDE3',
        surface: '#FFFFFF',
        surfaceContainerHighest: '#ECEEF2',
      }, [colorScheme, oledBlack]);
}
