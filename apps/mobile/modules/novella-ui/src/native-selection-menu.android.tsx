import type { PrimitiveBaseProps, ViewEvent } from '@expo/ui/jetpack-compose';
import { createViewModifierEventListener } from '@expo/ui/jetpack-compose/modifiers';
import { requireNativeView } from 'expo';

export type NativeSelectionMenuIcon =
  | 'books'
  | 'equal'
  | 'sparkles'
  | 'tag'
  | 'textSize'
  | 'user';

export interface NativeSelectionMenuItem {
  enabled?: boolean;
  icon?: NativeSelectionMenuIcon;
  label: string;
}

export interface NativeSelectionMenuProps extends PrimitiveBaseProps {
  enabled?: boolean;
  expanded: boolean;
  items: readonly NativeSelectionMenuItem[];
  onExpandedChange?: (expanded: boolean) => void;
  onItemSelected?: (index: number) => void;
  selectedIndex: number;
}

type NativeViewProps = Omit<
  NativeSelectionMenuProps,
  'onExpandedChange' | 'onItemSelected' | 'items'
> &
  ViewEvent<'onExpandedChange', { value: boolean }> &
  ViewEvent<'onItemSelected', { index: number }> & {
    items: NativeSelectionMenuItem[];
  };

const NativeView = requireNativeView<NativeViewProps>('NovellaUi', 'SelectionMenu');

export function NativeSelectionMenu({
  items,
  modifiers,
  onExpandedChange,
  onItemSelected,
  ...props
}: NativeSelectionMenuProps) {
  return (
    <NativeView
      {...props}
      items={items.map((item) => ({
        enabled: item.enabled ?? true,
        ...(item.icon ? { icon: item.icon } : {}),
        label: item.label,
      }))}
      {...(modifiers ? { modifiers } : {})}
      onExpandedChange={({ nativeEvent: { value } }) => onExpandedChange?.(value)}
      onItemSelected={({ nativeEvent: { index } }) => onItemSelected?.(index)}
      {...(modifiers ? createViewModifierEventListener(modifiers) : {})}
    />
  );
}
