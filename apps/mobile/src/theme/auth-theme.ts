import type { ColorSchemeName } from 'react-native';

import { useAppColorScheme } from '@/theme/app-theme';

export type AuthPalette = {
  accent: string;
  background: string;
  border: string;
  error: string;
  foreground: string;
  isDark: boolean;
  onAccent: string;
  placeholder: string;
  secondary: string;
  skeleton: string;
  skeletonHighlight: string;
  surface: string;
  welcomeGradient: readonly [string, string, string, string, string];
};

const darkPalette: AuthPalette = {
  accent: '#FF375F',
  background: '#000000',
  border: '#54545899',
  error: '#FF453A',
  foreground: '#FFFFFF',
  isDark: true,
  onAccent: '#FFFFFF',
  placeholder: '#EBEBF54D',
  secondary: '#EBEBF599',
  skeleton: '#2C2C2E',
  skeletonHighlight: '#48484A',
  surface: '#1C1C1E',
  welcomeGradient: ['rgba(0,0,0,0.01)', 'rgba(0,0,0,0.08)', 'rgba(0,0,0,0.58)', '#000000', '#000000'],
};

const lightPalette: AuthPalette = {
  accent: '#FF2D55',
  background: '#FFFFFF',
  border: '#3C3C434A',
  error: '#FF3B30',
  foreground: '#000000',
  isDark: false,
  onAccent: '#FFFFFF',
  placeholder: '#3C3C434D',
  secondary: '#3C3C4399',
  skeleton: '#E5E5EA',
  skeletonHighlight: '#F2F2F7',
  surface: '#F2F2F7',
  welcomeGradient: ['rgba(255,255,255,0.01)', 'rgba(255,255,255,0.08)', 'rgba(255,255,255,0.58)', '#FFFFFF', '#FFFFFF'],
};

export function getAuthPalette(colorScheme: ColorSchemeName): AuthPalette {
  return colorScheme === 'dark' ? darkPalette : lightPalette;
}

export function useAuthPalette(): AuthPalette {
  return getAuthPalette(useAppColorScheme());
}
