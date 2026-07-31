import { Image } from 'expo-image';
import {
  IconArrowBackUp,
  IconBook2,
  IconFilePencil,
  IconHexagon,
  IconHistory,
  IconLanguage,
  IconNumber1,
  IconNumber2,
  IconNumber3,
  IconNumber4,
  IconNumber5,
  IconNumber6,
  IconRobot,
  type Icon,
} from '@tabler/icons-react-native';
import { Pressable, StyleSheet, Text as NativeText, View } from 'react-native';

import type { BookCategory, BookListItem } from '@novella/api-client';

import { colors } from '@/theme/colors';

type BadgeIcon = Icon;

interface BookCoverGridItemProps {
  book: BookListItem;
  imageHeight: number;
  tileWidth: number;
  onPress?: () => void;
}

export function BookCoverGridItem({
  book,
  imageHeight,
  onPress,
  tileWidth,
}: BookCoverGridItemProps) {
  const categoryBadge = resolveCategoryBadge(book.category);
  const level = book.interiorLevel || book.level || 0;

  return (
    <Pressable
      accessibilityLabel={book.title}
      accessibilityRole="button"
      onPress={onPress}
      style={[styles.item, { width: tileWidth }]}
    >
      <View style={[styles.coverFrame, { height: imageHeight, width: tileWidth }]}>
        <Image
          accessibilityLabel={`${book.title} cover`}
          contentFit="cover"
          placeholder={book.coverPlaceholder}
          source={book.coverUrl}
          style={StyleSheet.absoluteFill}
          transition={200}
        />

        {level > 0 ? <LevelBadge level={level} interior={Boolean(book.interiorLevel)} /> : null}
        {categoryBadge ? <CategoryBadge badge={categoryBadge} /> : null}
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

const styles = StyleSheet.create({
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
    backgroundColor: colors.card as string,
    borderRadius: 12,
    overflow: 'hidden',
    position: 'relative',
  },
  interiorLevelBadge: {
    backgroundColor: '#FFFFFF',
    borderColor: '#E0A106',
    borderWidth: 1,
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
  },
});
