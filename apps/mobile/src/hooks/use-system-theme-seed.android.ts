import { useMaterialColors } from '@expo/ui/jetpack-compose';

export function useSystemThemeSeed(colorScheme: 'light' | 'dark'): string | null {
  const materialColors = useMaterialColors({ colorScheme });
  return materialColors.primary.slice(0, 7);
}
