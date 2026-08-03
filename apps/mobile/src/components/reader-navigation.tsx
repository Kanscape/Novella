import { Stack } from 'expo-router';

import type { ReaderNavigationProps } from '@/components/reader-navigation.types';

export function ReaderNavigation({
  backgroundColor,
  foregroundColor,
  title,
}: ReaderNavigationProps) {
  return (
    <Stack.Screen
      options={{
        contentStyle: { backgroundColor },
        headerBackButtonDisplayMode: 'minimal',
        headerShadowVisible: false,
        headerStyle: { backgroundColor },
        headerTintColor: foregroundColor,
        title,
      }}
    />
  );
}
