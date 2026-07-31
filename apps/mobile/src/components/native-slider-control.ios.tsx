import { Slider } from '@expo/ui';

import type { NativeSliderControlProps } from '@/components/native-slider-control';

export function NativeSliderControl(props: NativeSliderControlProps) {
  return <Slider {...props} />;
}
