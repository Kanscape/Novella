import { Stack } from 'expo-router';

import type { ShelfNavigationProps } from '@/components/shelf-navigation.types';

export function ShelfNavigation({ onManage, title }: ShelfNavigationProps) {
  return (
    <>
      <Stack.Screen options={{ headerLargeTitle: true, title }} />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button
          accessibilityLabel="Manage shelf"
          icon="ellipsis.circle"
          onPress={onManage}
        />
      </Stack.Toolbar>
    </>
  );
}
