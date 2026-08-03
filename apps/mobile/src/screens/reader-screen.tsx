import { router, useNavigation } from 'expo-router';
import { useHeaderHeight, useRoute } from 'expo-router/react-navigation';
import { isLiquidGlassAvailable } from 'expo-glass-effect';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  type LayoutChangeEvent,
  StyleSheet,
  useWindowDimensions,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  createReaderPagePlan,
  getAdjacentChapterSortNum,
  findReaderBlockIndex,
  normalizeNovelBlocks,
  processNovelFootnotes,
  resolveReaderInitialIndex,
  sanitizeNovelHtml,
  type NovelReaderBlock,
  type ReaderMode,
  type ReaderOpenPosition,
} from '@novella/reader-engine';

import { BookHtmlContent } from '@/components/book-html-content';
import { ReaderChapterNavigation } from '@/components/reader-chapter-navigation';
import { ReaderErrorState, ReaderPreparationState } from '@/components/reader-chrome';
import { ReaderNavigation } from '@/components/reader-navigation';
import { simplifyReaderChapterTitle } from '@/services/chapter-title';
import { useReaderChapter } from '@/hooks/use-reader-chapter';
import { useReaderChapterPreload } from '@/hooks/use-reader-chapter-preload';
import { useReaderFont } from '@/hooks/use-reader-font';
import { useReaderImageDimensions } from '@/hooks/use-reader-image-dimensions';
import { useReaderPositionSaver } from '@/hooks/use-reader-position-saver';
import {
  subscribeReaderChapterSelection,
} from '@/services/reader-chapter-selection';
import { createReaderFootnoteSession } from '@/services/reader-footnote-session';
import {
  type ReaderProgressCheckpoint,
  stageReaderProgress,
  syncReaderProgress,
} from '@/services/reader-progress-sync';
import { updateAppSettings, useAppSettings } from '@/services/settings';
import { useReaderLifecycleSave } from '@/hooks/use-reader-lifecycle-save';
import { colors } from '@/theme/colors';

const HAS_LIQUID_GLASS = isLiquidGlassAvailable();
const IOS_READER_BOTTOM_TOOLBAR_HEIGHT = 44;
const READER_PAGE_VERTICAL_PADDING = 16;
const READER_BLOCK_GAP = 12;
const READER_VIEWABILITY_CONFIG = Object.freeze({
  viewAreaCoveragePercentThreshold: 0,
});

interface NovelProgressInput {
  chapterId: number;
  position: string;
}

export interface ReaderScreenProps {
  bookId: number;
  sortNum: number;
  openPosition?: ReaderOpenPosition;
}

export function ReaderScreen({ bookId, sortNum, openPosition = 'saved' }: ReaderScreenProps) {
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const headerHeight = useHeaderHeight();
  const settings = useAppSettings();
  const navigation = useNavigation<{
    setParams(params: { position: ReaderOpenPosition; sortNum: string }): void;
  }>();
  const route = useRoute();
  const [mode, setMode] = useState<ReaderMode>(settings.readerViewMode);
  const [modeRestoreTarget, setModeRestoreTarget] = useState<{
    chapterId: number;
    index: number;
  } | null>(null);
  const [viewportHeight, setViewportHeight] = useState(0);
  const [measuredHeights, setMeasuredHeights] = useState<Record<string, number>>({});
  const measuredHeightsRef = useRef<Record<string, number>>({});
  const publishedHeightsRef = useRef<Record<string, number>>({});
  const measurementFrameRef = useRef<number | null>(null);
  const sidePadding = Math.max(12, settings.readerSidePadding);
  const contentWidth = Math.max(1, width - sidePadding * 2);
  useEffect(() => setMode(settings.readerViewMode), [settings.readerViewMode]);
  const conversion = settings.convertType === 'none' ? undefined : settings.convertType;
  const { content, error, isLoading, reload } = useReaderChapter(
    bookId,
    sortNum,
    conversion,
    openPosition === 'saved',
  );
  const readerFont = useReaderFont(content?.chapter.fontUrl);
  const chapterHtml = content?.chapter.content ?? '';
  const chapterPresentation = useMemo(() => {
    const presentation = processNovelFootnotes(chapterHtml);
    return {
      ...presentation,
      notesById: Object.fromEntries(
        Object.entries(presentation.notesById).map(([id, note]) => [
          id,
          sanitizeNovelHtml(note, readerFont.invisibleCodepoints),
        ]),
      ),
    };
  }, [chapterHtml, readerFont.invisibleCodepoints]);
  const readerImages = useReaderImageDimensions(chapterPresentation.html);
  useEffect(() => {
    measuredHeightsRef.current = {};
    publishedHeightsRef.current = {};
    setMeasuredHeights({});
    if (measurementFrameRef.current !== null) {
      cancelAnimationFrame(measurementFrameRef.current);
      measurementFrameRef.current = null;
    }
    return () => {
      if (measurementFrameRef.current !== null) {
        cancelAnimationFrame(measurementFrameRef.current);
        measurementFrameRef.current = null;
      }
    };
  }, [content?.chapter.id, settings.fontSize, settings.readerLineHeight, sidePadding]);
  const blocks = useMemo(
    () => (content ? normalizeNovelBlocks(chapterPresentation.html, readerFont.invisibleCodepoints) : []),
    [chapterPresentation.html, content, readerFont.invisibleCodepoints],
  );
  const usesOverlayHeader = process.env.EXPO_OS === 'ios' && HAS_LIQUID_GLASS;
  const pagedTopInset = usesOverlayHeader ? headerHeight : 0;
  const pagedBottomInset = process.env.EXPO_OS === 'ios'
    ? IOS_READER_BOTTOM_TOOLBAR_HEIGHT + insets.bottom
    : 0;
  const pageHeight = Math.max(1, (viewportHeight || height) - pagedTopInset - pagedBottomInset);
  const pageContentHeight = Math.max(
    1,
    pageHeight - READER_PAGE_VERTICAL_PADDING * 2 - READER_BLOCK_GAP,
  );
  const pages = useMemo(
    () => createReaderPagePlan(blocks, measuredHeights, pageContentHeight),
    [blocks, measuredHeights, pageContentHeight],
  );
  const savedIndex = findReaderBlockIndex(blocks, content?.readPosition?.position);
  const restoredIndex = resolveReaderInitialIndex(openPosition, savedIndex, blocks.length);
  const startIndex = modeRestoreTarget !== null && modeRestoreTarget.chapterId === content?.chapter.id
    ? Math.min(modeRestoreTarget.index, Math.max(0, blocks.length - 1))
    : restoredIndex;
  const scrollRestoreKey = [
    content?.chapter.id ?? 0,
    startIndex,
    blocks.length,
    settings.fontSize,
    settings.readerLineHeight,
    sidePadding,
  ].join(':');
  const [restoredScrollKey, setRestoredScrollKey] = useState<string | null>(null);
  const isRestoringScroll = mode === 'scroll' &&
    blocks.length > 0 &&
    startIndex > 0 &&
    restoredScrollKey !== scrollRestoreKey;
  const scrollListRef = useRef<FlatList<NovelReaderBlock>>(null);
  const scrollRestoreIndexRef = useRef<number | null>(null);
  const scrollRestoreAttemptsRef = useRef(0);
  const scrollRestoreTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const scrollInteractionStartedRef = useRef(false);
  const scrollRestoreCompletedRef = useRef(false);
  const clearScrollRestoreTimer = useCallback(() => {
    if (scrollRestoreTimerRef.current === null) return;
    clearTimeout(scrollRestoreTimerRef.current);
    scrollRestoreTimerRef.current = null;
  }, []);
  const requestScrollRestore = useCallback(() => {
    if (
      scrollInteractionStartedRef.current ||
      !scrollListRef.current ||
      blocks.length === 0
    ) return;
    const index = scrollRestoreIndexRef.current;
    if (index === null) return;
    // A freshly keyed list already starts at the native adjusted top. On iOS,
    // forcing offset 0 would skip the negative automatic header inset and hide
    // the opening content underneath the translucent navigation bar.
    if (index <= 0) {
      scrollRestoreIndexRef.current = null;
      scrollRestoreCompletedRef.current = true;
      setRestoredScrollKey(scrollRestoreKey);
      return;
    }
    if (index >= blocks.length - 1) {
      // Keep the target alive. As virtualized cells extend content size,
      // onContentSizeChange calls this again until the final block is mounted.
      scrollListRef.current.scrollToEnd({ animated: false });
      return;
    }
    scrollListRef.current.scrollToIndex({
      animated: false,
      index: Math.min(index, blocks.length - 1),
      viewPosition: 0,
    });
  }, [blocks.length, scrollRestoreKey]);
  useEffect(() => {
    clearScrollRestoreTimer();
    scrollRestoreAttemptsRef.current = 0;
    scrollInteractionStartedRef.current = false;
    scrollRestoreCompletedRef.current = mode !== 'scroll';
    scrollRestoreIndexRef.current = mode === 'scroll' && blocks.length > 0
      ? Math.min(startIndex, blocks.length - 1)
      : null;
    const frame = requestAnimationFrame(requestScrollRestore);
    return () => {
      cancelAnimationFrame(frame);
      clearScrollRestoreTimer();
    };
  }, [
    blocks.length,
    clearScrollRestoreTimer,
    content?.chapter.id,
    mode,
    requestScrollRestore,
    startIndex,
  ]);
  const readerTextColor = settings.oledBlack ? '#FFFFFF' : colors.label as string;
  const readerBackground = settings.oledBlack ? '#000000' : colors.background as string;
  const readerFontProps = {
    firstLineIndent: settings.readerFirstLineIndent,
    fontSize: settings.fontSize,
    lineHeight: settings.fontSize * settings.readerLineHeight,
    textColor: readerTextColor,
    ...(readerFont.status === 'loaded' ? { fontFamily: readerFont.family } : {}),
  };
  const openFootnote = useCallback((id: string) => {
    const html = chapterPresentation.notesById[id];
    if (!html) return;
    const token = createReaderFootnoteSession({
      bookId,
      fontSize: settings.fontSize,
      html,
      lineHeight: settings.fontSize * settings.readerLineHeight,
      ...(readerFont.status === 'loaded' ? { fontFamily: readerFont.family } : {}),
    });
    router.push({
      pathname: '/reader/[bookId]/footnote',
      params: { bookId: String(bookId), token },
    });
  }, [bookId, chapterPresentation.notesById, readerFont.family, readerFont.status, settings.fontSize, settings.readerLineHeight]);
  const requiresReaderFont = Boolean(content?.chapter.fontUrl?.trim());
  const fontLoading = requiresReaderFont && (readerFont.status === 'idle' || readerFont.status === 'loading');
  const pagedMeasurementReady = readerImages.isReady && blocks.every(
    (block) => measuredHeights[block.id] !== undefined,
  );
  const onBlockLayout = useCallback((id: string, event: LayoutChangeEvent) => {
    const height = event.nativeEvent.layout.height;
    measuredHeightsRef.current[id] = height;
    if (
      mode !== 'paged' ||
      publishedHeightsRef.current[id] === height ||
      measurementFrameRef.current !== null
    ) return;
    measurementFrameRef.current = requestAnimationFrame(() => {
      measurementFrameRef.current = null;
      const next = { ...measuredHeightsRef.current };
      publishedHeightsRef.current = next;
      setMeasuredHeights(next);
    });
  }, [mode]);
  const chapterCount = content?.chapter.chapterTitles.length ?? 0;
  useReaderChapterPreload({
    bookId,
    currentSortNum: sortNum,
    enabled:
      content !== null &&
      readerFont.status !== 'loading' &&
      (mode === 'scroll' || pagedMeasurementReady),
    totalChapters: chapterCount,
    windowSize: settings.readerPreloadWindow,
    ...(conversion === undefined ? {} : { convert: conversion }),
  });
  const previousSortNum = getAdjacentChapterSortNum({ sortNum, totalChapters: chapterCount }, 'previous');
  const nextSortNum = getAdjacentChapterSortNum({ sortNum, totalChapters: chapterCount }, 'next');
  const lastVisibleBlockRef = useRef<NovelReaderBlock | undefined>(undefined);
  const activeChapterIdRef = useRef<number | null>(null);
  activeChapterIdRef.current = content?.chapter.id ?? null;

  const stagePosition = useCallback(
    (position: NovelProgressInput) => stageReaderProgress({ bookId, ...position }),
    [bookId],
  );
  const {
    commit: commitPosition,
    flush: flushPosition,
    schedule: schedulePosition,
  } = useReaderPositionSaver<NovelProgressInput, ReaderProgressCheckpoint>(
    syncReaderProgress,
    450,
    stagePosition,
  );
  const createPositionInput = useCallback((block: NovelReaderBlock): NovelProgressInput => ({
    chapterId: content?.chapter.id ?? 0,
    position: block.locator,
  }), [content?.chapter.id]);
  const savePosition = useCallback((block: NovelReaderBlock | undefined) => {
    if (
      !block ||
      !content ||
      activeChapterIdRef.current !== content.chapter.id
    ) return;
    schedulePosition(createPositionInput(block));
  }, [content, createPositionInput, schedulePosition]);
  const saveCurrentPosition = useCallback(() => {
    const block = lastVisibleBlockRef.current;
    if (!block || !content) return flushPosition();
    return commitPosition(createPositionInput(block));
  }, [commitPosition, content, createPositionInput, flushPosition]);
  useReaderLifecycleSave(saveCurrentPosition);

  useEffect(() => {
    const initialBlock = blocks[startIndex];
    lastVisibleBlockRef.current = initialBlock;
    if (initialBlock && content && !fontLoading) {
      void commitPosition(createPositionInput(initialBlock));
    }
  }, [blocks, commitPosition, content, createPositionInput, fontLoading, startIndex]);

  const openChapter = useCallback((nextSortNum: number, nextOpenPosition: ReaderOpenPosition) => {
    void saveCurrentPosition();
    activeChapterIdRef.current = null;
    lastVisibleBlockRef.current = undefined;
    setModeRestoreTarget(null);
    navigation.setParams({
      position: nextOpenPosition,
      sortNum: String(nextSortNum),
    });
  }, [navigation, saveCurrentPosition]);
  useEffect(() => subscribeReaderChapterSelection(route.key, (selection) => {
    if (selection.bookId === bookId && selection.kind === 'Novel') {
      openChapter(selection.sortNum, selection.openPosition);
    }
  }), [bookId, openChapter, route.key]);
  const changeMode = useCallback((nextMode: ReaderMode) => {
    const currentBlock = lastVisibleBlockRef.current;
    const currentIndex = currentBlock
      ? blocks.findIndex((block) => block.id === currentBlock.id)
      : -1;
    if (content && currentIndex >= 0) {
      setModeRestoreTarget({ chapterId: content.chapter.id, index: currentIndex });
    }
    setMode(nextMode);
    void updateAppSettings({ readerViewMode: nextMode });
  }, [blocks, content]);
  const openChapters = useCallback(() => {
    router.push({
      pathname: '/reader/[bookId]/chapters',
      params: {
        bookId: String(bookId),
        readerKey: route.key,
        sortNum: String(sortNum),
        type: 'Novel',
      },
    });
  }, [bookId, route.key, sortNum]);

  const rawChapterTitle = content?.chapter.title ?? '';
  const readerTitle = rawChapterTitle
    ? settings.cleanChapterTitleScopes.includes('readerTitle')
      ? simplifyReaderChapterTitle(rawChapterTitle)
      : rawChapterTitle
    : '';

  return (
    <>
      <View
        onLayout={(event) => setViewportHeight(event.nativeEvent.layout.height)}
        style={[styles.root, { backgroundColor: readerBackground }]}
      >
      {isLoading || fontLoading ? (
        <View style={styles.centered}><ActivityIndicator color={colors.accent as string} /></View>
      ) : error ? (
        <ReaderErrorState message={error} onRetry={reload} />
      ) : requiresReaderFont && readerFont.status === 'error' ? (
        <ReaderErrorState message="The chapter font could not be loaded, so the encoded text is unavailable." onRetry={readerFont.retry} />
      ) : mode === 'paged' ? (
        <View
          style={[
            styles.pagedRoot,
            { paddingBottom: pagedBottomInset, paddingTop: pagedTopInset },
          ]}
        >
          {readerImages.isReady && !pagedMeasurementReady ? (
            <View pointerEvents="none" style={[styles.measurementLayer, { width: contentWidth }]}>
              {blocks.map((block) => (
                <View
                  key={'measure-' + block.id}
                  onLayout={(event) => onBlockLayout(block.id, event)}
                  style={styles.block}
                >
                  <BookHtmlContent
                    {...readerFontProps}
                    contentWidth={contentWidth}
                    footnotes={chapterPresentation.notesById}
                    html={block.html}
                    imageDimensions={readerImages.dimensions}
                    imageDimensionsLocked
                    imageMaxHeight={pageContentHeight}
                    imageMeasurementOnly
                    onOpenFootnote={openFootnote}
                  />
                </View>
              ))}
            </View>
          ) : null}
          {pagedMeasurementReady ? (
        <FlatList
          contentInsetAdjustmentBehavior="never"
          data={pages}
          key={`paged-${content?.chapter.id ?? sortNum}`}
          getItemLayout={(_, index) => ({ index, length: width, offset: width * index })}
          horizontal
          initialScrollIndex={Math.max(0, pages.findIndex((page) => startIndex >= page.start && startIndex < page.end))}
          keyExtractor={(page) => page.firstBlockId}
          pagingEnabled
          initialNumToRender={2}
          maxToRenderPerBatch={2}
          removeClippedSubviews={process.env.EXPO_OS === 'android'}
          renderItem={({ item }) => (
            <View
              style={[
                styles.page,
                item.end - item.start === 1 &&
                (blocks[item.start]?.imageCount ?? 0) > 0 &&
                (blocks[item.start]?.textLength ?? 0) === 0
                  ? styles.imageOnlyPage
                  : null,
                {
                  backgroundColor: readerBackground,
                  height: pageHeight,
                  paddingHorizontal: sidePadding,
                  width,
                },
              ]}
            >
              {blocks.slice(item.start, item.end).map((block) => (
                <View key={block.id} style={styles.block}>
                  <BookHtmlContent
                    {...readerFontProps}
                    contentWidth={contentWidth}
                    footnotes={chapterPresentation.notesById}
                    html={block.html}
                    imageDimensions={readerImages.dimensions}
                    imageDimensionsLocked
                    imageMaxHeight={pageContentHeight}
                    onOpenFootnote={openFootnote}
                  />
                </View>
              ))}
            </View>
          )}
          showsHorizontalScrollIndicator={false}
          style={styles.reader}
          windowSize={3}
          onMomentumScrollEnd={(event) => {
            const pageIndex = Math.round(event.nativeEvent.contentOffset.x / Math.max(1, width));
            const page = pages[pageIndex];
            const block = page ? blocks[page.start] : undefined;
            lastVisibleBlockRef.current = block;
            savePosition(block);
          }}
        />
          ) : (
            <View style={styles.centered}>
              <ActivityIndicator color={colors.accent as string} />
            </View>
          )}
        </View>
      ) : (
        <View style={styles.scrollReaderRoot}>
        <FlatList
          accessibilityElementsHidden={isRestoringScroll}
          contentInsetAdjustmentBehavior="automatic"
          data={blocks}
          key={`scroll-${scrollRestoreKey}`}
          initialNumToRender={8}
          keyExtractor={(block) => block.id}
          onContentSizeChange={requestScrollRestore}
          onLayout={requestScrollRestore}
          onEndReached={() => {
            if (!scrollRestoreCompletedRef.current) return;
            const last = blocks.at(-1);
            lastVisibleBlockRef.current = last;
            savePosition(last);
          }}
          onEndReachedThreshold={0.02}
          onScrollBeginDrag={() => {
            scrollInteractionStartedRef.current = true;
            scrollRestoreCompletedRef.current = true;
            setRestoredScrollKey(scrollRestoreKey);
            scrollRestoreIndexRef.current = null;
            clearScrollRestoreTimer();
          }}
          onScrollToIndexFailed={({ averageItemLength, index }) => {
            if (scrollInteractionStartedRef.current || !scrollListRef.current) return;
            scrollRestoreAttemptsRef.current += 1;
            scrollRestoreIndexRef.current = index;
            scrollListRef.current.scrollToOffset({
              animated: false,
              offset: Math.max(0, averageItemLength * index),
            });
            clearScrollRestoreTimer();
            scrollRestoreTimerRef.current = setTimeout(() => {
              scrollRestoreTimerRef.current = null;
              requestScrollRestore();
            }, Math.min(240, 48 + scrollRestoreAttemptsRef.current * 16));
          }}
          pointerEvents={isRestoringScroll ? 'none' : 'auto'}
          ref={scrollListRef}
          renderItem={({ item }) => (
            <View style={styles.block}>
              <BookHtmlContent
                {...readerFontProps}
                contentWidth={contentWidth}
                footnotes={chapterPresentation.notesById}
                html={item.html}
                imageDimensions={readerImages.dimensions}
                onOpenFootnote={openFootnote}
              />
            </View>
          )}
          showsVerticalScrollIndicator={false}
          style={[styles.reader, isRestoringScroll && styles.hiddenScrollReader]}
          contentContainerStyle={[styles.scrollContent, { paddingBottom: 24, paddingHorizontal: sidePadding }]}
          maxToRenderPerBatch={6}
          removeClippedSubviews={process.env.EXPO_OS === 'android'}
          updateCellsBatchingPeriod={32}
          onViewableItemsChanged={({ viewableItems }) => {
            const visible = viewableItems
              .filter((item) => item.isViewable && item.index !== null)
              .sort((left, right) => (left.index ?? 0) - (right.index ?? 0));
            const restoreTarget = scrollRestoreIndexRef.current;
            if (!scrollRestoreCompletedRef.current) {
              const reachedTarget = restoreTarget !== null && (
                restoreTarget >= blocks.length - 1
                  ? visible.some((item) => item.index === restoreTarget)
                  : visible[0]?.index === restoreTarget
              );
              if (!reachedTarget) return;
              scrollRestoreIndexRef.current = null;
              scrollRestoreCompletedRef.current = true;
              setRestoredScrollKey(scrollRestoreKey);
              clearScrollRestoreTimer();
            }
            const top = visible[0]?.item as NovelReaderBlock | undefined;
            lastVisibleBlockRef.current = top;
            savePosition(top);
          }}
          viewabilityConfig={READER_VIEWABILITY_CONFIG}
          windowSize={7}
        />
        {isRestoringScroll ? (
          <View
            pointerEvents="none"
            style={[styles.restoreOverlay, { backgroundColor: readerBackground }]}
          >
            <ReaderPreparationState label="Restoring reading position" />
          </View>
        ) : null}
        </View>
      )}
      </View>
      <ReaderNavigation
        backgroundColor={readerBackground}
        foregroundColor={readerTextColor}
        mode={mode}
        onModeChange={changeMode}
        onOpenChapters={openChapters}
        onOpenSettings={() => router.push('/settings/reader')}
        title={readerTitle || 'Reader'}
      />
      <ReaderChapterNavigation
        bottomInset={insets.bottom}
        current={sortNum}
        onNext={nextSortNum === null ? null : () => openChapter(nextSortNum, 'start')}
        onPrevious={previousSortNum === null ? null : () => openChapter(previousSortNum, 'end')}
        total={chapterCount}
      />
    </>
  );
}

const styles = StyleSheet.create({
  root: { backgroundColor: colors.background as string, flex: 1 },
  centered: { alignItems: 'center', flex: 1, justifyContent: 'center' },
  reader: { flex: 1 },
  hiddenScrollReader: { opacity: 0 },
  restoreOverlay: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 1,
  },
  scrollContent: { paddingHorizontal: 16, paddingTop: 16 },
  scrollReaderRoot: { flex: 1 },
  page: {
    overflow: 'hidden',
    paddingBottom: READER_PAGE_VERTICAL_PADDING,
    paddingHorizontal: 16,
    paddingTop: READER_PAGE_VERTICAL_PADDING,
  },
  block: { marginBottom: 12 },
  imageOnlyPage: { justifyContent: 'center' },
  pagedRoot: { flex: 1 },
  measurementLayer: { left: 0, opacity: 0, position: 'absolute', top: 0 },
});
