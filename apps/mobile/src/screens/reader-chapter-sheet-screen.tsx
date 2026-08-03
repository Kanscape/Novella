import { Stack, router, useLocalSearchParams } from 'expo-router';
import { IconListDetails } from '@tabler/icons-react-native';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import type { BookDetail, ComicInfo } from '@novella/api-client';

import { useBookDetailRouteTheme } from '@/components/book-detail-theme-provider';
import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { ReaderChapterList, type ReaderChapterListItem } from '@/components/reader-chapter-list';
import { bookDetails, reader } from '@/services/client';
import {
  publishReaderChapterSelection,
  type ReaderChapterKind,
} from '@/services/reader-chapter-selection';

export function ReaderChapterSheetScreen() {
  const {
    bookId: rawBookId,
    readerKey = '',
    sortNum: rawSortNum,
    type: rawType,
  } = useLocalSearchParams<{
    bookId: string;
    readerKey?: string;
    sortNum?: string;
    type?: string;
  }>();
  const bookId = Number(rawBookId);
  const kind: ReaderChapterKind = rawType === 'Comic' ? 'Comic' : 'Novel';
  const currentSortNum = Number(rawSortNum);
  const palette = useBookDetailRouteTheme(bookId, null, null, true).palette;
  const [source, setSource] = useState<BookDetail | ComicInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setSource(kind === 'Comic' ? await reader.loadComicInfo(bookId) : await bookDetails.load(bookId));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'The chapters could not be loaded.');
    }
  }, [bookId, kind]);

  useEffect(() => {
    void load();
  }, [load]);

  const items = useMemo<ReaderChapterListItem[]>(() => {
    if (!source) return [];
    if (kind === 'Comic') {
      const info = source as ComicInfo;
      return info.chapters.map((chapter) => ({
        id: chapter.id,
        isCurrent: chapter.sortNum === currentSortNum,
        sortNum: chapter.sortNum,
        subtitle: `${chapter.pageCount} pages`,
        title: chapter.title,
      }));
    }
    const book = source as BookDetail;
    return book.chapters.map((chapter, index) => ({
      id: chapter.id,
      isCurrent: index + 1 === currentSortNum,
      sortNum: index + 1,
      title: chapter.title,
    }));
  }, [currentSortNum, kind, source]);

  const savedChapterId = source?.readPosition?.chapterId;
  const selectChapter = useCallback((item: ReaderChapterListItem) => {
    publishReaderChapterSelection({
      bookId,
      kind,
      openPosition:
        item.sortNum === currentSortNum || item.id === savedChapterId
          ? 'saved'
          : 'start',
      readerKey,
      sortNum: item.sortNum,
    });
    router.back();
  }, [bookId, currentSortNum, kind, readerKey, savedChapterId]);

  const heading = (
    <View style={styles.heading}>
      <IconListDetails color={palette.primary} size={22} strokeWidth={2} />
      <Text style={[styles.headingTitle, { color: palette.onSurface }]}>Chapters</Text>
    </View>
  );

  return (
    <NativeRouteBottomSheet bookId={bookId} snapPoints={['50%', '100%']}>
      <Stack.Screen options={{ headerShown: false, title: 'Chapters' }} />
      <ReaderChapterList
        emptyState={
          <View style={styles.centered}>
            {!source && !error ? (
              <ActivityIndicator color={palette.primary} />
            ) : (
              <Text style={[styles.error, { color: palette.onSurfaceVariant }]}>{error}</Text>
            )}
          </View>
        }
        header={heading}
        items={items}
        onSelect={selectChapter}
        palette={palette}
      />
    </NativeRouteBottomSheet>
  );
}

const styles = StyleSheet.create({
  centered: { alignItems: 'center', justifyContent: 'center', minHeight: 180, padding: 24 },
  error: { fontSize: 14, textAlign: 'center' },
  heading: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
    paddingBottom: 16,
    paddingHorizontal: 8,
    paddingTop: process.env.EXPO_OS === 'android' ? 0 : 12,
  },
  headingTitle: { fontSize: 17, fontWeight: '700', lineHeight: 22 },
});
