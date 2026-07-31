import { Stack, router } from 'expo-router';

import type { BookDetailNavigationProps } from '@/components/book-detail-navigation.types';
export function BookDetailNavigation({ book, palette }: BookDetailNavigationProps) {
  return (
    <>
      <Stack.Screen
        options={{
          contentStyle: { backgroundColor: palette.surface },
          headerStyle: { backgroundColor: 'transparent' },
          headerBackVisible: false,
          headerTintColor: palette.primary,
          headerTransparent: true,
          title: '',
        }}
      />
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button
          accessibilityLabel="Back"
          icon="chevron.left"
          onPress={() => router.back()}
          tintColor={palette.primary}
        />
      </Stack.Toolbar>
      {book ? (
        <Stack.Toolbar placement="right">
          <Stack.Toolbar.Button
            hidden={book.classification.tags.length === 0}
            icon="tag"
            tintColor={palette.primary}
            onPress={() =>
              router.push({ pathname: '/book/[id]/tags', params: { id: String(book.id) } })
            }
          />
          <Stack.Toolbar.Button
            icon="bubble.left"
            tintColor={palette.primary}
            onPress={() =>
              router.push({ pathname: '/book/[id]/comments', params: { id: String(book.id) } })
            }
          />
          <Stack.Toolbar.Button
            icon="person.crop.rectangle"
            tintColor={palette.primary}
            onPress={() =>
              router.push({ pathname: '/book/[id]/uploader', params: { id: String(book.id) } })
            }
          />
        </Stack.Toolbar>
      ) : null}
    </>
  );
}
