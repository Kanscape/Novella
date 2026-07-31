import { Stack } from 'expo-router';

import type { BookDetailNavigationProps } from '@/components/book-detail-navigation.types';
export function BookDetailNavigation({ palette }: BookDetailNavigationProps) {
  return (
    <Stack.Screen
      options={{
        contentStyle: { backgroundColor: palette.surface },
        headerStyle: { backgroundColor: 'transparent' },
        headerTintColor: palette.primary,
        headerTransparent: true,
        title: '',
      }}
    />
  );
}
