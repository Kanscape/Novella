import {
  IconCheck,
  IconFolder,
  IconFolderOpen,
  IconGripVertical,
} from '@tabler/icons-react-native';
import {
  Pressable,
  StyleSheet,
  Text,
  View,
  type AccessibilityActionEvent,
  type AccessibilityActionInfo,
  type GestureResponderEvent,
} from 'react-native';

import type { BookListItem } from '@novella/api-client';

import { BookCoverImage } from '@/components/book-cover-image';
import { BOOK_COVER_ASPECT_RATIO } from '@/components/book-cover-grid-item';
import { colors } from '@/theme/colors';

interface ShelfFolderGridItemProps {
  accessibilityActions?: readonly AccessibilityActionInfo[];
  interactionState?: 'default' | 'selected' | 'sorting';
  itemCount: number;
  onAccessibilityAction?: (event: AccessibilityActionEvent) => void;
  onLongPress?: (event: GestureResponderEvent) => void;
  onPress: () => void;
  onPressOut?: () => void;
  previewBooks: BookListItem[];
  tileWidth: number;
  title: string;
}

export function ShelfFolderGridItem({
  accessibilityActions,
  interactionState = 'default',
  itemCount,
  onAccessibilityAction,
  onLongPress,
  onPress,
  onPressOut,
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
      {...(accessibilityActions ? { accessibilityActions: [...accessibilityActions] } : {})}
      accessibilityLabel={`${title}, folder, ${itemCount} items`}
      accessibilityRole="button"
      accessibilityState={{ selected: interactionState === 'selected' }}
      delayLongPress={180}
      onAccessibilityAction={onAccessibilityAction}
      onLongPress={onLongPress}
      onPress={onPress}
      onPressOut={onPressOut}
      style={[styles.item, { width: tileWidth }]}
    >
      <View
        style={[
          styles.coverFrame,
          { aspectRatio: BOOK_COVER_ASPECT_RATIO, width: tileWidth },
        ]}
      >
        {previewBooks.length === 0 ? (
          <View style={styles.emptyFolder}>
            <IconFolderOpen color={colors.accent as string} size={56} strokeWidth={1.7} />
          </View>
        ) : previewBooks.length === 1 && firstBook ? (
          <BookCoverImage
            accessibilityLabel={`${firstBook.title} cover`}
            animateCachedImage
            blurHash={firstBook.coverPlaceholder}
            source={firstBook.coverUrl}
          />
        ) : (
          <View style={styles.previewGrid}>
            {slots.map((book, index) => (
              <View
                key={book ? `${book.type}-${book.id}` : `empty-${index}`}
                style={[styles.previewSlot, { height: previewHeight, width: previewWidth }]}
              >
                {book ? (
                  <BookCoverImage
                    accessibilityLabel={`${book.title} cover`}
                    animateCachedImage
                    blurHash={book.coverPlaceholder}
                    source={book.coverUrl}
                  />
                ) : null}
              </View>
            ))}
          </View>
        )}
        <View style={styles.folderBadge}>
          <IconFolder color="#FFFFFF" size={15} strokeWidth={2} />
        </View>
        {interactionState !== 'default' ? (
          <View
            pointerEvents="none"
            style={[
              styles.interactionOverlay,
              interactionState === 'selected' ? styles.selectedOverlay : styles.sortingOverlay,
            ]}
          >
            {interactionState === 'selected' ? (
              <IconCheck color="#FFFFFF" size={34} strokeWidth={2.5} />
            ) : (
              <IconGripVertical color="#FFFFFF" size={36} strokeWidth={2.2} />
            )}
          </View>
        ) : null}
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
  interactionOverlay: {
    alignItems: 'center',
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
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
  selectedOverlay: {
    backgroundColor: 'rgba(217, 71, 93, 0.72)',
  },
  sortingOverlay: {
    backgroundColor: 'rgba(0, 0, 0, 0.48)',
  },
  title: {
    color: colors.label as string,
    fontSize: 13,
    lineHeight: 16,
    textAlign: 'center',
  },
  titleContainer: {
    height: 40,
    justifyContent: 'center',
    paddingHorizontal: 2,
    width: '100%',
  },
});
