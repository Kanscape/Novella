import type { PrimitiveBaseProps } from '@expo/ui/jetpack-compose';
import { createViewModifierEventListener } from '@expo/ui/jetpack-compose/modifiers';
import { requireNativeView } from 'expo';

export interface NativeBlurHashProps extends PrimitiveBaseProps {
  blurHash: string;
  height: number;
  width: number;
}

const NativeView = requireNativeView<NativeBlurHashProps>('NovellaUi', 'BlurHash');

export function NativeBlurHash({ modifiers, ...props }: NativeBlurHashProps) {
  return (
    <NativeView
      {...props}
      {...(modifiers ? { modifiers } : {})}
      {...(modifiers ? createViewModifierEventListener(modifiers) : {})}
    />
  );
}
