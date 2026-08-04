import { Uniwind } from 'uniwind';
import {
  createContext,
  type PropsWithChildren,
  useContext,
  useLayoutEffect,
  useMemo,
} from 'react';
import { StyleSheet, useColorScheme } from 'react-native';

import { usePlatformAppColors } from '@/hooks/use-platform-app-colors';
import { useAppSettings } from '@/services/settings';
import type { AppColors } from '@/theme/app-colors';
import { resolveAppColorScheme, type AppColorScheme } from '@/theme/theme-mode';

interface AppThemeContextValue {
  colorScheme: AppColorScheme;
  colors: AppColors;
  /** True when the effective appearance is dark and OLED black is active
   * (Android only — iOS always uses the system semantic palette). Lets
   * Compose chrome (top bars) opt into the pure-black container. */
  isOledDark: boolean;
}

const AppThemeContext = createContext<AppThemeContextValue | null>(null);

export function AppThemeProvider({ children }: PropsWithChildren) {
  const settings = useAppSettings();
  const systemColorScheme = useColorScheme();
  const colorScheme = resolveAppColorScheme(settings.theme, systemColorScheme);
  const isOledDark = process.env.EXPO_OS === 'android'
    && colorScheme === 'dark'
    && settings.oledBlack;
  const colors = usePlatformAppColors({
    colorScheme,
    oledBlack: settings.oledBlack,
    seedColor: settings.seedColorValue,
    useSystemColor: settings.useSystemColor,
  });

  useLayoutEffect(() => {
    Uniwind.setTheme(settings.theme);
  }, [settings.theme]);

  const value = useMemo<AppThemeContextValue>(
    () => ({ colorScheme, colors, isOledDark }),
    [colorScheme, colors, isOledDark],
  );

  return <AppThemeContext value={value}>{children}</AppThemeContext>;
}

export function useAppTheme(): AppThemeContextValue {
  const context = useContext(AppThemeContext);
  if (!context) throw new Error('useAppTheme requires AppThemeProvider');
  return context;
}

export function useAppColorScheme(): AppColorScheme {
  return useAppTheme().colorScheme;
}

export function createThemedStyles<T extends StyleSheet.NamedStyles<T>>(
  factory: (colors: AppColors) => T,
): () => T {
  return function useThemedStyles() {
    const { colors } = useAppTheme();
    return useMemo(() => StyleSheet.create(factory(colors)), [colors]);
  };
}
