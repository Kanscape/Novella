import { Host } from '@expo/ui';
import { StyleSheet, View } from 'react-native';

import { NativeSearchBar } from '../../modules/novella-ui';

import { NativeSegmentedControl } from '@/components/native-segmented-control';
import type { NativeSearchControlsProps } from '@/components/native-search-controls.types';
import { useAppColorScheme } from '@/theme/app-theme';

const FORMAT_OPTIONS = [
  { label: 'Novel', value: 'Novel' },
  { label: 'Comic', value: 'Comic' },
] as const;

export function NativeSearchControls({
  format,
  onFormatChange,
  onQueryChange,
  onSubmit,
  query,
}: NativeSearchControlsProps) {
  const colorScheme = useAppColorScheme();
  return (
    <View style={styles.root}>
      <Host colorScheme={colorScheme} style={styles.searchHost} useViewportSizeMeasurement>
        <NativeSearchBar
          onQueryChange={onQueryChange}
          onSearch={onSubmit}
          query={query}
        />
      </Host>
      <View style={styles.segmented}>
        <NativeSegmentedControl
          onValueChange={onFormatChange}
          options={FORMAT_OPTIONS}
          selectedValue={format}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },
  searchHost: { height: 56, width: '100%' },
  segmented: { minHeight: 48, width: '100%' },
});
