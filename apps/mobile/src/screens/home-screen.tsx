import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { IconRefresh, IconSpeakerphone } from '@tabler/icons-react-native';
import { router } from 'expo-router';

import type { DiscoverySnapshot } from '@novella/client-core';

import { BookCoverGridItem } from '@/components/book-cover-grid-item';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { SectionCard } from '@/components/section-card';
import { useDiscovery } from '@/hooks/use-discovery';
import { colors } from '@/theme/colors';

export function HomeScreen() {
  const { error, isLoading, isRefreshing, reload, snapshot } = useDiscovery();

  return (
    <NativeScreenScaffold title="Discover">
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={styles.content}
        nestedScrollEnabled
        showsVerticalScrollIndicator={false}
        style={styles.root}
      >
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Recently updated</Text>
          <Pressable
            accessibilityLabel={isRefreshing ? 'Updating' : 'Refresh'}
            accessibilityRole="button"
            disabled={isLoading || isRefreshing}
            onPress={reload}
            style={({ pressed }) => [styles.refreshButton, pressed && styles.pressed]}
          >
            {/* react-native-svg's SDK 57 ColorValue type omits literal colors. */}
            <IconRefresh color={colors.accent as string} size={17} strokeWidth={2.25} />
            <Text style={styles.refreshLabel}>{isRefreshing ? 'Updating' : 'Refresh'}</Text>
          </Pressable>
        </View>

        {isLoading ? <LoadingState /> : null}

        {error ? (
          <SectionCard>
            <Text style={styles.cardTitle}>Unable to load discovery</Text>
            <Text style={styles.cardDescription}>{error}</Text>
            <Pressable
              accessibilityLabel="Try again"
              accessibilityRole="button"
              onPress={reload}
              style={({ pressed }) => [styles.outlinedButton, pressed && styles.pressed]}
            >
              <Text style={styles.outlinedButtonLabel}>Try again</Text>
            </Pressable>
          </SectionCard>
        ) : null}

        {snapshot ? <DiscoveryContent snapshot={snapshot} /> : null}
      </ScrollView>
    </NativeScreenScaffold>
  );
}

function DiscoveryContent({ snapshot }: { snapshot: DiscoverySnapshot }) {
  const { width } = useWindowDimensions();
  const contentWidth = Math.max(1, width - 40);
  const tileWidth = Math.floor((contentWidth - 20) / 3);
  const imageHeight = Math.max(120, Math.round(tileWidth / 0.58 - 36));

  return (
    <View style={styles.contentSections}>
      {snapshot.latestBooks.items.length === 0 ? (
        <SectionCard>
          <Text style={styles.cardTitle}>No recent updates</Text>
          <Text style={styles.cardDescription}>
            The catalog has no new books to show right now.
          </Text>
        </SectionCard>
      ) : (
        <BookGrid
          books={snapshot.latestBooks.items}
          imageHeight={imageHeight}
          tileWidth={tileWidth}
          width={contentWidth}
        />
      )}

      <SectionCard>
        <Text style={styles.sectionTitle}>Announcements</Text>
        {snapshot.announcements.items.length === 0 ? (
          <Text style={styles.cardDescription}>No announcements.</Text>
        ) : (
          snapshot.announcements.items.map((announcement) => (
            <View key={announcement.id} style={styles.announcementRow}>
              <IconSpeakerphone color={colors.accent as string} size={18} strokeWidth={2.1} />
              <Text style={styles.cardDescription}>{announcement.title}</Text>
            </View>
          ))
        )}
      </SectionCard>

      <SectionCard>
        <Text style={styles.sectionTitle}>Service status</Text>
        <View style={styles.metricsRow}>
          <StatusMetric label="Online" value={snapshot.onlineInfo.onlineUserCount} />
          <StatusMetric label="Today" value={snapshot.onlineInfo.dayCount} />
          <StatusMetric label="New users" value={snapshot.onlineInfo.dayRegister} />
        </View>
      </SectionCard>
    </View>
  );
}

function BookGrid({
  books,
  imageHeight,
  tileWidth,
  width,
}: {
  books: DiscoverySnapshot['latestBooks']['items'];
  imageHeight: number;
  tileWidth: number;
  width: number;
}) {
  const rows = [];
  for (let index = 0; index < books.length; index += 3) {
    rows.push(books.slice(index, index + 3));
  }

  return (
    <View style={[styles.bookGrid, { width }]}>
      {rows.map((row, rowIndex) => (
        <View key={`book-row-${rowIndex}`} style={styles.bookRow}>
          {row.map((book) => (
            <BookCoverGridItem
              book={book}
              imageHeight={imageHeight}
              key={`${book.type}-${book.id}`}
              onPress={() => router.push({ pathname: '/book/[id]', params: { id: String(book.id) } })}
              tileWidth={tileWidth}
            />
          ))}
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
        <Text style={styles.cardDescription}>Loading the latest catalog...</Text>
      </View>
    </SectionCard>
  );
}

function StatusMetric({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricValue}>{String(value)}</Text>
      <Text style={styles.metadata}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  announcementRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
  },
  bookGrid: {
    gap: 12,
  },
  bookRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
  },
  cardDescription: {
    color: colors.secondaryLabel as string,
    fontSize: 15,
    lineHeight: 21,
  },
  cardTitle: {
    color: colors.label as string,
    fontSize: 17,
    fontWeight: '700',
    lineHeight: 22,
  },
  content: {
    gap: 18,
    paddingBottom: 120,
    paddingHorizontal: 20,
    paddingTop: 20,
  },
  contentSections: {
    gap: 18,
  },
  loadingRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
  },
  metadata: {
    color: colors.secondaryLabel as string,
    fontSize: 13,
  },
  metric: {
    flex: 1,
    gap: 3,
  },
  metricValue: {
    color: colors.label as string,
    fontSize: 20,
    fontWeight: '700',
  },
  metricsRow: {
    flexDirection: 'row',
    gap: 14,
  },
  outlinedButton: {
    alignItems: 'center',
    borderColor: colors.separator as string,
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  outlinedButtonLabel: {
    color: colors.accent as string,
    fontSize: 15,
    fontWeight: '600',
  },
  pressed: {
    opacity: 0.7,
  },
  refreshButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 5,
    paddingHorizontal: 4,
    paddingVertical: 4,
  },
  refreshLabel: {
    color: colors.accent as string,
    fontSize: 15,
    fontWeight: '600',
  },
  root: {
    backgroundColor: colors.background as string,
    flex: 1,
  },
  sectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    color: colors.label as string,
    fontSize: 21,
    fontWeight: '700',
  },
});
