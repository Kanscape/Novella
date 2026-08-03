import { Stack } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import type { ReaderChapterNavigationProps } from '@/components/reader-navigation.types';
import { colors } from '@/theme/colors';

export function ReaderChapterNavigation({
  bottomInset,
  current,
  onNext,
  onPrevious,
  total,
}: ReaderChapterNavigationProps) {
  return (
    <>
      <Stack.Toolbar placement="bottom">
        <Stack.Toolbar.Button
          accessibilityLabel="Previous chapter"
          disabled={onPrevious === null}
          icon="chevron.left"
          {...(onPrevious ? { onPress: onPrevious } : {})}
        />
        <Stack.Toolbar.Spacer />
        <Stack.Toolbar.Button
          accessibilityLabel="Next chapter"
          disabled={onNext === null}
          icon="chevron.right"
          {...(onNext ? { onPress: onNext } : {})}
        />
      </Stack.Toolbar>
      {/* The page counter is drawn by the screen layer instead of the native
          toolbar so it stays exactly centered no matter the toolbar item
          widths or disabled states. */}
      <View
        pointerEvents="none"
        style={[styles.pageCounter, { bottom: bottomInset }]}
      >
        <Text style={styles.pageCounterText}>
          {total > 0 ? `${current} / ${total}` : ''}
        </Text>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  pageCounter: {
    alignItems: 'center',
    height: 44,
    justifyContent: 'center',
    left: 0,
    position: 'absolute',
    right: 0,
  },
  pageCounterText: {
    color: colors.secondaryLabel as string,
    fontSize: 13,
    fontVariant: ['tabular-nums'],
  },
});
