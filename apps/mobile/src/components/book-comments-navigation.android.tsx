import { Stack } from 'expo-router';

import type { BookCommentsNavigationProps } from '@/components/book-comments-navigation.types';

export function BookCommentsNavigation(_props: BookCommentsNavigationProps) {
  return (
    <Stack.Screen
      options={{
        headerShown: false,
        title: 'Comments',
      }}
    />
  );
}
