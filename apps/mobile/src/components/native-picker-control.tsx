import { Picker } from '@expo/ui';

export interface NativePickerOption<T extends string | number> {
  label: string;
  value: T;
}

export interface NativePickerControlProps<T extends string | number> {
  enabled?: boolean;
  expanded?: boolean;
  onExpandedChange?: (expanded: boolean) => void;
  onValueChange: (value: T) => void;
  options: readonly NativePickerOption<T>[];
  selectedValue: T;
}

export function NativePickerControl<T extends string | number>({
  enabled = true,
  onValueChange,
  options,
  selectedValue,
}: NativePickerControlProps<T>) {
  return (
    <Picker
      appearance="menu"
      enabled={enabled}
      onValueChange={onValueChange}
      selectedValue={selectedValue}
    >
      {options.map((option) => (
        <Picker.Item key={String(option.value)} label={option.label} value={option.value} />
      ))}
    </Picker>
  );
}
