import { StyleSheet, View } from 'react-native';

import { tablerNativeIcons } from '@/components/tabler-native-icon-map';
import type { NativeIconName } from '@/components/native-icon-types';

export type { NativeIconName } from '@/components/native-icon-types';

export function NativeIcon({
  accessibilityLabel,
  color,
  name,
  size = 22,
}: {
  accessibilityLabel?: string;
  color: string;
  name: NativeIconName;
  size?: number;
}) {
  const IconComponent = tablerNativeIcons[name];

  return (
    <View style={styles.iconSlot}>
      <IconComponent
        color={color}
        size={size}
        strokeWidth={2}
        {...(accessibilityLabel
          ? { accessibilityLabel, accessible: true }
          : {})}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  iconSlot: {
    alignItems: 'center',
    height: 28,
    justifyContent: 'center',
    width: 28,
  },
});
