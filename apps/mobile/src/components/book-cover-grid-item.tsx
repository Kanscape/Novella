import {
  IconArrowBackUp,
  IconBook2,
  IconFilePencil,
  IconHexagon,
  IconHistory,
  IconGripVertical,
  IconLanguage,
  IconNumber1,
  IconNumber2,
  IconNumber3,
  IconNumber4,
  IconNumber5,
  IconNumber6,
  IconRobot,
  IconCheck,
  type Icon,
} from '@tabler/icons-react-native';
import {
  Pressable,
  StyleSheet,
  Text as NativeText,
  View,
  type AccessibilityActionEvent,
  type AccessibilityActionInfo,
  type GestureResponderEvent,
} from 'react-native';

import type { BookCategory, BookListItem } from '@novella/api-client';

import { BookCoverImage } from '@/components/book-cover-image';
import { createThemedStyles } from '@/theme/app-theme';

type BadgeIcon = Icon;

export const BOOK_COVER_ASPECT_RATIO = 2 / 3;

interface BookCoverGridItemProps {
  accessibilityActions?: readonly AccessibilityActionInfo[];
  animateCachedImage?: boolean;
  book: BookListItem;
  interactionState?: 'default' | 'selected' | 'sorting';
  onAccessibilityAction?: (event: AccessibilityActionEvent) => void;
  onLongPress?: (event: GestureResponderEvent) => void;
  onPress?: () => void;
  onPressOut?: () => void;
  /** Leaderboard position; renders a gold/silver/bronze badge for ranks 1-3. */
  rank?: number;
  tileWidth: number;
}

export function BookCoverGridItem({
  accessibilityActions,
  animateCachedImage,
  book,
  interactionState = 'default',
  onAccessibilityAction,
  onLongPress,
  onPress,
  onPressOut,
  rank,
  tileWidth,
}: BookCoverGridItemProps) {
  const styles = useBookCoverGridItemStyles();
  const categoryBadge = resolveCategoryBadge(book.category);
  const level = book.interiorLevel || book.level || 0;

  return (
    <Pressable
      {...(accessibilityActions ? { accessibilityActions: [...accessibilityActions] } : {})}
      accessibilityLabel={book.title}
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
        <BookCoverImage
          accessibilityLabel={`${book.title} cover`}
          {...(animateCachedImage === undefined ? {} : { animateCachedImage })}
          blurHash={book.coverPlaceholder}
          source={book.coverUrl}
        />

        {level > 0 ? <LevelBadge level={level} interior={Boolean(book.interiorLevel)} /> : null}
        {categoryBadge ? <CategoryBadge badge={categoryBadge} /> : null}
        {rank !== undefined && rank > 0 && rank <= 3 ? <RankBadge rank={rank} /> : null}
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
      <View style={[styles.titleContainer, { width: tileWidth }]}>
        <NativeText numberOfLines={2} style={styles.title}>
          {book.title}
        </NativeText>
      </View>
    </Pressable>
  );
}

function CategoryBadge({ badge }: { badge: CategoryBadge }) {
  const styles = useBookCoverGridItemStyles();
  const BadgeIcon = badge.icon;
  return (
    <View style={[styles.categoryBadge, { backgroundColor: badge.backgroundColor }]}>
      <BadgeIcon
        accessibilityLabel={badge.label}
        color={badge.iconColor}
        size={15}
        strokeWidth={2}
      />
    </View>
  );
}

function LevelBadge({ level, interior }: { level: number; interior: boolean }) {
  const styles = useBookCoverGridItemStyles();
  const safeLevel = Math.min(6, Math.max(1, Math.trunc(level))) as 1 | 2 | 3 | 4 | 5 | 6;
  const LevelIcon = levelIcons[safeLevel];
  const color = interior ? '#E0A106' : '#FFFFFF';
  return (
    <View
      style={[
        styles.levelBadge,
        interior ? styles.interiorLevelBadge : styles.publicLevelBadge,
      ]}
    >
      <IconHexagon
        accessibilityLabel={interior ? 'Interior level' : 'Level'}
        color={color}
        size={13}
        strokeWidth={2}
      />
      <LevelIcon
        accessibilityLabel={`Level ${safeLevel}`}
        color={color}
        size={15}
        strokeWidth={2}
      />
    </View>
  );
}

function RankBadge({ rank }: { rank: number }) {
  const styles = useBookCoverGridItemStyles();
  const color = rank === 1 ? '#FFD700' : rank === 2 ? '#78909C' : '#CD7F32';
  return (
    <View style={[styles.rankBadge, { backgroundColor: color }]}>
      <NativeText style={styles.rankLabel}>{String(rank)}</NativeText>
    </View>
  );
}

interface CategoryBadge {
  backgroundColor: string;
  icon: BadgeIcon;
  iconColor: string;
  label: string;
}

function resolveCategoryBadge(category: BookCategory | null): CategoryBadge | null {
  if (!category) return null;
  const name = category.name.trim();
  const shortName = category.shortName.trim();
  if (name === '录入完成' || shortName === '录入' || shortName === '录入完成') {
    return { backgroundColor: '#EC1282', icon: IconFilePencil, iconColor: '#FFFFFF', label: '录入' };
  }
  if (name === '翻译完成' || shortName === '翻译' || shortName === '翻译完成') {
    return { backgroundColor: '#1976D2', icon: IconLanguage, iconColor: '#FFFFFF', label: '翻译' };
  }
  if (name === '转载') return { backgroundColor: '#F1570E', icon: IconArrowBackUp, iconColor: '#FFFFFF', label: '转载' };
  if (name === '原创') return { backgroundColor: '#7B1FA2', icon: IconHistory, iconColor: '#FFFFFF', label: '原创' };
  if (name === '日文原版' || shortName === '日文' || shortName === '日原') {
    return { backgroundColor: '#C62828', icon: IconBook2, iconColor: '#FFFFFF', label: '日文' };
  }
  if (name === 'AI翻译' || shortName === 'AI') {
    return { backgroundColor: '#2EAF5D', icon: IconRobot, iconColor: '#FFFFFF', label: 'AI' };
  }
  if (name === '录入中' || shortName === '录入中') {
    return { backgroundColor: '#9E9E9E', icon: IconFilePencil, iconColor: '#FFFFFF', label: '录入中' };
  }
  if (name === '翻译中' || shortName === '翻译中') {
    return { backgroundColor: '#9E9E9E', icon: IconLanguage, iconColor: '#FFFFFF', label: '翻译中' };
  }
  return null;
}

const levelIcons: Record<1 | 2 | 3 | 4 | 5 | 6, BadgeIcon> = {
  1: IconNumber1,
  2: IconNumber2,
  3: IconNumber3,
  4: IconNumber4,
  5: IconNumber5,
  6: IconNumber6,
};

const useBookCoverGridItemStyles = createThemedStyles((colors) => ({
  categoryBadge: {
    alignItems: 'center',
    borderRadius: 8,
    bottom: 0,
    justifyContent: 'center',
    padding: 4,
    position: 'absolute',
    right: 0,
  },
  coverFrame: {
    backgroundColor: colors.card,
    borderRadius: 12,
    overflow: 'hidden',
    position: 'relative',
  },
  interiorLevelBadge: {
    backgroundColor: '#FFFFFF',
    borderColor: '#E0A106',
    borderWidth: 1,
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
  levelBadge: {
    alignItems: 'center',
    borderRadius: 8,
    flexDirection: 'row',
    gap: 4,
    justifyContent: 'center',
    paddingHorizontal: 6,
    paddingVertical: 4,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  publicLevelBadge: {
    backgroundColor: '#E0A106',
  },
  rankBadge: {
    borderRadius: 8,
    left: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    position: 'absolute',
    top: 4,
  },
  rankLabel: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '700',
  },
  selectedOverlay: {
    backgroundColor: 'rgba(217, 71, 93, 0.72)',
  },
  sortingOverlay: {
    backgroundColor: 'rgba(0, 0, 0, 0.48)',
  },
  title: {
    color: colors.label,
    fontSize: 13,
    lineHeight: 16,
    textAlign: 'center',
  },
  titleContainer: {
    height: 40,
    justifyContent: 'center',
    paddingHorizontal: 2,
  },
}));
