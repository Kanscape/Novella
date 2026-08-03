import { IconNote } from '@tabler/icons-react-native';
import { ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';

import { BookHtmlContent } from '@/components/book-html-content';
import { useBookDetailRouteTheme } from '@/components/book-detail-theme-provider';
import type { ReaderFootnoteSession } from '@/services/reader-footnote-session';

export interface ReaderFootnoteSheetScreenProps {
  bookId: number;
  session: ReaderFootnoteSession | undefined;
}

export function ReaderFootnoteSheetScreen({
  bookId,
  session,
}: ReaderFootnoteSheetScreenProps) {
  const { width } = useWindowDimensions();
  const { palette } = useBookDetailRouteTheme(bookId, null, null, true);

  return (
    <ScrollView
      contentContainerStyle={styles.content}
      nestedScrollEnabled={process.env.EXPO_OS === 'android'}
      showsVerticalScrollIndicator={false}
      style={[styles.scroll, { backgroundColor: palette.surface }]}
    >
      <View style={styles.section}>
        <View style={styles.heading}>
          <IconNote color={palette.primary} size={22} strokeWidth={2} />
          <Text style={[styles.title, { color: palette.onSurface }]}>注释</Text>
        </View>
        {session ? (
          <BookHtmlContent
            contentWidth={Math.max(1, width - 48)}
            fontSize={session.fontSize}
            html={session.html}
            lineHeight={session.lineHeight}
            textColor={palette.onSurface}
            {...(session.fontFamily ? { fontFamily: session.fontFamily } : {})}
          />
        ) : (
          <Text style={[styles.unavailableText, { color: palette.onSurfaceVariant }]}>This footnote is no longer available.</Text>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingBottom: 48,
    paddingHorizontal: 24,
    paddingTop: process.env.EXPO_OS === 'android' ? 8 : 28,
  },
  heading: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
  },
  scroll: { flex: 1 },
  section: { gap: 16 },
  title: {
    fontSize: 17,
    fontWeight: '700',
    lineHeight: 22,
  },
  unavailableText: {
    fontSize: 15,
    lineHeight: 21,
  },
});
