import { Image } from 'expo-image';
import { router } from 'expo-router';
import {
  useCallback,
  useRef,
  useState,
  type ComponentProps,
  type ComponentType,
  type ReactNode,
} from 'react';
import { ScrollViewMarker } from 'react-native-screens/experimental';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  ScrollView,
  StyleSheet,
  View,
  useWindowDimensions,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
  type ViewStyle,
} from 'react-native';
import Animated, {
  interpolate,
  useAnimatedRef,
  useAnimatedStyle,
  useScrollViewOffset,
  type SharedValue,
} from 'react-native-reanimated';
import {
  ActivityIndicator,
  Button,
  IconButton,
  PaperProvider,
  Surface,
  Text,
  TouchableRipple,
} from 'react-native-paper';
import {
  IconBookmark,
  IconBookmarkFilled,
  IconBooks,
  IconEye,
  IconHeart,
  IconPlayerPlayFilled,
  IconProgressBolt,
} from '@tabler/icons-react-native';

import type { BookDetail } from '@novella/api-client';

import { BookDetailNavigation } from '@/components/book-detail-navigation';
import { useBookDetailRouteTheme } from '@/components/book-detail-theme-provider';
import { BookHtmlContent } from '@/components/book-html-content';
import { useBookDetail } from '@/hooks/use-book-detail';
import {
  extractCoverBlurHash,
  type BookDetailPalette,
} from '@/theme/book-detail-theme';

export interface BookDetailScreenProps {
  bookId: number;
}

type TablerIcon = ComponentType<ComponentProps<typeof IconHeart>>;

const BOOK_HERO_HEIGHT = 280;
const BOOK_HERO_TOOLBAR_HEIGHT = 56;
const BOOK_HERO_COLLAPSE_DISTANCE = BOOK_HERO_HEIGHT - BOOK_HERO_TOOLBAR_HEIGHT;

export function BookDetailScreen({ bookId }: BookDetailScreenProps) {
  const {
    book,
    error,
    isInShelf,
    isLoading,
    isShelfLoading,
    reload,
    requiresAuth,
    shelfError,
    toggleShelf,
  } = useBookDetail(bookId);
  const detailTheme = useBookDetailRouteTheme(bookId, book?.coverUrl ?? null);
  const [usesSoftScrollEdge, setUsesSoftScrollEdge] = useState(false);

  return (
    <PaperProvider theme={detailTheme.paperTheme}>
      <View style={[styles.root, { backgroundColor: detailTheme.palette.surface }]}>
        <BookDetailNavigation book={book} palette={detailTheme.palette} />
        {isLoading ? <BookDetailLoading palette={detailTheme.palette} /> : null}
        {error ? (
          <BookDetailError
            error={error}
            onRetry={reload}
            palette={detailTheme.palette}
            requiresAuth={requiresAuth}
          />
        ) : null}
        {book ? (
          <BookDetailContent
            book={book}
            isInShelf={isInShelf}
            usesSoftScrollEdge={usesSoftScrollEdge}
            isShelfLoading={isShelfLoading}
            onToggleShelf={toggleShelf}
            onScrollEdgeChange={setUsesSoftScrollEdge}
            palette={detailTheme.palette}
            shelfError={shelfError}
          />
        ) : null}
      </View>
    </PaperProvider>
  );
}

function BookDetailContent({
  book,
  isInShelf,
  usesSoftScrollEdge,
  isShelfLoading,
  onToggleShelf,
  onScrollEdgeChange,
  palette,
  shelfError,
}: {
  book: BookDetail;
  isInShelf: boolean;
  usesSoftScrollEdge: boolean;
  isShelfLoading: boolean;
  onToggleShelf: () => Promise<void>;
  onScrollEdgeChange: (usesSoftScrollEdge: boolean) => void;
  palette: BookDetailPalette;
  shelfError: string | null;
}) {
  const { bottom: bottomInset, top: topInset } = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const scrollRef = useAnimatedRef<Animated.ScrollView>();
  const scrollOffset = useScrollViewOffset(scrollRef);
  const horizontalPadding = Math.max(20, (width - 640) / 2);
  const contentWidth = Math.max(1, width - horizontalPadding * 2);
  const currentSortNum = getCurrentSortNum(book);
  const resumeChapter = currentSortNum ? book.chapters[currentSortNum - 1] : undefined;
  const startSortNum = currentSortNum ?? 1;
  const latestChapter = book.chapters.at(-1)?.title ?? book.lastUpdatedChapter;
  const usesCollapsibleAppBar = process.env.EXPO_OS === 'android';
  const usesSoftScrollEdgeRef = useRef(usesSoftScrollEdge);
  const handleScroll = useCallback((offsetY: number) => {
    if (process.env.EXPO_OS !== 'ios') return;

    if (!usesSoftScrollEdgeRef.current && offsetY >= BOOK_HERO_COLLAPSE_DISTANCE) {
      usesSoftScrollEdgeRef.current = true;
      onScrollEdgeChange(true);
    } else if (usesSoftScrollEdgeRef.current && offsetY <= 1) {
      usesSoftScrollEdgeRef.current = false;
      onScrollEdgeChange(false);
    }
  }, [onScrollEdgeChange]);

  return (
    <View style={styles.detailContent}>
      <ScrollViewMarker
        scrollEdgeEffects={{ top: usesSoftScrollEdge ? 'soft' : 'hidden' }}
        style={styles.scrollViewMarker}
      >
        <Animated.ScrollView
          bounces={false}
          contentInsetAdjustmentBehavior="never"
          onScroll={({ nativeEvent }: NativeSyntheticEvent<NativeScrollEvent>) =>
            handleScroll(nativeEvent.contentOffset.y)
          }
          overScrollMode="never"
          ref={scrollRef}
          scrollEventThrottle={16}
          showsVerticalScrollIndicator={false}
          style={{ backgroundColor: palette.surface }}
        >
          {usesCollapsibleAppBar ? (
            <View style={{ height: BOOK_HERO_HEIGHT + topInset }} />
          ) : (
            <InlineBookHero
              book={book}
              horizontalPadding={horizontalPadding}
              palette={palette}
              scrollOffset={scrollOffset}
              topInset={topInset}
            />
          )}

      <View style={[styles.body, { paddingHorizontal: horizontalPadding }]}>
        <View style={styles.chips}>
          <MetaChip icon={IconHeart} palette={palette} value={formatCount(book.favoriteCount)} />
          <MetaChip icon={IconEye} palette={palette} value={formatCount(book.viewCount)} />
          <MetaChip icon={IconBooks} palette={palette} value={`${book.chapters.length} chapters`} />
        </View>

        <View style={styles.actions}>
          <IconButton
            accessibilityLabel={isInShelf ? 'Remove from shelf' : 'Add to shelf'}
            containerColor={isInShelf ? palette.primaryContainer : palette.surfaceContainerHighest}
            disabled={isShelfLoading}
            icon={() =>
              isInShelf ? (
                <IconBookmarkFilled color={palette.onPrimaryContainer} size={25} />
              ) : (
                <IconBookmark color={palette.onSurfaceVariant} size={25} strokeWidth={2} />
              )
            }
            loading={isShelfLoading}
            onPress={() => void onToggleShelf()}
            size={25}
            style={styles.shelfButton}
          />

          <Button
            accessibilityLabel={resumeChapter ? `Continue reading ${resumeChapter.title}` : 'Start reading'}
            buttonColor={palette.primary}
            contentStyle={styles.readButtonContent}
            disabled={book.chapters.length === 0}
            icon={({ color }) => <IconPlayerPlayFilled color={color} size={22} />}
            labelStyle={styles.readButtonLabel}
            mode="contained"
            onPress={() => openReader(book.id, startSortNum)}
            style={styles.readButton}
            textColor={palette.onPrimary}
          >
            {resumeChapter ? `Continue · ${shortenChapterTitle(resumeChapter.title)}` : 'Start reading'}
          </Button>
        </View>

        {shelfError ? (
          <Text style={[styles.actionError, { color: palette.error }]}>{shelfError}</Text>
        ) : null}

        {book.introduction.trim() ? (
          <View style={styles.introductionSection}>
            <SectionTitle palette={palette}>Introduction</SectionTitle>
            <TouchableRipple
              accessibilityLabel="Open full introduction"
              accessibilityRole="button"
              borderless
              onPress={() =>
                router.push({
                  pathname: '/book/[id]/introduction',
                  params: { id: String(book.id) },
                })
              }
              rippleColor={hexWithAlpha(palette.primary, 0.08)}
              style={styles.introductionPreview}
            >
              <View
                style={[
                  styles.introductionClip,
                  /<ruby[\s>]/iu.test(book.introduction) && styles.introductionClipWithRuby,
                ]}
              >
                <BookHtmlContent
                  contentWidth={contentWidth}
                  html={book.introduction}
                  preview
                  textColor={palette.onSurfaceVariant}
                />
              </View>
            </TouchableRipple>
          </View>
        ) : null}

        <Surface
          elevation={0}
          style={[
            styles.updateInfo,
            !book.introduction.trim() && styles.updateInfoWithoutIntroduction,
            { backgroundColor: hexWithAlpha(palette.surfaceContainerHighest, 0.5) },
          ]}
        >
          <IconProgressBolt color={palette.onSurfaceVariant} size={18} strokeWidth={2} />
          <Text numberOfLines={1} style={[styles.updateText, { color: palette.onSurfaceVariant }]}>
            {latestChapter
              ? `Latest: ${formatRelativeTime(book.lastUpdatedAt)} - ${latestChapter}`
              : `Latest: ${formatRelativeTime(book.lastUpdatedAt)}`}
          </Text>
        </Surface>

        <SectionTitle palette={palette}>Chapters</SectionTitle>
      </View>

      <View style={[styles.chapterList, { paddingHorizontal: horizontalPadding - 12 }]}>
        {book.chapters.map((chapter, index) => {
          const sortNum = index + 1;
          const isCurrent = sortNum === currentSortNum;
          return (
            <TouchableRipple
              accessibilityLabel={`Read chapter ${sortNum}, ${chapter.title}`}
              accessibilityRole="button"
              key={chapter.id}
              onPress={() => openReader(book.id, sortNum)}
              rippleColor={hexWithAlpha(palette.primary, 0.1)}
            >
              <View style={styles.chapterRow}>
                <View style={styles.chapterNumberSlot}>
                  <Text
                    style={[
                      styles.chapterNumber,
                      { color: isCurrent ? palette.primary : palette.onSurfaceVariant },
                      isCurrent && styles.currentChapterText,
                    ]}
                  >
                    {sortNum}
                  </Text>
                </View>
                <Text
                  numberOfLines={1}
                  style={[
                    styles.chapterTitle,
                    { color: isCurrent ? palette.primary : palette.onSurface },
                    isCurrent && styles.currentChapterTitle,
                  ]}
                >
                  {chapter.title}
                </Text>
                {isCurrent ? (
                  <Surface
                    elevation={0}
                    style={[styles.currentBadge, { backgroundColor: palette.primaryContainer }]}
                  >
                    <Text style={[styles.currentBadgeLabel, { color: palette.onPrimaryContainer }]}>Current</Text>
                  </Surface>
                ) : null}
              </View>
            </TouchableRipple>
          );
        })}
      </View>
          <View style={{ height: 40 + bottomInset }} />
        </Animated.ScrollView>
      </ScrollViewMarker>
      {usesCollapsibleAppBar ? (
        <CollapsibleBookAppBar
          book={book}
          horizontalPadding={horizontalPadding}
          palette={palette}
          scrollOffset={scrollOffset}
          topInset={topInset}
        />
      ) : null}
    </View>
  );
}

function CollapsibleBookAppBar({
  book,
  horizontalPadding,
  palette,
  scrollOffset,
  topInset,
}: {
  book: BookDetail;
  horizontalPadding: number;
  palette: BookDetailPalette;
  scrollOffset: SharedValue<number>;
  topInset: number;
}) {
  const author = book.authorName?.trim() || book.classification.author?.trim() || 'Unknown author';
  const maxHeight = BOOK_HERO_HEIGHT + topInset;
  const minHeight = BOOK_HERO_TOOLBAR_HEIGHT + topInset;
  const appBarStyle = useAnimatedStyle(() => ({
    height: interpolate(
      scrollOffset.value,
      [0, BOOK_HERO_COLLAPSE_DISTANCE],
      [maxHeight, minHeight],
      'clamp',
    ),
  }));
  const flexibleBackgroundStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      scrollOffset.value,
      [
        0,
        BOOK_HERO_COLLAPSE_DISTANCE - BOOK_HERO_TOOLBAR_HEIGHT,
        BOOK_HERO_COLLAPSE_DISTANCE,
      ],
      [1, 1, 0],
      'clamp',
    ),
    transform: [{
      translateY: interpolate(
        scrollOffset.value,
        [0, BOOK_HERO_COLLAPSE_DISTANCE],
        [0, -BOOK_HERO_TOOLBAR_HEIGHT],
        'clamp',
      ),
    }],
  }));

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        styles.collapsibleAppBar,
        { backgroundColor: palette.surface, height: maxHeight },
        appBarStyle,
      ]}
    >
      <Animated.View
        style={[
          styles.flexibleAppBarBackground,
          { height: maxHeight },
          flexibleBackgroundStyle,
        ]}
      >
        <BookHeroContent
          author={author}
          book={book}
          height={maxHeight}
          horizontalPadding={horizontalPadding}
          palette={palette}
        />
      </Animated.View>
    </Animated.View>
  );
}

function InlineBookHero({
  book,
  horizontalPadding,
  palette,
  scrollOffset,
  topInset,
}: {
  book: BookDetail;
  horizontalPadding: number;
  palette: BookDetailPalette;
  scrollOffset: SharedValue<number>;
  topInset: number;
}) {
  const author = book.authorName?.trim() || book.classification.author?.trim() || 'Unknown author';
  const height = BOOK_HERO_HEIGHT + topInset;
  const flexibleBackgroundStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      scrollOffset.value,
      [
        0,
        BOOK_HERO_COLLAPSE_DISTANCE - BOOK_HERO_TOOLBAR_HEIGHT,
        BOOK_HERO_COLLAPSE_DISTANCE,
      ],
      [1, 1, 0],
      'clamp',
    ),
    transform: [{
      translateY: interpolate(
        scrollOffset.value,
        [0, BOOK_HERO_COLLAPSE_DISTANCE],
        [0, BOOK_HERO_COLLAPSE_DISTANCE * 0.75],
        'clamp',
      ),
    }],
  }));

  return (
    <View style={[styles.inlineHeroClip, { height }]}>
      <Animated.View style={[StyleSheet.absoluteFill, flexibleBackgroundStyle]}>
        <BookHeroContent
          author={author}
          book={book}
          height={height}
          horizontalPadding={horizontalPadding}
          palette={palette}
        />
      </Animated.View>
    </View>
  );
}

function BookHeroContent({
  author,
  book,
  height,
  horizontalPadding,
  palette,
}: {
  author: string;
  book: BookDetail;
  height: number;
  horizontalPadding: number;
  palette: BookDetailPalette;
}) {
  return (
    <Surface
      elevation={0}
      style={[
        styles.hero,
        { backgroundColor: palette.surface, height },
      ]}
    >
      {palette.gradientColors ? (
        <>
          <View style={[StyleSheet.absoluteFill, heroGradientStyle(palette.gradientColors)]} />
          <View style={[StyleSheet.absoluteFill, heroTransitionStyle(palette.headerTransitionColors)]} />
        </>
      ) : null}
      <View style={[styles.heroContent, { left: horizontalPadding, right: horizontalPadding }]}>
        <View style={styles.coverShadow}>
          <View style={styles.coverFrame}>
            {book.coverUrl ? (
              <Image
                accessibilityLabel={`${book.title} cover`}
                contentFit="cover"
                placeholder={getCoverPlaceholder(book.coverUrl)}
                placeholderContentFit="cover"
                source={book.coverUrl}
                style={styles.cover}
                transition={200}
              />
            ) : (
              <View style={[styles.coverFallback, { backgroundColor: palette.surfaceContainerHighest }]}>
                <IconBooks color={palette.onSurfaceVariant} size={40} strokeWidth={1.8} />
              </View>
            )}
          </View>
        </View>
        <View style={styles.heroText}>
          <Text
            numberOfLines={4}
            selectable
            style={[styles.bookTitle, { color: palette.onSurface }]}
          >
            {book.title}
          </Text>
          <Text
            numberOfLines={2}
            selectable
            style={[styles.author, { color: palette.onSurfaceVariant }]}
          >
            {author}
          </Text>
        </View>
      </View>
    </Surface>
  );
}

function MetaChip({ icon: Icon, palette, value }: { icon: TablerIcon; palette: BookDetailPalette; value: string }) {
  return (
    <Surface
      elevation={0}
      style={[
        styles.metaChip,
        { backgroundColor: hexWithAlpha(palette.surfaceContainerHighest, 0.71) },
      ]}
    >
      <Icon color={palette.onSurfaceVariant} size={14} strokeWidth={2} />
      <Text style={[styles.metaChipText, { color: palette.onSurfaceVariant }]}>{value}</Text>
    </Surface>
  );
}

function SectionTitle({ children, palette }: { children: ReactNode; palette: BookDetailPalette }) {
  return <Text style={[styles.sectionTitle, { color: palette.onSurfaceVariant }]}>{children}</Text>;
}

function BookDetailLoading({ palette }: { palette: BookDetailPalette }) {
  const { top: topInset } = useSafeAreaInsets();
  const block = { backgroundColor: palette.surfaceContainerHighest };
  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ backgroundColor: palette.surface }}
      scrollEnabled={false}
    >
      <View
        style={[
          styles.loadingHero,
          { height: BOOK_HERO_HEIGHT + topInset },
        ]}
      >
        <View style={[styles.loadingBlock, styles.loadingCover, block]} />
        <View style={styles.loadingTextGroup}>
          <View style={[styles.loadingBlock, styles.loadingTitle, block]} />
          <View style={[styles.loadingBlock, styles.loadingAuthor, block]} />
        </View>
      </View>
      <View style={styles.loadingBody}>
        <View style={styles.loadingChipRow}>
          <View style={[styles.loadingBlock, styles.loadingChip, block]} />
          <View style={[styles.loadingBlock, styles.loadingChip, block]} />
          <View style={[styles.loadingBlock, styles.loadingChipWide, block]} />
        </View>
        <View style={[styles.loadingBlock, styles.loadingAction, block]} />
        <View style={[styles.loadingBlock, styles.loadingParagraph, block]} />
        <View style={[styles.loadingBlock, styles.loadingUpdate, block]} />
      </View>
    </ScrollView>
  );
}

function BookDetailError({
  error,
  onRetry,
  palette,
  requiresAuth,
}: {
  error: string;
  onRetry: () => void;
  palette: BookDetailPalette;
  requiresAuth: boolean;
}) {
  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={styles.errorContent}
      style={{ backgroundColor: palette.surface }}
    >
      <IconBooks color={palette.onSurfaceVariant} size={42} strokeWidth={1.7} />
      <Text style={[styles.errorTitle, { color: palette.onSurface }]}>Unable to load this book</Text>
      <Text style={[styles.errorText, { color: palette.onSurfaceVariant }]}>{error}</Text>
      <Button icon="refresh" mode="text" onPress={onRetry} textColor={palette.primary}>
        Try again
      </Button>
      {requiresAuth ? (
        <Button mode="text" onPress={() => router.push('/sign-in')} textColor={palette.primary}>
          Sign in
        </Button>
      ) : null}
    </ScrollView>
  );
}

function getCurrentSortNum(book: BookDetail): number | null {
  if (!book.readPosition) return null;
  const index = book.chapters.findIndex((chapter) => chapter.id === book.readPosition?.chapterId);
  return index < 0 ? null : index + 1;
}

function openReader(bookId: number, sortNum: number) {
  router.push({
    pathname: '/reader/[bookId]/[sortNum]',
    params: { bookId: String(bookId), sortNum: String(sortNum) },
  });
}

function shortenChapterTitle(title: string): string {
  return title.length > 15 ? `${title.slice(0, 15)}...` : title;
}

function formatCount(value: number): string {
  return new Intl.NumberFormat(undefined, { notation: 'compact', maximumFractionDigits: 1 }).format(value);
}

function formatRelativeTime(value: string): string {
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return 'unknown';

  const elapsed = Math.max(0, Date.now() - timestamp);
  const minutes = Math.floor(elapsed / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);
  if (days < 26) return `${days}d ago`;
  if (days < 46) return '1mo ago';
  if (days < 320) return `${Math.round(days / 30.4)}mo ago`;
  if (days < 548) return '1y ago';
  return `${Math.round(days / 365.25)}y ago`;
}

function heroGradientStyle(colors: readonly [string, string, string]): ViewStyle {
  return {
    experimental_backgroundImage: `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 50%, ${colors[2]} 100%)`,
  };
}

function heroTransitionStyle(
  colors: BookDetailPalette['headerTransitionColors'],
): ViewStyle {
  return {
    experimental_backgroundImage: `linear-gradient(180deg, ${colors[0]} 0%, ${colors[1]} 30%, ${colors[2]} 50%, ${colors[3]} 70%, ${colors[4]} 90%, ${colors[5]} 100%)`,
  };
}

function getCoverPlaceholder(coverUrl: string): { blurhash: string; width: number; height: number } | null {
  const blurhash = extractCoverBlurHash(coverUrl);
  return blurhash ? { blurhash, width: 32, height: 48 } : null;
}

function hexWithAlpha(hex: string, alpha: number): string {
  const normalized = hex.replace('#', '');
  if (normalized.length !== 6) return hex;
  const red = Number.parseInt(normalized.slice(0, 2), 16);
  const green = Number.parseInt(normalized.slice(2, 4), 16);
  const blue = Number.parseInt(normalized.slice(4, 6), 16);
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
}

const styles = StyleSheet.create({
  actionError: { fontSize: 13, lineHeight: 18, paddingTop: 8 },
  actions: { alignItems: 'center', flexDirection: 'row', gap: 12 },
  author: { fontSize: 14, letterSpacing: 0.25, lineHeight: 20 },
  body: { paddingTop: 16 },
  bookTitle: { fontSize: 22, fontWeight: '700', letterSpacing: 0, lineHeight: 28 },
  chapterList: {},
  chapterNumber: { fontSize: 13, fontVariant: ['tabular-nums'], fontWeight: '500', letterSpacing: 0.5, lineHeight: 19 },
  chapterNumberSlot: { alignItems: 'center', width: 32 },
  chapterRow: { alignItems: 'center', flexDirection: 'row', gap: 16, minHeight: 48, paddingHorizontal: 12 },
  chapterTitle: { flex: 1, fontSize: 14, letterSpacing: 0.5, lineHeight: 21 },
  chips: { alignItems: 'center', flexDirection: 'row', flexWrap: 'wrap', gap: 8, paddingBottom: 20 },
  collapsibleAppBar: { left: 0, overflow: 'hidden', position: 'absolute', right: 0, top: 0, zIndex: 1 },
  cover: { borderRadius: 8, height: 150, width: 100 },
  coverFallback: { alignItems: 'center', height: 150, justifyContent: 'center', width: 100 },
  coverFrame: { borderRadius: 8, height: 150, overflow: 'hidden', width: 100 },
  coverShadow: { borderRadius: 8, boxShadow: '0 3px 8px rgba(0, 0, 0, 0.176)', height: 150, width: 100 },
  currentBadge: { borderRadius: 4, paddingHorizontal: 8, paddingVertical: 2 },
  currentBadgeLabel: { fontSize: 11, fontWeight: '500', letterSpacing: 0.5, lineHeight: 16 },
  currentChapterText: { fontWeight: '700' },
  currentChapterTitle: { fontWeight: '600' },
  detailContent: { flex: 1 },
  errorContent: { alignItems: 'center', gap: 10, padding: 32, paddingTop: 88 },
  errorText: { fontSize: 15, lineHeight: 21, textAlign: 'center' },
  errorTitle: { fontSize: 18, fontWeight: '700', letterSpacing: 0, lineHeight: 24 },
  flexibleAppBarBackground: { left: 0, position: 'absolute', right: 0, top: 0 },
  hero: { overflow: 'hidden' },
  heroContent: { alignItems: 'flex-end', bottom: 16, flexDirection: 'row', gap: 16, position: 'absolute' },
  heroText: { flex: 1, gap: 4, paddingBottom: 1 },
  inlineHeroClip: { overflow: 'hidden' },
  introductionClip: { maxHeight: 90, overflow: 'hidden' },
  introductionClipWithRuby: { maxHeight: 1000 },
  introductionPreview: { borderRadius: 8, paddingVertical: 4 },
  introductionSection: { gap: 8, paddingBottom: 24, paddingTop: 24 },
  loadingAction: { height: 56, width: '100%' },
  loadingAuthor: { height: 15, width: '42%' },
  loadingBlock: { borderRadius: 8 },
  loadingBody: { gap: 20, padding: 20 },
  loadingChip: { height: 26, width: 58 },
  loadingChipRow: { flexDirection: 'row', gap: 8 },
  loadingChipWide: { height: 26, width: 92 },
  loadingCover: { height: 150, width: 100 },
  loadingHero: { alignItems: 'flex-end', flexDirection: 'row', gap: 16, padding: 20, paddingBottom: 16 },
  loadingParagraph: { height: 88, width: '100%' },
  loadingTextGroup: { flex: 1, gap: 10, paddingBottom: 8 },
  loadingTitle: { height: 26, width: '88%' },
  loadingUpdate: { height: 42, width: '100%' },
  metaChip: { alignItems: 'center', borderRadius: 8, flexDirection: 'row', gap: 4, height: 26, paddingHorizontal: 10 },
  metaChipText: { fontSize: 12, fontWeight: '500', letterSpacing: 0.25, lineHeight: 17 },
  readButton: { borderRadius: 16, flex: 1, height: 56 },
  readButtonContent: { height: 56 },
  readButtonLabel: { fontSize: 15, fontWeight: '600', letterSpacing: 0.1, lineHeight: 21.5 },
  root: { flex: 1 },
  scrollViewMarker: { flex: 1 },
  sectionTitle: { fontSize: 13, fontWeight: '600', letterSpacing: 0.5, lineHeight: 19 },
  shelfButton: { borderRadius: 16, height: 56, margin: 0, width: 56 },
  updateInfo: { alignItems: 'center', borderRadius: 12, flexDirection: 'row', gap: 8, marginBottom: 24, padding: 12 },
  updateInfoWithoutIntroduction: { marginTop: 24 },
  updateText: { flex: 1, fontSize: 13, letterSpacing: 0.25, lineHeight: 19 },
});
