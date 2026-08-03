import { Host } from '@expo/ui';
import { useColorScheme } from 'react-native';

import { NativeSegmentedControl as NativeSegmentedControlView } from '../../modules/novella-ui';

import type { NativeSegmentedControlProps } from '@/components/native-segmented-control';

export function NativeSegmentedControl<T extends string>({
  enabled = true,
  onValueChange,
  options,
  selectedValue,
}: NativeSegmentedControlProps<T>) {
  const colorScheme = useColorScheme();
  return (
    <Host
      colorScheme={colorScheme}
      matchContents={{ vertical: true }}
      style={{ width: '100%' }}
      useViewportSizeMeasurement
    >
      <NativeSegmentedControlView
        enabled={enabled}
        onValueChange={(value) => {
          const option = options.find((candidate) => candidate.value === value);
          if (option) onValueChange(option.value);
        }}
        options={options}
        selectedValue={selectedValue}
      />
    </Host>
  );
}
