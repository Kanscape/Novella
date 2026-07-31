import { Stack } from 'expo-router';

import type { BookCommentsNavigationProps } from '@/components/book-comments-navigation.types';

export function BookCommentsNavigation({ onCompose, palette }: BookCommentsNavigationProps) {
  return (
    <>
      <Stack.Screen
        options={{
          headerTintColor: palette.primary,
          title: 'Comments',
        }}
      />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button
          accessibilityLabel="Write a comment"
          icon="pencil"
          onPress={onCompose}
          tintColor={palette.primary}
        />
      </Stack.Toolbar>
    </>
  );
}
