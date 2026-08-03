import type { PrimitiveBaseProps, ViewEvent } from '@expo/ui/jetpack-compose';
import { createViewModifierEventListener } from '@expo/ui/jetpack-compose/modifiers';
import { requireNativeView } from 'expo';

export interface NativeSegmentedControlOption {
  label: string;
  value: string;
}

export interface NativeSegmentedControlProps extends PrimitiveBaseProps {
  enabled?: boolean;
  onValueChange?: (value: string) => void;
  options: readonly NativeSegmentedControlOption[];
  selectedValue: string;
}

type NativeViewProps = Omit<NativeSegmentedControlProps, 'onValueChange' | 'options'> &
  ViewEvent<'onValueChange', { value: string }> & {
    options: NativeSegmentedControlOption[];
  };

const NativeView = requireNativeView<NativeViewProps>('NovellaUi', 'SegmentedControl');

export function NativeSegmentedControl({
  modifiers,
  onValueChange,
  options,
  ...props
}: NativeSegmentedControlProps) {
  return (
    <NativeView
      {...props}
      options={options.map((option) => ({ ...option }))}
      {...(modifiers ? { modifiers } : {})}
      onValueChange={({ nativeEvent: { value } }) => onValueChange?.(value)}
      {...(modifiers ? createViewModifierEventListener(modifiers) : {})}
    />
  );
}
