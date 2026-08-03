import { Stack } from 'expo-router';
import { Text, View } from 'react-native';

import type { ReaderChapterNavigationProps } from '@/components/reader-navigation.types';
import { colors } from '@/theme/colors';

export function ReaderChapterNavigation({
  current,
  onNext,
  onPrevious,
  total,
}: ReaderChapterNavigationProps) {
  return (
    <Stack.Toolbar placement="bottom">
      <Stack.Toolbar.Button
        accessibilityLabel="Previous chapter"
        disabled={onPrevious === null}
        icon="chevron.left"
        {...(onPrevious ? { onPress: onPrevious } : {})}
      />
      <Stack.Toolbar.Spacer />
      <Stack.Toolbar.View>
        <View style={{ alignItems: 'center', height: 32, justifyContent: 'center', width: 88 }}>
          <Text
            style={{
              color: colors.secondaryLabel,
              fontSize: 13,
              fontVariant: ['tabular-nums'],
            }}
          >
            {total > 0 ? `${current} / ${total}` : ''}
          </Text>
        </View>
      </Stack.Toolbar.View>
      <Stack.Toolbar.Spacer />
      <Stack.Toolbar.Button
        accessibilityLabel="Next chapter"
        disabled={onNext === null}
        icon="chevron.right"
        {...(onNext ? { onPress: onNext } : {})}
      />
    </Stack.Toolbar>
  );
}
