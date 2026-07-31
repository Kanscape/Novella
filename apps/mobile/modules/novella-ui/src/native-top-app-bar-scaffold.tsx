import type { PrimitiveBaseProps, ViewEvent } from '@expo/ui/jetpack-compose';
import { createViewModifierEventListener } from '@expo/ui/jetpack-compose/modifiers';
import { requireNativeView } from 'expo';
import type { ReactNode } from 'react';
import type { ColorValue } from 'react-native';

export type NativeTopAppBarAction = {
  accessibilityLabel: string;
  enabled?: boolean;
  icon: 'pencil';
  id: string;
};

export interface NativeTopAppBarScaffoldProps extends PrimitiveBaseProps {
  actions?: NativeTopAppBarAction[];
  children?: ReactNode;
  containerColor?: ColorValue;
  contentColor?: ColorValue;
  largeTitle?: boolean;
  onActionPress?: (id: string) => void;
  onBackPress?: () => void;
  showBackButton?: boolean;
  title: string;
}

type NativeViewProps = Omit<NativeTopAppBarScaffoldProps, 'onActionPress' | 'onBackPress'> &
  ViewEvent<'onActionPressed', { id: string }> &
  ViewEvent<'onBackPressed', { value: boolean }>;

const NativeView = requireNativeView<NativeViewProps>('NovellaUi', 'TopAppBarScaffold');

export function NativeTopAppBarScaffold({
  children,
  modifiers,
  onActionPress,
  onBackPress,
  ...props
}: NativeTopAppBarScaffoldProps) {
  return (
    <NativeView
      {...props}
      {...(modifiers ? { modifiers } : {})}
      onActionPressed={
        onActionPress ? (event) => onActionPress(event.nativeEvent.id) : undefined
      }
      onBackPressed={onBackPress ? () => onBackPress() : undefined}
      {...(modifiers ? createViewModifierEventListener(modifiers) : {})}
    >
      {children}
    </NativeView>
  );
}
