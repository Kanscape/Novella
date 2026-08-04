import type { PrimitiveBaseProps, ViewEvent } from '@expo/ui/jetpack-compose';
import { createViewModifierEventListener } from '@expo/ui/jetpack-compose/modifiers';
import { requireNativeView } from 'expo';
import type { ColorValue } from 'react-native';

export interface NativeBottomAppBarProps extends PrimitiveBaseProps {
  containerColor?: ColorValue;
  contentColor?: ColorValue;
  counterText?: string;
  /** Bar height in dp. */
  height?: number;
  nextAccessibilityLabel?: string;
  nextEnabled?: boolean;
  onNextPress?: () => void;
  onPreviousPress?: () => void;
  previousAccessibilityLabel?: string;
  previousEnabled?: boolean;
}

type NativeViewProps = Omit<NativeBottomAppBarProps, 'onNextPress' | 'onPreviousPress'> &
  ViewEvent<'onNextPressed', { value: boolean }> &
  ViewEvent<'onPreviousPressed', { value: boolean }>;

const NativeView = requireNativeView<NativeViewProps>('NovellaUi', 'BottomAppBar');

export function NativeBottomAppBar({
  modifiers,
  onNextPress,
  onPreviousPress,
  ...props
}: NativeBottomAppBarProps) {
  return (
    <NativeView
      {...props}
      {...(modifiers ? { modifiers } : {})}
      onNextPressed={onNextPress ? () => onNextPress() : undefined}
      onPreviousPressed={onPreviousPress ? () => onPreviousPress() : undefined}
      {...(modifiers ? createViewModifierEventListener(modifiers) : {})}
    />
  );
}
