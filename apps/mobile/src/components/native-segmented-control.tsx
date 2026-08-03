import SegmentedControl from '@expo/ui/community/segmented-control';

export interface NativeSegmentedControlOption<T extends string> {
  label: string;
  value: T;
}

export interface NativeSegmentedControlProps<T extends string> {
  enabled?: boolean;
  onValueChange(value: T): void;
  options: readonly NativeSegmentedControlOption<T>[];
  selectedValue: T;
}

export function NativeSegmentedControl<T extends string>({
  enabled = true,
  onValueChange,
  options,
  selectedValue,
}: NativeSegmentedControlProps<T>) {
  const selectedIndex = Math.max(0, options.findIndex((option) => option.value === selectedValue));
  return (
    <SegmentedControl
      enabled={enabled}
      onChange={({ nativeEvent }) => {
        const option = options[nativeEvent.selectedSegmentIndex];
        if (option) onValueChange(option.value);
      }}
      selectedIndex={selectedIndex}
      values={options.map((option) => option.label)}
    />
  );
}
