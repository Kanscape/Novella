import { useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { IconArrowLeft, IconBook2, IconFolderOpen, IconRefresh } from '@tabler/icons-react-native';

import type { BookListItem, ShelfItem } from '@novella/api-client';
import type { ShelfSnapshot } from '@novella/client-core';

import { BookCoverGridItem } from '@/components/book-cover-grid-item';
import { ShelfFolderGridItem } from '@/components/shelf-grid-item';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { SectionCard } from '@/components/section-card';
import { useShelf } from '@/hooks/use-shelf';
import { colors } from '@/theme/colors';
import { router } from 'expo-router';

export function ShelfScreen() {
  const { error, isLoading, isRefreshing, reload, snapshot } = useShelf();
  const [parents, setParents] = useState<string[]>([]);

  return (
    <NativeScreenScaffold title="Shelf">
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={styles.content}
        nestedScrollEnabled
        showsVerticalScrollIndicator={false}
        style={styles.root}
      >
        <View style={styles.sectionHeader}>
          <View style={styles.headingBlock}>
            {parents.length > 0 ? (
              <Pressable
                accessibilityLabel="Back to parent folder"
                accessibilityRole="button"
                onPress={() => setParents((current) => current.slice(0, -1))}
                style={({ pressed }) => [styles.backButton, pressed && styles.pressed]}
              >
                <IconArrowLeft color={colors.accent as string} size={17} strokeWidth={2.1} />
                <Text style={styles.backLabel}>Shelf</Text>
              </Pressable>
            ) : null}
            <Text style={styles.sectionTitle}>{getFolderHeading(snapshot, parents)}</Text>
          </View>
          <Pressable
            accessibilityLabel={isRefreshing ? 'Updating shelf' : 'Refresh shelf'}
            accessibilityRole="button"
            disabled={isLoading || isRefreshing}
            onPress={reload}
            style={({ pressed }) => [styles.refreshButton, pressed && styles.pressed]}
          >
            <IconRefresh color={colors.accent as string} size={17} strokeWidth={2.25} />
            <Text style={styles.refreshLabel}>{isRefreshing ? 'Updating' : 'Refresh'}</Text>
          </Pressable>
        </View>

        {isLoading ? <LoadingState /> : null}
        {error ? <ErrorState error={error} onRetry={reload} /> : null}
        {snapshot ? (
          <ShelfContent parents={parents} setParents={setParents} snapshot={snapshot} />
        ) : null}
      </ScrollView>
    </NativeScreenScaffold>
  );
}

function ShelfContent({
  parents,
  setParents,
  snapshot,
}: {
  parents: string[];
  setParents: React.Dispatch<React.SetStateAction<string[]>>;
  snapshot: ShelfSnapshot;
}) {
  const { width } = useWindowDimensions();
  const contentWidth = Math.max(1, width - 40);
  const tileWidth = Math.floor((contentWidth - 20) / 3);
  const imageHeight = Math.max(150, Math.round(tileWidth * 1.5));
  const booksById = new Map(snapshot.books.map((book) => [book.id, book]));
  const visibleItems = snapshot.items.filter((item) => sameParents(item.parents, parents));

  if (visibleItems.length === 0) {
    return <EmptyShelfState nested={parents.length > 0} />;
  }

  const rows: ShelfItem[][] = [];
  for (let index = 0; index < visibleItems.length; index += 3) {
    rows.push(visibleItems.slice(index, index + 3));
  }

  return (
    <View style={[styles.grid, { width: contentWidth }]}>
      {rows.map((row, rowIndex) => (
        <View key={`shelf-row-${rowIndex}`} style={styles.gridRow}>
          {row.map((item) => {
            if (item.type === 'FOLDER') {
              const folderParents = [...parents, item.id];
              const previewBooks = snapshot.items
                .filter(
                  (child): child is Extract<ShelfItem, { type: 'BOOK' }> =>
                    child.type === 'BOOK' && sameParents(child.parents, folderParents),
                )
                .map((child) => booksById.get(child.id))
                .filter((book): book is BookListItem => book !== undefined);
              const itemCount = snapshot.items.filter((child) =>
                sameParents(child.parents, folderParents),
              ).length;
              return (
                <ShelfFolderGridItem
                  imageHeight={imageHeight}
                  itemCount={itemCount}
                  key={`folder-${item.id}`}
                  onPress={() => setParents((current) => [...current, item.id])}
                  previewBooks={previewBooks}
                  tileWidth={tileWidth}
                  title={item.title.trim() || 'Unnamed folder'}
                />
              );
            }

            const book = booksById.get(item.id);
            return book ? (
              <BookCoverGridItem
                book={book}
                imageHeight={imageHeight}
                key={`book-${item.id}`}
                onPress={() => router.push({ pathname: '/book/[id]', params: { id: String(item.id) } })}
                tileWidth={tileWidth}
              />
            ) : (
              <UnavailableBookGridItem key={`missing-book-${item.id}`} tileWidth={tileWidth} />
            );
          })}
          {row.length < 3 ? <View style={{ width: (3 - row.length) * (tileWidth + 10) }} /> : null}
        </View>
      ))}
    </View>
  );
}

function LoadingState() {
  return (
    <SectionCard>
      <View style={styles.loadingRow}>
        <ActivityIndicator color={colors.accent as string} />
        <Text style={styles.cardDescription}>Loading your shelf...</Text>
      </View>
    </SectionCard>
  );
}

function ErrorState({ error, onRetry }: { error: string; onRetry: () => void }) {
  return (
    <SectionCard>
      <Text style={styles.cardTitle}>Unable to load your shelf</Text>
      <Text style={styles.cardDescription}>{error}</Text>
      <Pressable
        accessibilityLabel="Try again"
        accessibilityRole="button"
        onPress={onRetry}
        style={({ pressed }) => [styles.retryButton, pressed && styles.pressed]}
      >
        <IconRefresh color={colors.accent as string} size={17} strokeWidth={2} />
        <Text style={styles.retryLabel}>Try again</Text>
      </Pressable>
    </SectionCard>
  );
}

function EmptyShelfState({ nested }: { nested: boolean }) {
  return (
    <SectionCard>
      <View style={styles.emptyState}>
        <IconFolderOpen color={colors.accent as string} size={38} strokeWidth={1.8} />
        <Text style={styles.cardTitle}>{nested ? 'This folder is empty' : 'Your shelf is empty'}</Text>
        <Text style={styles.cardDescription}>
          {nested
            ? 'Books added to this folder will appear here.'
            : 'Add a book from Discover to start building your shelf.'}
        </Text>
      </View>
    </SectionCard>
  );
}

function UnavailableBookGridItem({ tileWidth }: { tileWidth: number }) {
  return (
    <View style={[styles.unavailableItem, { width: tileWidth }]}>
      <View style={[styles.unavailableCover, { height: Math.round(tileWidth * 1.5), width: tileWidth }]}>
        <IconBook2 color={colors.secondaryLabel as string} size={32} strokeWidth={1.8} />
      </View>
      <Text numberOfLines={2} style={styles.unavailableTitle}>Unavailable book</Text>
    </View>
  );
}

function getFolderHeading(snapshot: ShelfSnapshot | null, parents: string[]): string {
  if (parents.length === 0 || !snapshot) return 'Your shelf';
  const folder = snapshot.items.find(
    (item): item is Extract<ShelfItem, { type: 'FOLDER' }> =>
      item.type === 'FOLDER' && item.id === parents[parents.length - 1],
  );
  return folder?.title.trim() || 'Unnamed folder';
}

function sameParents(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

const styles = StyleSheet.create({
  backButton: { alignItems: 'center', flexDirection: 'row', gap: 5, paddingVertical: 3 },
  backLabel: { color: colors.accent as string, fontSize: 14, fontWeight: '600' },
  cardDescription: { color: colors.secondaryLabel as string, fontSize: 15, lineHeight: 21 },
  cardTitle: { color: colors.label as string, fontSize: 17, fontWeight: '700', lineHeight: 22 },
  content: { gap: 18, paddingBottom: 120, paddingHorizontal: 20, paddingTop: 20 },
  emptyState: { alignItems: 'center', gap: 10, paddingVertical: 18 },
  grid: { gap: 12 },
  gridRow: { alignItems: 'flex-start', flexDirection: 'row', gap: 10, justifyContent: 'space-between' },
  headingBlock: { flex: 1, gap: 5 },
  loadingRow: { alignItems: 'center', flexDirection: 'row', gap: 10 },
  pressed: { opacity: 0.7 },
  refreshButton: { alignItems: 'center', flexDirection: 'row', gap: 5, paddingHorizontal: 4, paddingVertical: 4 },
  refreshLabel: { color: colors.accent as string, fontSize: 15, fontWeight: '600' },
  retryButton: { alignItems: 'center', flexDirection: 'row', gap: 6, paddingVertical: 4 },
  retryLabel: { color: colors.accent as string, fontSize: 15, fontWeight: '600' },
  root: { backgroundColor: colors.background as string, flex: 1 },
  sectionHeader: { alignItems: 'flex-start', flexDirection: 'row', justifyContent: 'space-between' },
  sectionTitle: { color: colors.label as string, fontSize: 21, fontWeight: '700' },
  unavailableCover: { alignItems: 'center', backgroundColor: colors.card as string, borderColor: colors.separator as string, borderRadius: 12, borderWidth: 0.5, justifyContent: 'center' },
  unavailableItem: { alignItems: 'center' },
  unavailableTitle: { color: colors.secondaryLabel as string, fontSize: 13, lineHeight: 16, paddingHorizontal: 2, paddingTop: 8, textAlign: 'center' },
});
