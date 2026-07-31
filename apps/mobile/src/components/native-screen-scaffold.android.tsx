import { Host } from '@expo/ui';
import { RNHostView } from '@expo/ui/jetpack-compose';
import { fillMaxSize } from '@expo/ui/jetpack-compose/modifiers';
import { StyleSheet, useColorScheme, View } from 'react-native';

import { NativeTopAppBarScaffold } from '../../modules/novella-ui';

import type { NativeScreenScaffoldProps } from '@/components/native-screen-scaffold.types';

export function NativeScreenScaffold({
  actions,
  children,
  containerColor,
  contentColor,
  largeTitle = true,
  onActionPress,
  onBackPress,
  showBackButton = false,
  title,
}: NativeScreenScaffoldProps) {
  const colorScheme = useColorScheme();

  return (
    <Host colorScheme={colorScheme} style={styles.host} useViewportSizeMeasurement>
      <NativeTopAppBarScaffold
        {...(actions ? { actions } : {})}
        {...(containerColor ? { containerColor } : {})}
        {...(contentColor ? { contentColor } : {})}
        largeTitle={largeTitle}
        {...(onActionPress ? { onActionPress } : {})}
        {...(onBackPress ? { onBackPress } : {})}
        showBackButton={showBackButton}
        title={title}
      >
        <RNHostView modifiers={[fillMaxSize()]} style={StyleSheet.absoluteFill}>
          <View style={StyleSheet.absoluteFill}>{children}</View>
        </RNHostView>
      </NativeTopAppBarScaffold>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: { flex: 1 },
});
