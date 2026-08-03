import { Stack } from 'expo-router';

import type { HistoryNavigationProps } from '@/components/history-navigation.types';

export function HistoryNavigation({ onClear, showClear }: HistoryNavigationProps) {
  return showClear ? (
    <Stack.Toolbar placement="right">
      <Stack.Toolbar.Button
        accessibilityLabel="Clear reading history"
        icon="trash"
        onPress={onClear}
      />
    </Stack.Toolbar>
  ) : null;
}
