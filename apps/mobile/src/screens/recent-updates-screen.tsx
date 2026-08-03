import { router } from 'expo-router';
import { IconRefreshOff } from '@tabler/icons-react-native';
import {
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';

import type { BookListItem } from '@novella/api-client';

import {
  BookCoverGridItem,
} from '@/components/book-cover-grid-item';
import {
  BookCoverSkeletonTile,
  bookGridLoadingMoreKeys,
  bookGridSkeletonCount,
  skeletonKeys,
} from '@/components/book-grid-skeleton';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { useBookGridLayout } from '@/hooks/use-book-grid-layout';
import { useRecentUpdates } from '@/hooks/use-recent-updates';
import { colors } from '@/theme/colors';

export function RecentUpdatesScreen() {
  const {
    books,
    error,
    loadMore,
    refresh,
    retry,
    status,
  } = useRecentUpdates();
  const { columns, contentWidth, height, tileWidth } = useBookGridLayout(20);
  const skeletonCount =
    status === 'loading' && books.length === 0
      ? bookGridSkeletonCount({ columns, headerOffset: 110, height, tileWidth })
      : 0;
  // While loading more, complete the current last row (missing slots) and add
  // one full skeleton row, as list items so the FlatList's own layout
  // arranges them exactly like the real grid.
  const loadingMoreKeys =
    status === 'loadingMore'
      ? bookGridLoadingMoreKeys(books.length, columns)
      : [];
  const data: (number | BookListItem)[] = [
    ...(skeletonCount > 0 ? skeletonKeys(skeletonCount) : books),
    ...loadingMoreKeys,
  ];

  return (
    <NativeScreenScaffold
      largeTitle={false}
      onBackPress={() => router.back()}
      showBackButton
      title="Recently updated"
    >
      <View style={styles.root}>
        <FlatList
          ListEmptyComponent={
            error ? (
              <ErrorState error={error} onRetry={retry} />
            ) : (
              <EmptyState />
            )
          }
          columnWrapperStyle={styles.row}
          contentContainerStyle={styles.content}
          contentInsetAdjustmentBehavior="automatic"
          data={data}
          keyExtractor={(item) =>
            typeof item === 'number'
              ? `skeleton-${item}`
              : `${item.type ?? 'Novel'}-${item.id}`
          }
          nestedScrollEnabled
          numColumns={columns}
          onEndReached={loadMore}
          onEndReachedThreshold={0.6}
          refreshControl={
            <RefreshControl
              colors={[colors.accent as string]}
              onRefresh={refresh}
              refreshing={status === 'refreshing'}
              tintColor={colors.accent as string}
            />
          }
          renderItem={({ item }) =>
            typeof item === 'number' ? (
              <BookCoverSkeletonTile tileWidth={tileWidth} />
            ) : (
              <BookCoverGridItem
                book={item}
                onPress={() => router.push({
                  pathname: '/book/[id]',
                  params: {
                    cover: item.coverUrl,
                    id: String(item.id),
                    placeholder: item.coverPlaceholder ?? '',
                    title: item.title,
                    type: item.type ?? 'Novel',
                  },
                })}
                tileWidth={tileWidth}
              />
            )
          }
          showsVerticalScrollIndicator={false}
        />
      </View>
    </NativeScreenScaffold>
  );
}

function EmptyState() {
  return (
    <View style={styles.emptyState}>
      <IconRefreshOff color={colors.secondaryLabel as string} size={44} strokeWidth={1.5} />
      <Text style={styles.emptyTitle}>No recent updates</Text>
      <Text style={styles.emptyDescription}>
        The catalog has no new books to show right now.
      </Text>
    </View>
  );
}

function ErrorState({ error, onRetry }: { error: string; onRetry(): void }) {
  return (
    <View style={styles.errorBlock}>
      <Text selectable style={styles.errorText}>{error}</Text>
      <Pressable
        accessibilityLabel="Try again"
        accessibilityRole="button"
        onPress={onRetry}
        style={({ pressed }) => [styles.retryButton, pressed && styles.pressed]}
      >
        <Text style={styles.retryLabel}>Try again</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  content: {
    gap: 12,
    paddingBottom: 40,
    paddingHorizontal: 20,
    paddingTop: 16,
  },
  emptyDescription: {
    color: colors.secondaryLabel as string,
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
  },
  emptyState: {
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 32,
    paddingTop: 72,
  },
  emptyTitle: {
    color: colors.label as string,
    fontSize: 17,
    fontWeight: '700',
  },
  errorBlock: {
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 24,
    paddingTop: 72,
  },
  errorText: {
    color: colors.secondaryLabel as string,
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
  },
  pressed: {
    opacity: 0.7,
  },
  retryButton: {
    alignItems: 'center',
    borderColor: colors.separator as string,
    borderCurve: 'continuous',
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  retryLabel: {
    color: colors.accent as string,
    fontSize: 15,
    fontWeight: '600',
  },
  root: {
    backgroundColor: colors.background as string,
    flex: 1,
  },
  row: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
  },
});
