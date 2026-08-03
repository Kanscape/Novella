import { router } from 'expo-router';
import { IconChevronRight, IconSpeakerphone } from '@tabler/icons-react-native';
import { Skeleton } from 'heroui-native';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import type {
  AnnouncementPage,
  BookListItem,
  BookListPage,
  OnlineInfo,
} from '@novella/api-client';
import type { RankPeriod } from '@novella/client-core';

import {
  BOOK_COVER_ASPECT_RATIO,
  BookCoverGridItem,
} from '@/components/book-cover-grid-item';
import { DiscoverNavigation } from '@/components/discover-navigation';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { SectionCard } from '@/components/section-card';
import { useBookGridLayout, BOOK_GRID_COLUMN_GAP } from '@/hooks/use-book-grid-layout';
import { useHomeRanking } from '@/hooks/use-ranking';
import {
  useDiscovery,
  type DiscoverySectionState,
} from '@/hooks/use-discovery';
import { colors } from '@/theme/colors';

export function HomeScreen() {
  const {
    announcements,
    latestBooks,
    onlineInfo,
    retryAnnouncements,
    retryLatestBooks,
    retryOnlineInfo,
  } = useDiscovery();

  const openProfileAndSettings = () => router.push('/settings');

  return (
    <>
      <NativeScreenScaffold
        actions={[
          {
            accessibilityLabel: 'Profile and settings',
            icon: 'userCircle',
            id: 'profile-settings',
          },
        ]}
        onActionPress={(id) => {
          if (id === 'profile-settings') openProfileAndSettings();
        }}
        title="Discover"
      >
        <ScrollView
          contentInsetAdjustmentBehavior="automatic"
          contentContainerStyle={styles.content}
          nestedScrollEnabled
          showsVerticalScrollIndicator={false}
          style={styles.root}
        >
          <RankingSection />
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Recently updated</Text>
            <Pressable
              accessibilityLabel="See all recently updated books"
              accessibilityRole="button"
              onPress={() => router.push('/recent-updates')}
              style={({ pressed }) => [styles.seeAllButton, pressed && styles.pressed]}
            >
              <Text style={styles.seeAllLabel}>See all</Text>
              <IconChevronRight color={colors.accent as string} size={18} strokeWidth={2.2} />
            </Pressable>
          </View>

          <LatestBooksSection onRetry={retryLatestBooks} state={latestBooks} />
          <AnnouncementsSection onRetry={retryAnnouncements} state={announcements} />
          <OnlineInfoSection onRetry={retryOnlineInfo} state={onlineInfo} />
        </ScrollView>
      </NativeScreenScaffold>
      <DiscoverNavigation />
    </>
  );
}

const RANK_PERIOD_LABELS: Record<RankPeriod, string> = {
  daily: 'Daily',
  weekly: 'Weekly',
  monthly: 'Monthly',
};

function RankingSection() {
  const { books, error, period, reload, retry, status } = useHomeRanking();
  const { columns, contentWidth, tileWidth } = useBookGridLayout(20);
  const previewBooks = books.slice(0, columns * 2);

  return (
    <>
      <View style={styles.sectionHeader}>
        <View style={styles.rankTitleRow}>
          <Text style={styles.sectionTitle}>Rankings</Text>
          <View style={styles.rankPeriodBadge}>
            <Text style={styles.rankPeriodLabel}>{RANK_PERIOD_LABELS[period]}</Text>
          </View>
        </View>
        <Pressable
          accessibilityLabel="See all rankings"
          accessibilityRole="button"
          onPress={() => router.push('/ranking')}
          style={({ pressed }) => [styles.seeAllButton, pressed && styles.pressed]}
        >
          <Text style={styles.seeAllLabel}>See all</Text>
          <IconChevronRight color={colors.accent as string} size={18} strokeWidth={2.2} />
        </Pressable>
      </View>

      {status === 'loading' && books.length === 0 ? (
        <BookGridPlaceholder
          columns={columns}
          tileWidth={tileWidth}
          width={contentWidth}
        />
      ) : status === 'error' && books.length === 0 ? (
        <SectionError
          description={error ?? 'The rankings are unavailable.'}
          onRetry={retry}
          title="Unable to load rankings"
        />
      ) : previewBooks.length === 0 ? (
        <SectionCard>
          <Text style={styles.cardTitle}>No rankings</Text>
          <Text style={styles.cardDescription}>
            There is no ranking data for this period right now.
          </Text>
          {status === 'error' && error ? (
            <StaleError message={error} onRetry={reload} />
          ) : null}
        </SectionCard>
      ) : (
        <View style={styles.sectionBody}>
          <BookGrid
            books={previewBooks}
            columns={columns}
            showRanks
            tileWidth={tileWidth}
            width={contentWidth}
          />
          {status === 'error' && error ? <StaleError message={error} onRetry={reload} /> : null}
        </View>
      )}
    </>
  );
}

function LatestBooksSection({
  onRetry,
  state,
}: {
  onRetry(): void;
  state: DiscoverySectionState<BookListPage>;
}) {
  const { columns, contentWidth, tileWidth } = useBookGridLayout(20);

  if (state.data === null && state.status === 'loading') {
    return (
      <BookGridPlaceholder
        columns={columns}
        tileWidth={tileWidth}
        width={contentWidth}
      />
    );
  }

  if (state.data === null) {
    return (
      <SectionError
        description={state.error ?? 'The catalog is unavailable.'}
        onRetry={onRetry}
        title="Unable to load recent updates"
      />
    );
  }

  if (state.data.items.length === 0) {
    return (
      <SectionCard>
        <Text style={styles.cardTitle}>No recent updates</Text>
        <Text style={styles.cardDescription}>
          The catalog has no new books to show right now.
        </Text>
        {state.status === 'error' ? <StaleError message={state.error} onRetry={onRetry} /> : null}
      </SectionCard>
    );
  }

  return (
    <View style={styles.sectionBody}>
      <BookGrid
        books={state.data.items}
        columns={columns}
        tileWidth={tileWidth}
        width={contentWidth}
      />
      {state.status === 'error' ? <StaleError message={state.error} onRetry={onRetry} /> : null}
    </View>
  );
}

function AnnouncementsSection({
  onRetry,
  state,
}: {
  onRetry(): void;
  state: DiscoverySectionState<AnnouncementPage>;
}) {
  return (
    <SectionCard>
      <Text style={styles.sectionTitle}>Announcements</Text>
      {state.data === null && state.status === 'loading' ? (
        <View
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
          style={styles.placeholderStack}
        >
          <SkeletonLine width="92%" />
          <SkeletonLine width="76%" />
          <SkeletonLine width="84%" />
        </View>
      ) : state.data === null ? (
        <InlineSectionError
          message={state.error ?? 'Announcements are unavailable.'}
          onRetry={onRetry}
        />
      ) : state.data.items.length === 0 ? (
        <View style={styles.placeholderStack}>
          <Text style={styles.cardDescription}>No announcements.</Text>
          {state.status === 'error' ? <StaleError message={state.error} onRetry={onRetry} /> : null}
        </View>
      ) : (
        <View style={styles.placeholderStack}>
          {state.data.items.map((announcement) => (
            <View key={announcement.id} style={styles.announcementRow}>
              <IconSpeakerphone color={colors.accent as string} size={18} strokeWidth={2.1} />
              <Text style={[styles.cardDescription, styles.flexText]}>
                {announcement.title}
              </Text>
            </View>
          ))}
          {state.status === 'error' ? <StaleError message={state.error} onRetry={onRetry} /> : null}
        </View>
      )}
    </SectionCard>
  );
}

function OnlineInfoSection({
  onRetry,
  state,
}: {
  onRetry(): void;
  state: DiscoverySectionState<OnlineInfo>;
}) {
  return (
    <SectionCard>
      <Text style={styles.sectionTitle}>Service status</Text>
      {state.data === null && state.status === 'loading' ? (
        <View
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
          style={styles.metricsRow}
        >
          <MetricPlaceholder />
          <MetricPlaceholder />
          <MetricPlaceholder />
        </View>
      ) : state.data === null ? (
        <InlineSectionError
          message={state.error ?? 'Service status is unavailable.'}
          onRetry={onRetry}
        />
      ) : (
        <View style={styles.placeholderStack}>
          <View style={styles.metricsRow}>
            <StatusMetric label="Online" value={state.data.onlineUserCount} />
            <StatusMetric label="Today" value={state.data.dayCount} />
            <StatusMetric label="New users" value={state.data.dayRegister} />
          </View>
          {state.status === 'error' ? <StaleError message={state.error} onRetry={onRetry} /> : null}
        </View>
      )}
    </SectionCard>
  );
}

function BookGrid({
  books,
  columns,
  showRanks = false,
  tileWidth,
  width,
}: {
  books: BookListItem[];
  columns: number;
  showRanks?: boolean;
  tileWidth: number;
  width: number;
}) {
  const rows = [];
  for (let index = 0; index < books.length; index += columns) {
    rows.push(books.slice(index, index + columns));
  }

  return (
    <View style={[styles.bookGrid, { width }]}>
      {rows.map((row, rowIndex) => (
        <View key={`book-row-${rowIndex}`} style={styles.bookRow}>
          {row.map((book, columnIndex) => (
            <BookCoverGridItem
              book={book}
              key={`${book.type}-${book.id}`}
              onPress={() => router.push({
                pathname: '/book/[id]',
                params: {
                  cover: book.coverUrl,
                  id: String(book.id),
                  placeholder: book.coverPlaceholder ?? '',
                  title: book.title,
                  type: book.type,
                },
              })}
              tileWidth={tileWidth}
              {...(showRanks
                ? { rank: rowIndex * columns + columnIndex + 1 }
                : {})}
            />
          ))}
          {row.length < columns ? (
            <View
              style={{ width: (columns - row.length) * (tileWidth + BOOK_GRID_COLUMN_GAP) }}
            />
          ) : null}
        </View>
      ))}
    </View>
  );
}

function BookGridPlaceholder({
  columns,
  tileWidth,
  width,
}: {
  columns: number;
  tileWidth: number;
  width: number;
}) {
  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[styles.bookGrid, { width }]}
    >
      {[0, 1].map((row) => (
        <View key={`placeholder-row-${row}`} style={styles.bookRow}>
          {Array.from({ length: columns }, (_, column) => (
            <View key={`placeholder-${row}-${column}`} style={{ gap: 7, width: tileWidth }}>
              <Skeleton
                animation={{ entering: false, exiting: false }}
                style={[
                  styles.skeletonBlock,
                  { aspectRatio: BOOK_COVER_ASPECT_RATIO, width: tileWidth },
                ]}
                variant="shimmer"
              />
              <SkeletonLine width="88%" />
              <SkeletonLine width="58%" />
            </View>
          ))}
        </View>
      ))}
    </View>
  );
}

function MetricPlaceholder() {
  return (
    <View style={styles.metric}>
      <Skeleton
        animation={{ entering: false, exiting: false }}
        style={[styles.skeletonBlock, styles.metricValuePlaceholder]}
        variant="shimmer"
      />
      <Skeleton
        animation={{ entering: false, exiting: false }}
        style={[styles.skeletonBlock, styles.metricLabelPlaceholder]}
        variant="shimmer"
      />
    </View>
  );
}

function SkeletonLine({ width }: { width: `${number}%` }) {
  return (
    <Skeleton
      animation={{ entering: false, exiting: false }}
      style={[styles.skeletonBlock, styles.skeletonLine, { width }]}
      variant="shimmer"
    />
  );
}

function SectionError({
  description,
  onRetry,
  title,
}: {
  description: string;
  onRetry(): void;
  title: string;
}) {
  return (
    <SectionCard>
      <Text style={styles.cardTitle}>{title}</Text>
      <Text selectable style={styles.cardDescription}>{description}</Text>
      <RetryButton onPress={onRetry} />
    </SectionCard>
  );
}

function InlineSectionError({ message, onRetry }: { message: string; onRetry(): void }) {
  return (
    <View style={styles.inlineError}>
      <Text selectable style={styles.cardDescription}>{message}</Text>
      <RetryButton onPress={onRetry} />
    </View>
  );
}

function StaleError({ message, onRetry }: { message: string; onRetry(): void }) {
  return (
    <Pressable
      accessibilityLabel="Refresh this section"
      accessibilityRole="button"
      onPress={onRetry}
      style={({ pressed }) => [styles.staleError, pressed && styles.pressed]}
    >
      <Text selectable style={styles.staleErrorText}>{message} Tap to retry.</Text>
    </Pressable>
  );
}

function RetryButton({ onPress }: { onPress(): void }) {
  return (
    <Pressable
      accessibilityLabel="Try again"
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.outlinedButton, pressed && styles.pressed]}
    >
      <Text style={styles.outlinedButtonLabel}>Try again</Text>
    </Pressable>
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
  flexText: {
    flex: 1,
  },
  inlineError: {
    alignItems: 'flex-start',
    gap: 10,
  },
  metadata: {
    color: colors.secondaryLabel as string,
    fontSize: 13,
  },
  metric: {
    flex: 1,
    gap: 5,
  },
  metricLabelPlaceholder: {
    height: 12,
    width: '58%',
  },
  metricValue: {
    color: colors.label as string,
    fontSize: 20,
    fontVariant: ['tabular-nums'],
    fontWeight: '700',
  },
  metricValuePlaceholder: {
    height: 24,
    width: '44%',
  },
  metricsRow: {
    flexDirection: 'row',
    gap: 14,
  },
  outlinedButton: {
    alignItems: 'center',
    borderColor: colors.separator as string,
    borderCurve: 'continuous',
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
  placeholderStack: {
    gap: 12,
  },
  pressed: {
    opacity: 0.7,
  },
  root: {
    backgroundColor: colors.background as string,
    flex: 1,
  },
  sectionBody: {
    gap: 10,
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
  rankPeriodBadge: {
    backgroundColor: colors.surfaceContainerHighest as string,
    borderRadius: 8,
    marginLeft: 8,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  rankPeriodLabel: {
    color: colors.secondaryLabel as string,
    fontSize: 13,
    fontWeight: '600',
  },
  rankTitleRow: {
    alignItems: 'center',
    flexDirection: 'row',
  },
  seeAllButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 2,
    paddingHorizontal: 4,
    paddingVertical: 4,
  },
  seeAllLabel: {
    color: colors.accent as string,
    fontSize: 15,
    fontWeight: '600',
  },
  skeletonBlock: {
    backgroundColor: colors.surfaceContainerHighest as string,
    borderCurve: 'continuous',
    borderRadius: 8,
    overflow: 'hidden',
  },
  skeletonLine: {
    height: 13,
  },
  staleError: {
    backgroundColor: colors.surfaceContainerHighest as string,
    borderCurve: 'continuous',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  staleErrorText: {
    color: colors.secondaryLabel as string,
    fontSize: 13,
    lineHeight: 18,
  },
});
