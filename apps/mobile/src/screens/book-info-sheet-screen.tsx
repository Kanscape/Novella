import { Image } from 'expo-image';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import {
  IconFileDescription,
  IconId,
  IconRefresh,
  IconTag,
  IconUserCircle,
} from '@tabler/icons-react-native';

import { useBookDetailRouteTheme } from '@/components/book-detail-theme-provider';
import { BookHtmlContent } from '@/components/book-html-content';
import { useBookInfo } from '@/hooks/use-book-info';
import type { BookDetailPalette } from '@/theme/book-detail-theme';

export type BookInfoSheetVariant = 'introduction' | 'tags' | 'uploader';

export interface BookInfoSheetScreenProps {
  bookId: number;
  variant: BookInfoSheetVariant;
}

export function BookInfoSheetScreen({ bookId, variant }: BookInfoSheetScreenProps) {
  const { book, error, isLoading, reload } = useBookInfo(bookId);
  const { width } = useWindowDimensions();
  const { palette } = useBookDetailRouteTheme(
    bookId,
    book?.coverUrl ?? null,
    book?.coverPlaceholder ?? null,
  );

  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={styles.content}
      nestedScrollEnabled={process.env.EXPO_OS === 'android'}
      showsVerticalScrollIndicator={false}
      style={[
        styles.scroll,
        { backgroundColor: palette.surface },
        variant === 'introduction' && styles.scrollFill,
      ]}
    >
      {isLoading ? (
        <View style={styles.state}>
          <ActivityIndicator color={palette.primary} />
        </View>
      ) : null}
      {error ? (
        <View style={styles.state}>
          <Text style={[styles.errorText, { color: palette.error }]}>{error}</Text>
          <Pressable
            accessibilityLabel="Try again"
            accessibilityRole="button"
            onPress={reload}
            style={({ pressed }) => [styles.retryButton, pressed && styles.pressed]}
          >
            <IconRefresh color={palette.primary} size={18} strokeWidth={2} />
            <Text style={[styles.retryLabel, { color: palette.primary }]}>Try again</Text>
          </Pressable>
        </View>
      ) : null}
      {book && variant === 'tags' ? (
        <View style={styles.sheetSection}>
          <View style={styles.sheetHeading}>
            <IconTag color={palette.primary} size={22} strokeWidth={2} />
            <Text style={[styles.sheetTitle, { color: palette.onSurface }]}>Book tags</Text>
          </View>
          <View style={styles.tags}>
            {book.classification.tags.map((tag) => (
              <View
                key={tag}
                style={[
                  styles.tag,
                  {
                    backgroundColor: palette.surfaceContainerHighest,
                    borderColor: palette.outlineVariant,
                  },
                ]}
              >
                <Text style={[styles.tagLabel, { color: palette.onSurface }]}>{tag}</Text>
              </View>
            ))}
          </View>
        </View>
      ) : null}
      {book && variant === 'uploader' ? (
        <View style={styles.sheetSection}>
          <View style={styles.sheetHeading}>
            <IconUserCircle color={palette.primary} size={22} strokeWidth={2} />
            <Text style={[styles.sheetTitle, { color: palette.onSurface }]}>Uploader information</Text>
          </View>
          <Text style={[styles.description, { color: palette.onSurfaceVariant }]}>
            View the profile that uploaded this book.
          </Text>
          <View style={[styles.uploaderCard, { backgroundColor: palette.surfaceContainerHighest }]}>
            <UploaderAvatar
              avatarUrl={book.user?.avatarUrl ?? ''}
              palette={palette}
              userName={book.user?.userName ?? ''}
            />
            <View style={styles.uploaderText}>
              <Text numberOfLines={2} style={[styles.uploaderName, { color: palette.onSurface }]}>
                {book.user?.userName.trim() || 'Unknown uploader'}
              </Text>
              <Text style={[styles.description, { color: palette.onSurfaceVariant }]}>
                {book.user && book.user.id > 0 ? 'Book uploader' : 'No uploader profile'}
              </Text>
            </View>
          </View>
          {book.user && book.user.id > 0 ? (
            <View style={[styles.infoItem, { backgroundColor: palette.surfaceContainerHighest }]}>
              <IconId color={palette.primary} size={20} strokeWidth={2} />
              <View style={styles.infoText}>
                <Text style={[styles.infoLabel, { color: palette.onSurfaceVariant }]}>User ID</Text>
                <Text selectable style={[styles.infoValue, { color: palette.onSurface }]}>
                  {book.user.id}
                </Text>
              </View>
            </View>
          ) : null}
        </View>
      ) : null}
      {book && variant === 'introduction' ? (
        <View style={styles.sheetSection}>
          <View style={styles.sheetHeading}>
            <IconFileDescription color={palette.primary} size={22} strokeWidth={2} />
            <Text style={[styles.sheetTitle, { color: palette.onSurface }]}>Introduction</Text>
          </View>
          <BookHtmlContent
            contentWidth={Math.max(1, width - 48)}
            html={book.introduction}
            textColor={palette.onSurface}
          />
        </View>
      ) : null}
    </ScrollView>
  );
}

function UploaderAvatar({
  avatarUrl,
  palette,
  userName,
}: {
  avatarUrl: string;
  palette: BookDetailPalette;
  userName: string;
}) {
  const fallback = userName.trim().slice(0, 1).toUpperCase() || '?';
  return avatarUrl ? (
    <Image accessibilityLabel={`${userName} avatar`} source={avatarUrl} style={styles.avatar} />
  ) : (
    <View style={[styles.avatarFallback, { backgroundColor: palette.surfaceContainerHighest }]}>
      <Text style={[styles.avatarFallbackLabel, { color: palette.onSurface }]}>{fallback}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  avatar: { borderRadius: 28, height: 56, width: 56 },
  avatarFallback: { alignItems: 'center', borderRadius: 28, height: 56, justifyContent: 'center', width: 56 },
  avatarFallbackLabel: { fontSize: 24, fontWeight: '700' },
  content: {
    paddingBottom: 48,
    paddingHorizontal: 24,
    paddingTop: process.env.EXPO_OS === 'android' ? 8 : 28,
  },
  description: { fontSize: 13, lineHeight: 18 },
  errorText: { fontSize: 15, lineHeight: 21, textAlign: 'center' },
  infoItem: { alignItems: 'flex-start', borderRadius: 16, flexDirection: 'row', gap: 12, padding: 14 },
  infoLabel: { fontSize: 12, lineHeight: 16 },
  infoText: { flex: 1, gap: 4 },
  infoValue: { fontSize: 16, fontWeight: '600', lineHeight: 22 },
  pressed: { opacity: 0.68 },
  retryButton: { alignItems: 'center', flexDirection: 'row', gap: 7, padding: 8 },
  retryLabel: { fontSize: 15, fontWeight: '600' },
  scroll: {},
  scrollFill: { flex: 1 },
  sheetHeading: { alignItems: 'center', flexDirection: 'row', gap: 10 },
  sheetSection: { gap: 16 },
  sheetTitle: { fontSize: 17, fontWeight: '700', lineHeight: 22 },
  state: { alignItems: 'center', gap: 12, paddingVertical: 48 },
  tag: { borderRadius: 8, borderWidth: 0.5, paddingHorizontal: 12, paddingVertical: 7 },
  tagLabel: { fontSize: 14, lineHeight: 18 },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  uploaderCard: { alignItems: 'center', borderRadius: 20, flexDirection: 'row', gap: 14, padding: 16 },
  uploaderName: { fontSize: 17, fontWeight: '700', lineHeight: 22 },
  uploaderText: { flex: 1, gap: 4 },
});
