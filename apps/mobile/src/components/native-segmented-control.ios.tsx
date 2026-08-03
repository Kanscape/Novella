import { StyleSheet } from 'react-native';

import { NativeSegmentedControl as NativeSegmentedControlView } from '../../modules/novella-ui';

import type { NativeSegmentedControlProps } from '@/components/native-segmented-control';

export function NativeSegmentedControl<T extends string>({
  enabled = true,
  onValueChange,
  options,
  selectedValue,
}: NativeSegmentedControlProps<T>) {
  return (
    <NativeSegmentedControlView
      enabled={enabled}
      onValueChange={(value) => {
        const option = options.find((candidate) => candidate.value === value);
        if (option) onValueChange(option.value);
      }}
      options={options}
      selectedValue={selectedValue}
      style={styles.control}
    />
  );
}

const styles = StyleSheet.create({
  control: {
    height: 32,
    width: '100%',
  },
});
