import { Slider } from '@expo/ui';

export type NativeSliderControlProps = React.ComponentProps<typeof Slider>;

export function NativeSliderControl(props: NativeSliderControlProps) {
  return <Slider {...props} />;
}
