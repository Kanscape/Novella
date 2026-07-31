import { Box } from '@expo/ui/jetpack-compose';
import { width } from '@expo/ui/jetpack-compose/modifiers';

import { Slider } from '@expo/ui';

import type { NativeSliderControlProps } from '@/components/native-slider-control';

const sliderWidth = 168;

export function NativeSliderControl(props: NativeSliderControlProps) {
  return (
    <Box modifiers={[width(sliderWidth)]}>
      <Slider {...props} />
    </Box>
  );
}
