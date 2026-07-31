import { Image } from 'expo-image';
import { IconFolder, IconFolderOpen } from '@tabler/icons-react-native';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { BookListItem } from '@novella/api-client';

import { colors } from '@/theme/colors';

interface ShelfFolderGridItemProps {
  imageHeight: number;
  itemCount: number;
  onPress: () => void;
  previewBooks: BookListItem[];
  tileWidth: number;
  title: string;
}

export function ShelfFolderGridItem({
  imageHeight,
  itemCount,
  onPress,
  previewBooks,
  tileWidth,
  title,
}: ShelfFolderGridItemProps) {
  const previewWidth = Math.max(1, Math.floor((tileWidth - 28) / 2));
  const previewHeight = Math.round(previewWidth * 1.5);
  const firstBook = previewBooks[0];
  const slots = [...previewBooks.slice(0, 4), ...Array(4).fill(null)].slice(0, 4);

  return (
    <Pressable
      accessibilityLabel={`${title}, folder, ${itemCount} items`}
      accessibilityRole="button"
      onPress={onPress}
      style={[styles.item, { width: tileWidth }]}
    >
      <View style={[styles.coverFrame, { height: imageHeight, width: tileWidth }]}>
        {previewBooks.length === 0 ? (
          <View style={styles.emptyFolder}>
            <IconFolderOpen color={colors.accent as string} size={56} strokeWidth={1.7} />
          </View>
        ) : previewBooks.length === 1 && firstBook ? (
          <Image
            accessibilityLabel={`${firstBook.title} cover`}
            contentFit="cover"
            placeholder={firstBook.coverPlaceholder}
            source={firstBook.coverUrl}
            style={StyleSheet.absoluteFill}
            transition={200}
          />
        ) : (
          <View style={styles.previewGrid}>
            {slots.map((book, index) => (
              <View
                key={book ? `${book.type}-${book.id}` : `empty-${index}`}
                style={[styles.previewSlot, { height: previewHeight, width: previewWidth }]}
              >
                {book ? (
                  <Image
                    accessibilityLabel={`${book.title} cover`}
                    contentFit="cover"
                    placeholder={book.coverPlaceholder}
                    source={book.coverUrl}
                    style={StyleSheet.absoluteFill}
                    transition={200}
                  />
                ) : null}
              </View>
            ))}
          </View>
        )}
        <View style={styles.folderBadge}>
          <IconFolder color="#FFFFFF" size={15} strokeWidth={2} />
        </View>
      </View>
      <View style={styles.titleContainer}>
        <Text numberOfLines={2} style={styles.title}>
          {title}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  coverFrame: {
    backgroundColor: colors.card as string,
    borderRadius: 12,
    overflow: 'hidden',
    position: 'relative',
  },
  emptyFolder: {
    alignItems: 'center',
    backgroundColor: colors.card as string,
    flex: 1,
    justifyContent: 'center',
  },
  folderBadge: {
    alignItems: 'center',
    backgroundColor: colors.accent as string,
    borderRadius: 8,
    bottom: 4,
    justifyContent: 'center',
    padding: 4,
    position: 'absolute',
    right: 4,
  },
  item: {
    alignItems: 'center',
  },
  previewGrid: {
    alignContent: 'center',
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    justifyContent: 'center',
    padding: 10,
  },
  previewSlot: {
    backgroundColor: colors.card as string,
    borderRadius: 6,
    overflow: 'hidden',
    position: 'relative',
  },
  title: {
    color: colors.label as string,
    fontSize: 13,
    lineHeight: 16,
    textAlign: 'center',
  },
  titleContainer: {
    height: 36,
    justifyContent: 'center',
    paddingHorizontal: 2,
    width: '100%',
  },
});
