import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { ComicSeriesListItem } from '@novella/api-client';

import { BOOK_COVER_ASPECT_RATIO } from '@/components/book-cover-grid-item';
import { BookCoverImage } from '@/components/book-cover-image';
import { colors } from '@/theme/colors';

export interface ComicSeriesGridItemProps {
  item: ComicSeriesListItem;
  onPress(): void;
  tileWidth: number;
}

export function ComicSeriesGridItem({ item, onPress, tileWidth }: ComicSeriesGridItemProps) {
  return (
    <Pressable
      accessibilityLabel={`${item.title}, comic series, ${item.volumeCount} volumes`}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.root, { width: tileWidth }, pressed && styles.pressed]}
    >
      <View style={[styles.cover, { aspectRatio: BOOK_COVER_ASPECT_RATIO, width: tileWidth }]}>
        <BookCoverImage
          accessibilityLabel={`${item.title} cover`}
          blurHash={item.coverPlaceholder}
          source={item.coverUrl}
        />
      </View>
      <Text numberOfLines={2} style={styles.title}>{item.title}</Text>
      <Text numberOfLines={1} style={styles.metadata}>
        {item.volumeCount === 1 ? '1 volume' : `${item.volumeCount} volumes`}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  cover: {
    backgroundColor: colors.card as string,
    borderCurve: 'continuous',
    borderRadius: 12,
    overflow: 'hidden',
  },
  metadata: {
    color: colors.secondaryLabel as string,
    fontSize: 12,
    lineHeight: 16,
    textAlign: 'center',
  },
  pressed: { opacity: 0.72 },
  root: { alignItems: 'center', gap: 3 },
  title: {
    color: colors.label as string,
    fontSize: 13,
    lineHeight: 16,
    minHeight: 32,
    paddingHorizontal: 2,
    textAlign: 'center',
  },
});
