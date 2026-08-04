import { Image } from 'expo-image';
import { router, useNavigation } from 'expo-router';
import { useRoute } from 'expo-router/react-navigation';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  FlatList,
  StyleSheet,
  useWindowDimensions,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { ComicContent, ComicInfo } from '@novella/api-client';
import { createComicPageSlots, mergeComicPageBatch, resolveReaderInitialIndex, resolveReaderRestorePosition, type ComicPageSlot, type ReaderMode, type ReaderOpenPosition } from '@novella/reader-engine';

import { createComicBlurHashPlaceholder } from '@/services/blurhash';
import { reader } from '@/services/client';
import { ReaderChapterNavigation } from '@/components/reader-chapter-navigation';
import { ReaderErrorState, ReaderPreparationState } from '@/components/reader-chrome';
import { ReaderNavigation } from '@/components/reader-navigation';
import { subscribeReaderChapterSelection } from '@/services/reader-chapter-selection';
import {
  getCachedReaderPosition,
  shouldUseCachedReaderPosition,
} from '@/services/reader-position-cache';
import {
  type ReaderProgressCheckpoint,
  stageReaderProgress,
  syncReaderProgress,
} from '@/services/reader-progress-sync';
import { useReaderLifecycleSave } from '@/hooks/use-reader-lifecycle-save';
import { useReaderPositionSaver } from '@/hooks/use-reader-position-saver';
import { updateAppSettings, useAppSettings } from '@/services/settings';
import { colors } from '@/theme/colors';

const PAGE_BATCH = 12;
const EMPTY_COMIC_SLOTS: readonly ComicPageSlot[] = [];
const IOS_READER_TOP_TOOLBAR_HEIGHT = 44;
const IOS_READER_BOTTOM_TOOLBAR_HEIGHT = 44;

interface ComicProgressInput {
  chapterId: number;
  index: number;
}

export interface ComicReaderScreenProps {
  bookId: number;
  sortNum: number;
  openPosition?: ReaderOpenPosition;
}

export function ComicReaderScreen({ bookId, sortNum, openPosition = 'saved' }: ComicReaderScreenProps) {
  const { height: windowHeight, width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  // The iOS reader floats glass toolbars over the top and bottom of the
  // screen, so pages must be inset by their heights (plus a little extra to
  // keep page content out of the blur zone) — same scheme as the novel
  // reader. Android renders native bars that handle insets themselves.
  const readerTopInset = process.env.EXPO_OS === 'ios'
    ? insets.top + IOS_READER_TOP_TOOLBAR_HEIGHT + 16
    : 0;
  const readerBottomInset = process.env.EXPO_OS === 'ios'
    ? IOS_READER_BOTTOM_TOOLBAR_HEIGHT + insets.bottom + 16
    : 0;
  // Height of the visible page band between the floating top/bottom bars.
  // Paged pages are centered within this band (top-aligned only when a page
  // is taller than the band).
  const availablePageHeight = Math.max(1, windowHeight - readerTopInset - readerBottomInset);
  const settings = useAppSettings();
  const navigation = useNavigation<{
    setParams(params: { position: ReaderOpenPosition; sortNum: string; type: 'Comic' }): void;
  }>();
  const route = useRoute();
  const [mode, setMode] = useState<ReaderMode>(settings.readerViewMode);
  const [modeRestoreTarget, setModeRestoreTarget] = useState<{
    chapterId: number;
    index: number;
  } | null>(null);
  const [info, setInfo] = useState<ComicInfo | null>(null);
  const [chapter, setChapter] = useState<ComicContent | null>(null);
  const [slots, setSlots] = useState<ComicPageSlot[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const loadingBatchesRef = useRef(new Set<string>());
  const [visiblePage, setVisiblePage] = useState(0);
  const requestVersion = useRef(0);

  const loadChapter = useCallback(async () => {
    const version = ++requestVersion.current;
    setLoading(true);
    setError(null);
    setInfo(null);
    setChapter(null);
    setSlots([]);
    try {
      const loadedInfo = await reader.loadComicInfo(bookId);
      if (version !== requestVersion.current) return;
      const selected = loadedInfo.chapters.find((item) => item.sortNum === sortNum) ?? loadedInfo.chapters[sortNum - 1];
      if (!selected) throw new Error('This chapter is not available.');
      let loadedChapter = await reader.loadComicContent({ chapterId: selected.id, skip: 0, take: PAGE_BATCH });
      if (version !== requestVersion.current) return;
      if (
        loadedChapter.chapter.bookId !== bookId ||
        loadedChapter.chapter.sortNum !== selected.sortNum
      ) throw new Error('The chapter response does not match the requested chapter.');
      if (openPosition !== 'saved') {
        loadedChapter = {
          ...loadedChapter,
          readPosition: {
            chapterId: loadedChapter.chapter.id,
            position: openPosition === 'start' ? '1' : String(Math.max(1, loadedChapter.chapter.total)),
          },
        };
      } else {
        const cached = await getCachedReaderPosition(bookId);
        if (version !== requestVersion.current) return;
        loadedChapter = {
          ...loadedChapter,
          readPosition: resolveReaderRestorePosition(
            loadedChapter.chapter.id,
            loadedChapter.readPosition,
            cached,
            cached !== null && shouldUseCachedReaderPosition(
              bookId,
              cached,
              loadedChapter.readPosition,
            ),
          ),
        };
      }
      if (version !== requestVersion.current) return;
      setInfo(loadedInfo);
      setChapter(loadedChapter);
      setSlots(createComicPageSlots(loadedChapter.chapter.total, loadedChapter.chapter.images.map((image, index) => ({ ...image, index }))));
    } catch (cause) {
      if (version === requestVersion.current) {
        setError(cause instanceof Error ? cause.message : 'The comic could not be loaded.');
      }
    } finally {
      if (version === requestVersion.current) setLoading(false);
    }
  }, [bookId, openPosition, sortNum]);

  useEffect(() => {
    void loadChapter();
    return () => {
      requestVersion.current += 1;
      loadingBatchesRef.current.clear();
    };
  }, [loadChapter]);
  useEffect(() => setMode(settings.readerViewMode), [settings.readerViewMode]);

  const loadBatch = useCallback(async (pageIndex: number) => {
    if (!chapter || pageIndex < 0 || pageIndex >= chapter.chapter.total) return;
    const batch = Math.floor(pageIndex / PAGE_BATCH);
    const version = requestVersion.current;
    const batchKey = `${version}:${batch}`;
    if (loadingBatchesRef.current.has(batchKey) || slots.slice(batch * PAGE_BATCH, (batch + 1) * PAGE_BATCH).every((slot) => slot.image)) return;
    loadingBatchesRef.current.add(batchKey);
    try {
      const result = await reader.loadComicContent({ chapterId: chapter.chapter.id, skip: batch * PAGE_BATCH, take: PAGE_BATCH });
      if (
        version !== requestVersion.current ||
        result.chapter.id !== chapter.chapter.id
      ) return;
      setSlots((current) => mergeComicPageBatch(current, result.chapter.skip, result.chapter.images.map((image, index) => ({ ...image, index }))));
    } finally {
      loadingBatchesRef.current.delete(batchKey);
    }
  }, [chapter, slots]);

  const activeChapter = chapter?.chapter.sortNum === sortNum ? chapter : null;
  const activeChapterIdRef = useRef<number | null>(null);
  activeChapterIdRef.current = activeChapter?.chapter.id ?? null;
  const activeSlots = activeChapter ? slots : EMPTY_COMIC_SLOTS;
  const selectedChapterIndex = info?.chapters.findIndex((item) => item.sortNum === sortNum) ?? -1;
  const previousChapter = selectedChapterIndex > 0 ? info?.chapters[selectedChapterIndex - 1] : undefined;
  const nextChapter = selectedChapterIndex >= 0 ? info?.chapters[selectedChapterIndex + 1] : undefined;
  const pageWidth = width;
  const scrollLayouts = useMemo(
    () => createComicPageLayouts(activeSlots, pageWidth),
    [activeSlots, pageWidth],
  );
  const savedPageIndex = Math.max(0, Number(activeChapter?.readPosition?.position ?? 1) - 1);
  const restoredPageIndex = resolveReaderInitialIndex(openPosition, savedPageIndex, activeSlots.length);
  const initialPageIndex = modeRestoreTarget !== null && modeRestoreTarget.chapterId === activeChapter?.chapter.id
    ? Math.min(modeRestoreTarget.index, Math.max(0, activeSlots.length - 1))
    : restoredPageIndex;
  const lastVisiblePageRef = useRef(initialPageIndex);
  useEffect(() => {
    setVisiblePage(initialPageIndex);
    lastVisiblePageRef.current = initialPageIndex;
  }, [activeChapter?.chapter.id, initialPageIndex]);
  useEffect(() => {
    const urls = activeSlots
      .slice(Math.max(0, visiblePage - 2), visiblePage + 3)
      .map((slot) => slot.image?.url)
      .filter((url): url is string => Boolean(url));
    if (urls.length > 0) void Image.prefetch(urls, 'memory-disk').catch(() => false);
  }, [activeSlots, visiblePage]);
  useEffect(() => {
    if (!activeChapter || activeSlots.length === 0) return;
    void loadBatch(visiblePage);
    void loadBatch(Math.min(activeSlots.length - 1, visiblePage + 4));
  }, [activeChapter, activeSlots.length, loadBatch, visiblePage]);
  const stagePosition = useCallback(
    ({ chapterId, index }: ComicProgressInput) => stageReaderProgress({
      bookId,
      chapterId,
      position: String(index + 1),
    }),
    [bookId],
  );
  const {
    commit: commitPosition,
    flush: flushPosition,
    schedule: schedulePosition,
  } = useReaderPositionSaver<ComicProgressInput, ReaderProgressCheckpoint>(
    syncReaderProgress,
    450,
    stagePosition,
  );
  const scheduleActivePosition = useCallback((index: number) => {
    if (
      !activeChapter ||
      activeChapterIdRef.current !== activeChapter.chapter.id
    ) return;
    schedulePosition({ chapterId: activeChapter.chapter.id, index });
  }, [activeChapter, schedulePosition]);
  const saveCurrentPosition = useCallback(() => {
    if (!activeChapter) return flushPosition();
    return commitPosition({
      chapterId: activeChapter.chapter.id,
      index: lastVisiblePageRef.current,
    });
  }, [activeChapter, commitPosition, flushPosition]);
  useReaderLifecycleSave(saveCurrentPosition);
  useEffect(() => {
    if (!activeChapter || activeSlots.length === 0) return;
    void commitPosition({
      chapterId: activeChapter.chapter.id,
      index: initialPageIndex,
    });
  }, [activeChapter, activeSlots.length, commitPosition, initialPageIndex]);
  const openChapter = useCallback((nextSortNum: number, nextOpenPosition: ReaderOpenPosition) => {
    void saveCurrentPosition();
    activeChapterIdRef.current = null;
    setModeRestoreTarget(null);
    navigation.setParams({
      position: nextOpenPosition,
      sortNum: String(nextSortNum),
      type: 'Comic',
    });
  }, [navigation, saveCurrentPosition]);
  useEffect(() => subscribeReaderChapterSelection(route.key, (selection) => {
    if (selection.bookId === bookId && selection.kind === 'Comic') {
      openChapter(selection.sortNum, selection.openPosition);
    }
  }), [bookId, openChapter, route.key]);
  const changeMode = useCallback((nextMode: ReaderMode) => {
    if (activeChapter) {
      setModeRestoreTarget({
        chapterId: activeChapter.chapter.id,
        index: lastVisiblePageRef.current,
      });
    }
    setMode(nextMode);
    void updateAppSettings({ readerViewMode: nextMode });
  }, [activeChapter]);
  const openChapters = useCallback(() => {
    router.push({
      pathname: '/reader/[bookId]/chapters',
      params: {
        bookId: String(bookId),
        readerKey: route.key,
        sortNum: String(sortNum),
        type: 'Comic',
      },
    });
  }, [bookId, route.key, sortNum]);

  return (
    <>
      <View style={styles.root}>
      {error ? (
        <ReaderErrorState message={error} onRetry={loadChapter} />
      ) : loading || !activeChapter ? <ReaderPreparationState label="Loading comic" /> : mode === 'paged' ? (
        <FlatList
          contentInsetAdjustmentBehavior="never"
          contentContainerStyle={{ paddingBottom: readerBottomInset, paddingTop: readerTopInset }}
          data={activeSlots}
          key={`paged-${activeChapter.chapter.id}`}
          horizontal
          initialScrollIndex={Math.min(initialPageIndex, Math.max(0, activeSlots.length - 1))}
          keyExtractor={(slot) => String(slot.index)}
          getItemLayout={(_, index) => ({ index, length: pageWidth, offset: pageWidth * index })}
          pagingEnabled
          initialNumToRender={3}
          maxToRenderPerBatch={3}
          removeClippedSubviews={process.env.EXPO_OS === 'android'}
          renderItem={({ item }) => <ComicPage maxHeight={availablePageHeight} priority={Math.abs(item.index - visiblePage) <= 1 ? 'high' : 'normal'} slot={item} width={pageWidth} />}
          showsHorizontalScrollIndicator={false}
          onMomentumScrollEnd={(event) => { const index = Math.round(event.nativeEvent.contentOffset.x / Math.max(1, pageWidth)); lastVisiblePageRef.current = index; setVisiblePage(index); void loadBatch(index); scheduleActivePosition(index); }}
          windowSize={5}
        />
      ) : (
        <FlatList
          contentInsetAdjustmentBehavior="never"
          data={activeSlots}
          key={`scroll-${activeChapter.chapter.id}`}
          initialScrollIndex={Math.min(initialPageIndex, Math.max(0, activeSlots.length - 1))}
          keyExtractor={(slot) => String(slot.index)}
          getItemLayout={(_, index) => scrollLayouts[index] ?? { index, length: pageWidth * 1.5, offset: 0 }}
          initialNumToRender={3}
          maxToRenderPerBatch={3}
          removeClippedSubviews={process.env.EXPO_OS === 'android'}
          renderItem={({ item }) => <ComicPage priority={Math.abs(item.index - visiblePage) <= 2 ? 'high' : 'normal'} slot={item} width={pageWidth} />}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: readerBottomInset + 16, paddingTop: readerTopInset }}
          onViewableItemsChanged={({ viewableItems }) => { const first = viewableItems.find((item) => item.isViewable)?.item as ComicPageSlot | undefined; if (first) { lastVisiblePageRef.current = first.index; setVisiblePage(first.index); void loadBatch(first.index); scheduleActivePosition(first.index); } }}
          updateCellsBatchingPeriod={32}
          viewabilityConfig={{ itemVisiblePercentThreshold: 20 }}
          windowSize={5}
        />
      )}
      </View>
      <ReaderNavigation
        backgroundColor={colors.background as string}
        foregroundColor={colors.label as string}
        mode={mode}
        onModeChange={changeMode}
        onOpenChapters={openChapters}
        onOpenSettings={() => router.push('/settings/reader')}
        title={activeChapter?.chapter.title ?? 'Comic reader'}
      />
      <ReaderChapterNavigation
        bottomInset={insets.bottom}
        current={selectedChapterIndex + 1}
        onNext={nextChapter ? () => openChapter(nextChapter.sortNum, 'start') : null}
        onPrevious={previousChapter ? () => openChapter(previousChapter.sortNum, 'end') : null}
        total={info?.chapters.length ?? 0}
      />
    </>
  );
}

function ComicPage({ maxHeight, priority, slot, width }: { maxHeight?: number; priority: 'high' | 'normal'; slot: ComicPageSlot; width: number }) {
  const image = slot.image;
  const ratio = image ? Math.max(0.2, image.height / image.width) : 1.5;
  const naturalHeight = width * ratio;
  const placeholder = image
    ? createComicBlurHashPlaceholder(image.placeholder, image.width, image.height)
    : null;
  // Paged mode constrains the page to the visible band; pages that fit are
  // vertically centered, taller ones stay top-aligned so only the bottom
  // clips (the top always stays visible).
  const constrained = maxHeight !== undefined;
  const centered = constrained && naturalHeight <= maxHeight;
  return (
    <View
      style={[
        { width },
        constrained ? { height: maxHeight } : null,
        centered ? styles.centeredPage : null,
      ]}
    >
      {image ? (
        <Image
          accessibilityLabel={`Comic page ${slot.index + 1}`}
          cachePolicy="memory-disk"
          contentFit="contain"
          placeholderContentFit="contain"
          priority={priority}
          recyclingKey={image.url}
          {...(placeholder ? { placeholder } : {})}
          source={{ uri: image.url }}
          style={{ backgroundColor: colors.surfaceContainerHighest as string, height: naturalHeight, width }}
          transition={80}
        />
      ) : <View style={{ backgroundColor: colors.surfaceContainerHighest as string, height: naturalHeight, width }} />}
    </View>
  );
}

function createComicPageLayouts(
  slots: readonly ComicPageSlot[],
  width: number,
): Array<{ length: number; offset: number; index: number }> {
  const heightFor = (slot: ComicPageSlot | undefined) => {
    const image = slot?.image;
    return width * (image ? Math.max(0.2, image.height / image.width) : 1.5);
  };
  let offset = 0;
  return slots.map((slot, index) => {
    const length = heightFor(slot);
    const layout = { index, length, offset };
    offset += length;
    return layout;
  });
}

const styles = StyleSheet.create({
  centeredPage: { alignItems: 'center', justifyContent: 'center' },
  root: { backgroundColor: colors.background as string, flex: 1 },
  centered: { alignItems: 'center', flex: 1, justifyContent: 'center' },
});
