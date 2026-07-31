import { Switch } from '@expo/ui';
import { useState } from 'react';

import {
  NativeGroupedListRow,
  type NativeGroupedListRowProps,
} from '@/components/native-grouped-list';
import {
  NativePickerControl,
  type NativePickerOption,
} from '@/components/native-picker-control';
import { NativeSliderControl } from '@/components/native-slider-control';
import { NativeListValue } from '@/components/settings-row-accessories';

export function NativeToggleRow({
  onValueChange,
  value,
  ...row
}: Omit<NativeGroupedListRowProps, 'trailing'> & {
  onValueChange: (value: boolean) => void;
  value: boolean;
}) {
  return (
    <NativeGroupedListRow
      {...row}
      onPress={() => onValueChange(!value)}
      trailing={
        <Switch
          onValueChange={onValueChange}
          value={value}
        />
      }
    />
  );
}

export function NativeSliderRow({
  formatValue = (value) => value.toString(),
  max,
  min,
  onValueChange,
  step,
  value,
  ...row
}: Omit<NativeGroupedListRowProps, 'trailing'> & {
  formatValue?: (value: number) => string;
  max: number;
  min: number;
  onValueChange: (value: number) => void;
  step?: number;
  value: number;
}) {
  return (
    <NativeGroupedListRow
      {...row}
      description={`${row.description ?? ''}${row.description ? ' · ' : ''}${formatValue(value)}`}
      trailing={
        <NativeSliderControl
          max={max}
          min={min}
          onValueChange={onValueChange}
          {...(step === undefined ? {} : { step })}
          value={value}
        />
      }
    />
  );
}

export function NativePickerRow<T extends string | number>({
  options,
  selectedValue,
  onValueChange,
  onPress,
  disabled = false,
  ...row
}: Omit<NativeGroupedListRowProps, 'trailing'> & {
  onValueChange: (value: T) => void;
  options: readonly NativePickerOption<T>[];
  selectedValue: T;
}) {
  const [expanded, setExpanded] = useState(false);
  const selectedLabel = options.find((option) => option.value === selectedValue)?.label ?? '';
  const handlePress = disabled
    ? onPress
    : () => {
        onPress?.();
        setExpanded(true);
      };

  return (
    <NativeGroupedListRow
      {...row}
      disabled={disabled}
      {...(handlePress ? { onPress: handlePress } : {})}
      description={`${row.description ?? ''}${row.description ? ' · ' : ''}${selectedLabel}`}
      trailing={
        <NativePickerControl
          enabled={!disabled}
          expanded={expanded}
          onValueChange={onValueChange}
          onExpandedChange={setExpanded}
          options={options}
          selectedValue={selectedValue}
        />
      }
    />
  );
}

export type { NativePickerOption } from '@/components/native-picker-control';

export function NativeValueRow({
  value,
  ...row
}: Omit<NativeGroupedListRowProps, 'trailing'> & { value: string }) {
  return <NativeGroupedListRow {...row} trailing={<NativeListValue>{value}</NativeListValue>} />;
}
