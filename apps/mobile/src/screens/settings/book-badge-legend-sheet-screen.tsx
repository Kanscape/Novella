import { IconBadges } from '@tabler/icons-react-native';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { BookTypeBadgeIcon } from '@/components/book-type-badge';
import { BOOK_BADGE_LEGEND_DEFINITIONS } from '@/services/book-badge-definitions';
import { useAppTheme } from '@/theme/app-theme';

export function BookBadgeLegendSheetScreen() {
  const { colors } = useAppTheme();

  return (
    <ScrollView
      contentContainerStyle={styles.content}
      contentInsetAdjustmentBehavior="automatic"
      nestedScrollEnabled={process.env.EXPO_OS === 'android'}
      showsVerticalScrollIndicator={false}
      style={styles.scroll}
    >
      <View style={styles.sheetSection}>
        <View style={styles.sheetHeading}>
          <IconBadges
            color={colors.accent as string}
            size={22}
            strokeWidth={2}
          />
          <Text style={[styles.sheetTitle, { color: colors.label }]}>
            Badge meanings
          </Text>
        </View>
        <Text style={[styles.description, { color: colors.secondaryLabel }]}>
          Preview all book-cover badges supported by Novella. The app always
          shows these badges wherever a supported book cover is displayed.
        </Text>
        <View style={styles.badgeList}>
          {BOOK_BADGE_LEGEND_DEFINITIONS.map((badge) => (
            <View
              key={badge.id}
              style={[
                styles.badgeCard,
                { backgroundColor: colors.surfaceContainerHighest },
              ]}
            >
              <View
                style={[
                  styles.badgePreview,
                  { width: badge.level === undefined ? 44 : 68 },
                ]}
              >
                <BookTypeBadgeIcon badge={badge} />
              </View>
              <View style={styles.badgeText}>
                <Text style={[styles.badgeLabel, { color: colors.label }]}>
                  {badge.label}
                </Text>
                <Text
                  style={[
                    styles.badgeMeaning,
                    { color: colors.secondaryLabel },
                  ]}
                >
                  {badge.meaning}
                </Text>
              </View>
            </View>
          ))}
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  badgeCard: {
    alignItems: 'center',
    borderRadius: 16,
    flexDirection: 'row',
    gap: 12,
    padding: 12,
  },
  badgeLabel: { fontSize: 16, fontWeight: '600', lineHeight: 21 },
  badgeList: { gap: 10 },
  badgeMeaning: { fontSize: 15, lineHeight: 20 },
  badgePreview: { alignItems: 'center', justifyContent: 'center' },
  badgeText: { flex: 1, gap: 2 },
  content: {
    gap: 16,
    paddingBottom: 48,
    paddingHorizontal: 24,
    paddingTop: process.env.EXPO_OS === 'android' ? 8 : 28,
  },
  description: { fontSize: 13, lineHeight: 18 },
  scroll: { flex: 1 },
  sheetHeading: { alignItems: 'center', flexDirection: 'row', gap: 10 },
  sheetSection: { gap: 16 },
  sheetTitle: { fontSize: 17, fontWeight: '700', lineHeight: 22 },
});
