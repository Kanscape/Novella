import { Stack } from 'expo-router';

import type { BookCommentsNavigationProps } from '@/components/book-comments-navigation.types';

export function BookCommentsNavigation({ onCompose }: BookCommentsNavigationProps) {
  return (
    <Stack.Screen
      options={{
        headerRight: () => null,
        title: 'Comments',
      }}
    />
  );
}
