import type { PrimitiveBaseProps, ViewEvent } from '@expo/ui/jetpack-compose';
import { createViewModifierEventListener } from '@expo/ui/jetpack-compose/modifiers';
import { requireNativeView } from 'expo';

export interface NativeM3ExpressiveDropdownItem {
  enabled?: boolean;
  label: string;
}

export interface NativeM3ExpressiveDropdownProps extends PrimitiveBaseProps {
  enabled?: boolean;
  expanded: boolean;
  items: readonly NativeM3ExpressiveDropdownItem[];
  onExpandedChange?: (expanded: boolean) => void;
  onItemSelected?: (index: number) => void;
  selectedIndex: number;
}

type NativeViewProps = Omit<
  NativeM3ExpressiveDropdownProps,
  'onExpandedChange' | 'onItemSelected' | 'items'
> &
  ViewEvent<'onExpandedChange', { value: boolean }> &
  ViewEvent<'onItemSelected', { index: number }> & {
    items: NativeM3ExpressiveDropdownItem[];
  };

const NativeView = requireNativeView<NativeViewProps>('NovellaUi', 'M3ExpressiveDropdown');

export function NativeM3ExpressiveDropdown({
  items,
  modifiers,
  onExpandedChange,
  onItemSelected,
  ...props
}: NativeM3ExpressiveDropdownProps) {
  return (
    <NativeView
      {...props}
      items={items.map((item) => ({
        enabled: item.enabled ?? true,
        label: item.label,
      }))}
      {...(modifiers ? { modifiers } : {})}
      onExpandedChange={({ nativeEvent: { value } }) => onExpandedChange?.(value)}
      onItemSelected={({ nativeEvent: { index } }) => onItemSelected?.(index)}
      {...(modifiers ? createViewModifierEventListener(modifiers) : {})}
    />
  );
}
