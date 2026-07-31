import { Color } from 'expo-router';
import { Platform } from 'react-native';

export const colors = {
  accent: Platform.select({
    ios: Color.ios.systemPink,
    android: Color.android.dynamic.primary,
    default: '#d9475d',
  })!,
  background: Platform.select({
    ios: Color.ios.systemGroupedBackground,
    android: Color.android.dynamic.surface,
    default: '#f7f8fa',
  })!,
  surface: Platform.select({
    ios: Color.ios.systemBackground,
    android: Color.android.dynamic.surface,
    default: '#ffffff',
  })!,
  card: Platform.select({
    ios: Color.ios.secondarySystemGroupedBackground,
    android: Color.android.dynamic.surfaceContainer,
    default: '#ffffff',
  })!,
  surfaceContainerHighest: Platform.select({
    ios: Color.ios.tertiarySystemGroupedBackground,
    android: Color.android.dynamic.surfaceContainerHighest,
    default: '#eceef2',
  })!,
  primaryContainer: Platform.select({
    ios: Color.ios.systemPink,
    android: Color.android.dynamic.primaryContainer,
    default: '#ffd9df',
  })!,
  onPrimaryContainer: Platform.select({
    ios: '#ffffff',
    android: Color.android.dynamic.onPrimaryContainer,
    default: '#63001e',
  })!,
  error: Platform.select({
    ios: Color.ios.systemRed,
    android: Color.android.dynamic.error,
    default: '#ba1a1a',
  })!,
  label: Platform.select({
    ios: Color.ios.label,
    android: Color.android.dynamic.onSurface,
    default: '#20242a',
  })!,
  secondaryLabel: Platform.select({
    ios: Color.ios.secondaryLabel,
    android: Color.android.dynamic.onSurfaceVariant,
    default: '#656b74',
  })!,
  separator: Platform.select({
    ios: Color.ios.separator,
    android: Color.android.dynamic.outlineVariant,
    default: '#d9dde3',
  })!,
};
