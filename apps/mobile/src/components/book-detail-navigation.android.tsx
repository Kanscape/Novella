import { Stack, router } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { IconMessage, IconTag, IconUserScreen } from '@tabler/icons-react-native';

import type { BookDetail } from '@novella/api-client';

import type { BookDetailNavigationProps } from '@/components/book-detail-navigation.types';

export function BookDetailNavigation({ book, palette }: BookDetailNavigationProps) {
  return (
    <Stack.Screen
      options={{
        contentStyle: { backgroundColor: palette.surface },
        headerShadowVisible: false,
        headerStyle: { backgroundColor: 'transparent' },
        headerTintColor: palette.onSurface,
        headerTransparent: true,
        ...(book ? { headerRight: () => <AndroidHeaderActions book={book} palette={palette} showTags={book.classification.tags.length > 0} /> } : {}),
        title: '',
      }}
    />
  );
}

function AndroidHeaderActions({ book, palette, showTags }: { book: BookDetail; palette: BookDetailNavigationProps['palette']; showTags: boolean }) {
  return (
    <View style={styles.actions}>
      {showTags ? (
        <HeaderAction
          accessibilityLabel="Book tags"
          color={palette.onSurface}
          icon={IconTag}
          onPress={() =>
            router.push({
              pathname: '/book/[id]/tags',
              params: { id: String(book.id), ...(book.type ? { type: book.type } : {}) },
            })
          }
        />
      ) : null}
      <HeaderAction
        accessibilityLabel="Comments"
        color={palette.onSurface}
        icon={IconMessage}
        onPress={() =>
          router.push({ pathname: '/book/[id]/comments', params: { id: String(book.id) } })
        }
      />
      <HeaderAction
        accessibilityLabel="Uploader information"
        color={palette.onSurface}
        icon={IconUserScreen}
        onPress={() =>
          router.push({
            pathname: '/book/[id]/uploader',
            params: { id: String(book.id), ...(book.type ? { type: book.type } : {}) },
          })
        }
      />
    </View>
  );
}

function HeaderAction({
  accessibilityLabel,
  color,
  icon: Icon,
  onPress,
}: {
  accessibilityLabel: string;
  color: string;
  icon: typeof IconMessage;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.action, pressed && styles.pressed]}
    >
      <Icon color={color} size={24} strokeWidth={2} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  action: { alignItems: 'center', height: 48, justifyContent: 'center', width: 48 },
  actions: { alignItems: 'center', flexDirection: 'row', marginRight: -12 },
  pressed: { opacity: 0.6 },
});
