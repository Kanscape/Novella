import { useState } from 'react';

import { NativeM3ExpressiveDropdown } from '../../modules/novella-ui';

import type { NativePickerControlProps } from '@/components/native-picker-control';

export function NativePickerControl<T extends string | number>({
  enabled = true,
  expanded: expandedProp,
  onExpandedChange,
  onValueChange,
  options,
  selectedValue,
}: NativePickerControlProps<T>) {
  const [internalExpanded, setInternalExpanded] = useState(false);
  const expanded = expandedProp ?? internalExpanded;
  const setExpanded = (nextExpanded: boolean) => {
    onExpandedChange?.(nextExpanded);
    if (expandedProp === undefined) setInternalExpanded(nextExpanded);
  };
  const selectedIndex = options.findIndex((option) => option.value === selectedValue);

  return (
    <NativeM3ExpressiveDropdown
      enabled={enabled}
      expanded={expanded}
      items={options}
      onExpandedChange={setExpanded}
      onItemSelected={(index: number) => {
        const option = options[index];
        if (!option) return;
        onValueChange(option.value);
      }}
      selectedIndex={selectedIndex}
    />
  );
}
