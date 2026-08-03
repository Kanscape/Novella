import { Stack, router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { IconChevronRight, IconRefresh } from '@tabler/icons-react-native';
import type { ComicInfo } from '@novella/api-client';

import { BookCoverImage } from '@/components/book-cover-image';
import { reader } from '@/services/client';
import { colors } from '@/theme/colors';

export interface ComicDetailScreenProps {
  bookId: number;
  initialCoverPlaceholder?: string;
  initialCoverUrl?: string;
  initialTitle?: string;
}

export function ComicDetailScreen({
  bookId,
  initialCoverPlaceholder,
  initialCoverUrl,
  initialTitle,
}: ComicDetailScreenProps) {
  const insets = useSafeAreaInsets();
  const [info, setInfo] = useState<ComicInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const load = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      setInfo(await reader.loadComicInfo(bookId));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'The comic could not be loaded.');
    } finally {
      setIsLoading(false);
    }
  }, [bookId]);

  useEffect(() => { void load(); }, [load]);

  const resumeChapter = info?.readPosition
    ? info.chapters.find((chapter) => chapter.id === info.readPosition?.chapterId)
    : undefined;
  const firstChapter = info?.chapters[0];
  const hintedCoverUrl = initialCoverUrl?.trim() ? initialCoverUrl : null;
  const coverUrl = hintedCoverUrl ?? info?.coverUrl ?? null;
  const coverPlaceholder = hintedCoverUrl
    ? initialCoverPlaceholder ?? info?.coverPlaceholder ?? null
    : info?.coverPlaceholder ?? null;

  const openReader = (sortNum: number, position: 'saved' | 'start' | 'end' = 'saved') => {
    router.push({
      pathname: '/reader/[bookId]/[sortNum]',
      params: { bookId: String(bookId), sortNum: String(sortNum), type: 'Comic', position },
    });
  };

  return (
    <View style={styles.root}>
      <Stack.Screen options={{ title: info?.title ?? initialTitle ?? 'Comic' }} />
      {isLoading ? (
        <View style={styles.centered}><ActivityIndicator color={colors.accent as string} /></View>
      ) : error ? (
        <View style={styles.centered}>
          <Text style={styles.errorText}>{error}</Text>
          <Pressable accessibilityLabel="Retry comic" onPress={load} style={styles.retry}><IconRefresh color={colors.accent as string} size={18} /><Text style={styles.retryText}>Try again</Text></Pressable>
        </View>
      ) : info ? (
        <ScrollView contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 28 }]} showsVerticalScrollIndicator={false}>
          <View style={styles.header}>
            <View style={styles.cover}>
              <BookCoverImage
                accessibilityLabel={`${info.title} cover`}
                blurHash={coverPlaceholder}
                source={coverUrl ?? ''}
              />
            </View>
            <View style={styles.headerText}>
              <Text style={styles.title}>{info.title}</Text>
              {info.authorName ? <Text style={styles.author}>{info.authorName}</Text> : null}
              <Text style={styles.metadata}>{info.chapters.length} chapters · {info.views} views</Text>
              {resumeChapter ? <Pressable accessibilityLabel={`Continue ${resumeChapter.title}`} onPress={() => openReader(resumeChapter.sortNum)} style={styles.resumeButton}><Text style={styles.resumeText}>Continue reading</Text><IconChevronRight color={colors.onPrimaryContainer as string} size={18} /></Pressable> : firstChapter ? <Pressable accessibilityLabel="Start reading" onPress={() => openReader(firstChapter.sortNum, 'start')} style={styles.resumeButton}><Text style={styles.resumeText}>Start reading</Text><IconChevronRight color={colors.onPrimaryContainer as string} size={18} /></Pressable> : null}
            </View>
          </View>
          {info.introduction.trim() ? <Text style={styles.introduction}>{info.introduction}</Text> : null}
          <Text style={styles.sectionTitle}>Chapters</Text>
          <View style={styles.chapterList}>
            {info.chapters.map((chapter) => (
              <Pressable accessibilityLabel={`Read ${chapter.title}`} key={chapter.id} onPress={() => openReader(chapter.sortNum, chapter.id === resumeChapter?.id ? 'saved' : 'start')} style={({ pressed }) => [styles.chapterRow, pressed && styles.pressed]}>
                <View style={styles.chapterText}><Text numberOfLines={1} style={styles.chapterTitle}>{chapter.title}</Text><Text style={styles.chapterMetadata}>{chapter.pageCount} pages</Text></View>
                <IconChevronRight color={colors.secondaryLabel as string} size={19} />
              </Pressable>
            ))}
          </View>
        </ScrollView>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { backgroundColor: colors.background as string, flex: 1 },
  centered: { alignItems: 'center', flex: 1, justifyContent: 'center', padding: 24 },
  content: { gap: 22, padding: 20 },
  header: { flexDirection: 'row', gap: 16 },
  cover: { backgroundColor: colors.card as string, borderCurve: 'continuous', borderRadius: 10, height: 210, overflow: 'hidden', width: 140 },
  headerText: { flex: 1, gap: 8, justifyContent: 'center' },
  title: { color: colors.label as string, fontSize: 22, fontWeight: '700', lineHeight: 28 },
  author: { color: colors.secondaryLabel as string, fontSize: 15 },
  metadata: { color: colors.secondaryLabel as string, fontSize: 13 },
  resumeButton: { alignItems: 'center', alignSelf: 'flex-start', backgroundColor: colors.accent as string, borderRadius: 9, flexDirection: 'row', gap: 4, paddingHorizontal: 12, paddingVertical: 9 },
  resumeText: { color: colors.onPrimaryContainer as string, fontSize: 14, fontWeight: '700' },
  introduction: { color: colors.secondaryLabel as string, fontSize: 15, lineHeight: 23 },
  sectionTitle: { color: colors.label as string, fontSize: 19, fontWeight: '700' },
  chapterList: { backgroundColor: colors.surface as string, borderRadius: 12, overflow: 'hidden' },
  chapterRow: { alignItems: 'center', borderBottomColor: colors.separator as string, borderBottomWidth: StyleSheet.hairlineWidth, flexDirection: 'row', gap: 10, justifyContent: 'space-between', minHeight: 62, paddingHorizontal: 16, paddingVertical: 10 },
  chapterText: { flex: 1, gap: 4 },
  chapterTitle: { color: colors.label as string, fontSize: 15, fontWeight: '600' },
  chapterMetadata: { color: colors.secondaryLabel as string, fontSize: 13 },
  errorText: { color: colors.secondaryLabel as string, marginBottom: 14, textAlign: 'center' },
  retry: { alignItems: 'center', flexDirection: 'row', gap: 6, padding: 10 },
  retryText: { color: colors.accent as string, fontWeight: '600' },
  pressed: { opacity: 0.7 },
});
